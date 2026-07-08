// src/protocols/graphsync/graphsync_handler.dart
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' as core;
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/errors/graphsync_errors.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart' as ipld;
import 'package:dart_ipfs/src/core/ipld/selectors/selector_ast.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_budget.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_protocol.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_types.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Graphsync protocol handler for efficient DAG (Directed Acyclic Graph) transfer.
///
/// Implements the server-side and client-side Graphsync protocol. Server-side
/// responses are unicast to the requester, enforce selector budgets, and fall
/// back to Bitswap for missing blocks. Client-side requests can be sent to a
/// specific peer and support bidirectional pause/resume.
class GraphsyncHandler {
  /// Creates a new [GraphsyncHandler] with required dependencies.
  ///
  /// Parameters:
  /// - [config]: Global IPFS configuration for debug/logging and graphsync
  ///   budgets.
  /// - [_router]: Network router for protocol communication.
  /// - [_bitswap]: Bitswap handler for fetching individual blocks.
  /// - [_ipld]: IPLD handler for executing selectors and traversing graphs.
  /// - [_blockStore]: Local storage for persisted blocks.
  GraphsyncHandler(
    IPFSConfig config,
    this._router,
    this._bitswap,
    this._ipld,
    this._blockStore,
  ) : _logger = Logger(
        'GraphsyncHandler',
        debug: config.debug,
        verbose: config.verboseLogging,
      ),
      _protocol = GraphsyncProtocol(),
      _graphsyncConfig = config.graphsync,
      _maxConcurrentRequests = 64;

  final BitswapHandler _bitswap;
  final IPLDHandler _ipld;
  final RouterInterface _router;
  final BlockStore _blockStore;
  final Logger _logger;
  final GraphsyncProtocol _protocol;
  final GraphsyncConfig _graphsyncConfig;
  final int _maxConcurrentRequests;

  bool _isRunning = false;
  int _nextRequestId = 1;

  // Metrics tracking
  int _activeRequests = 0;
  int _totalRequestsReceived = 0;
  int _totalBytesSent = 0;
  int _totalBytesReceived = 0;

  /// Active server-side requests, keyed by request id.
  final Map<int, _ServerRequestContext> _serverRequests = {};

  /// Active client-side requests, keyed by request id.
  final Map<int, _ClientRequestContext> _clientRequests = {};

  /// Starts the Graphsync protocol handler and registers it with the router.
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('GraphsyncHandler is already running.');
      return;
    }

    _logger.debug('Starting GraphsyncHandler...');
    try {
      _router.registerProtocol(GraphsyncProtocol.protocolID);
      _router.registerProtocolHandler(
        GraphsyncProtocol.protocolID,
        (NetworkPacket packet) =>
            _handleMessage(packet.srcPeerId, packet.datagram),
      );
      _isRunning = true;
      _logger.info('GraphsyncHandler started successfully.');
    } catch (e, stackTrace) {
      _logger.error('Failed to start GraphsyncHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the Graphsync handler and unregisters it from the router.
  Future<void> stop() async {
    if (!_isRunning) return;

    _logger.debug('Stopping GraphsyncHandler...');
    try {
      for (final context in _clientRequests.values) {
        context.error(RequestHandlingError('GraphsyncHandler stopped'));
      }
      _clientRequests.clear();
      for (final context in _serverRequests.values) {
        context.cancel();
      }
      _serverRequests.clear();
      _isRunning = false;
      _logger.info('GraphsyncHandler stopped successfully.');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop GraphsyncHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Returns the current operational status and metrics of the Graphsync handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'enabled': _graphsyncConfig.enabled,
      'active_requests': _activeRequests,
      'total_requests_received': _totalRequestsReceived,
      'bytes_received': _totalBytesReceived,
      'bytes_sent': _totalBytesSent,
      'server_requests': _serverRequests.length,
      'client_requests': _clientRequests.length,
    };
  }

  /// Handles incoming Graphsync messages from a peer.
  Future<void> _handleMessage(String peer, Uint8List data) async {
    _totalBytesReceived += data.length;
    try {
      final GraphsyncMessage message = GraphsyncMessage.fromBuffer(data);

      for (final GraphsyncRequest request in message.requests) {
        if (request.cancel) {
          await _handleCancelRequest(peer, request.id);
        } else if (request.pause) {
          await _handlePauseRequest(peer, request.id);
        } else if (request.unpause) {
          await _handleUnpauseRequest(peer, request.id);
        } else {
          _totalRequestsReceived++;
          unawaited(_handleNewRequest(peer, request));
        }
      }

      for (final GraphsyncResponse response in message.responses) {
        await _handleResponse(peer, response, message.blocks);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error processing Graphsync message from $peer',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Handles a request to cancel an ongoing Graphsync operation.
  Future<void> _handleCancelRequest(String peer, int requestId) async {
    _logger.debug('Handling cancel request for ID: $requestId from $peer');
    try {
      final context = _serverRequests[requestId];
      if (context != null) {
        context.cancel();
      }
      await _sendResponseToPeer(
        peer,
        _protocol.createResponse(
          requestId: requestId,
          status: ResponseStatus.RS_CANCELLED,
          metadata: {'message': 'Request cancelled by peer'},
        ),
      );
      _logger.debug('Cancel request handled for ID: $requestId');
    } catch (e, stackTrace) {
      _logger.error('Error handling cancel request', e, stackTrace);
      throw RequestHandlingError('Failed to handle cancel request: $e');
    }
  }

  /// Handles a request to pause an ongoing Graphsync operation.
  Future<void> _handlePauseRequest(String peer, int requestId) async {
    _logger.debug('Handling pause request for ID: $requestId from $peer');
    try {
      final context = _serverRequests[requestId];
      if (context != null) {
        context.pause();
      }
      await _sendResponseToPeer(
        peer,
        _protocol.createResponse(
          requestId: requestId,
          status: ResponseStatus.RS_PAUSED,
          metadata: {'message': 'Request paused by peer'},
        ),
      );
    } catch (e, stackTrace) {
      _logger.error('Error handling pause request', e, stackTrace);
      throw RequestHandlingError('Failed to handle pause request: $e');
    }
  }

  /// Handles a request to resume a paused Graphsync operation.
  Future<void> _handleUnpauseRequest(String peer, int requestId) async {
    _logger.debug('Handling unpause request for ID: $requestId from $peer');
    try {
      final context = _serverRequests[requestId];
      if (context != null) {
        context.resume();
      }
      await _sendResponseToPeer(
        peer,
        _protocol.createResponse(
          requestId: requestId,
          status: ResponseStatus.RS_IN_PROGRESS,
          metadata: {'message': 'Request resumed'},
        ),
      );
    } catch (e, stackTrace) {
      _logger.error('Error handling unpause request', e, stackTrace);
      throw RequestHandlingError('Failed to handle unpause request: $e');
    }
  }

  /// Processes a new Graphsync request from a peer.
  ///
  /// Validates the request, enforces budgets, and traverses the graph using
  /// the provided selector. All responses are sent unicast to the requester.
  Future<void> _handleNewRequest(String peer, GraphsyncRequest request) async {
    _logger.debug('Handling new Graphsync request ${request.id} from $peer');
    _activeRequests++;

    final budget = _parseBudget(request.extensions);
    final context = _ServerRequestContext(
      requestId: request.id,
      peer: peer,
      budget: budget,
    );
    _serverRequests[request.id] = context;

    try {
      if (!request.hasRoot() || !request.hasSelector()) {
        await _sendErrorToPeer(peer, request.id, 'missing root or selector');
        return;
      }

      if (_serverRequests.length > _maxConcurrentRequests) {
        await _sendErrorToPeer(
          peer,
          request.id,
          'too many concurrent requests',
        );
        return;
      }

      await _sendResponseToPeer(
        peer,
        _protocol.createResponse(
          requestId: request.id,
          status: ResponseStatus.RS_IN_PROGRESS,
          metadata: {'message': 'Request accepted'},
        ),
      );

      final CID rootCID = CID.fromBytes(Uint8List.fromList(request.root));
      final Selector selector = await decodeSelectorBytes(
        Uint8List.fromList(request.selector),
      );

      final rootBlock = await _fetchGraphsyncBlock(rootCID, budget);
      if (rootBlock == null) {
        await _sendResponseToPeer(
          peer,
          _protocol.createResponse(
            requestId: request.id,
            status: ResponseStatus.RS_REJECTED,
            metadata: {'error': 'root block not found: $rootCID'},
          ),
        );
        return;
      }

      final blocks = <Block>[rootBlock];
      final blockCids = <String>{rootCID.toString()};

      try {
        await for (final result in _ipld.executeSelectorStream(
          rootCID,
          selector,
          maxDepth: budget.maxDepth,
          maxNodes: budget.maxBlocks,
        )) {
          if (context.cancelled) break;
          await context.waitWhilePaused();
          if (context.cancelled) break;

          final cidStr = result.cid.toString();
          if (blockCids.contains(cidStr)) continue;

          final block = await _fetchGraphsyncBlock(result.cid, budget);
          if (block == null) {
            await _sendResponseToPeer(
              peer,
              _protocol.createResponse(
                requestId: request.id,
                status: ResponseStatus.RS_REJECTED,
                metadata: {'error': 'block not found: $result.cid'},
              ),
            );
            return;
          }

          blocks.add(block);
          blockCids.add(cidStr);

          if (blocks.length % 10 == 0) {
            await _sendResponseToPeer(
              peer,
              _protocol.createProgressResponse(
                requestId: request.id,
                blocksProcessed: blocks.length,
                totalBlocks: budget.maxBlocks,
              ),
            );
          }
        }

        if (context.cancelled) {
          await _sendResponseToPeer(
            peer,
            _protocol.createResponse(
              requestId: request.id,
              status: ResponseStatus.RS_CANCELLED,
              metadata: {'message': 'Request cancelled'},
            ),
          );
          return;
        }

        await _sendResponseToPeer(
          peer,
          _protocol.createResponse(
            requestId: request.id,
            status: ResponseStatus.RS_COMPLETED,
            metadata: {
              'message': 'Graph transfer completed',
              'blocksProcessed': '${blocks.length}',
              'bytesSent':
                  '${blocks.fold<int>(0, (s, b) => s + b.data.length)}',
            },
            blocks: blocks,
          ),
        );
      } on SelectorBudgetExceeded catch (e) {
        await _sendResponseToPeer(
          peer,
          _protocol.createResponse(
            requestId: request.id,
            status: ResponseStatus.RS_REJECTED,
            metadata: {'error': 'budget exceeded: ${e.message}'},
          ),
        );
      } on BudgetExceededError catch (e) {
        await _sendResponseToPeer(
          peer,
          _protocol.createResponse(
            requestId: request.id,
            status: ResponseStatus.RS_REJECTED,
            metadata: {'error': e.message},
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling Graphsync request ${request.id}',
        e,
        stackTrace,
      );
      await _sendResponseToPeer(
        peer,
        _protocol.createResponse(
          requestId: request.id,
          status: ResponseStatus.RS_ERROR,
          metadata: {'error': e.toString()},
        ),
      );
    } finally {
      _activeRequests--;
      _serverRequests.remove(request.id);
    }
  }

  /// Sends an error response to a specific peer.
  Future<void> _sendErrorToPeer(
    String peer,
    int requestId,
    String message,
  ) async {
    await _sendResponseToPeer(
      peer,
      _protocol.createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_REJECTED,
        metadata: {'error': message},
      ),
    );
  }

  /// Sends a Graphsync response unicast to the requesting peer.
  Future<void> _sendResponseToPeer(
    String peer,
    GraphsyncMessage response,
  ) async {
    final Uint8List buffer = response.writeToBuffer();
    _totalBytesSent += buffer.length;

    await _router.sendMessage(
      peer,
      buffer,
      protocolId: GraphsyncProtocol.protocolID,
    );
  }

  /// Parses the selector budget from request extensions.
  SelectorBudget _parseBudget(Map<String, List<int>> extensions) {
    int maxDepth = _graphsyncConfig.defaultMaxDepth;
    int maxBlocks = _graphsyncConfig.defaultMaxBlocks;
    int maxBytes = _graphsyncConfig.defaultMaxBytes;

    final depthBytes = extensions['graphsync/max-depth'];
    if (depthBytes != null && depthBytes.isNotEmpty) {
      maxDepth = _parseIntBytes(depthBytes) ?? maxDepth;
    }

    final blocksBytes = extensions['graphsync/max-blocks'];
    if (blocksBytes != null && blocksBytes.isNotEmpty) {
      maxBlocks = _parseIntBytes(blocksBytes) ?? maxBlocks;
    }

    final bytesBytes = extensions['graphsync/max-bytes'];
    if (bytesBytes != null && bytesBytes.isNotEmpty) {
      maxBytes = _parseIntBytes(bytesBytes) ?? maxBytes;
    }

    return SelectorBudget(
      maxDepth: maxDepth,
      maxBlocks: maxBlocks,
      maxBytes: maxBytes,
    );
  }

  int? _parseIntBytes(List<int> bytes) {
    if (bytes.length > 8) return null;
    var value = 0;
    for (final byte in bytes) {
      value = (value << 8) | byte;
    }
    return value;
  }

  /// Fetches a block from the local store or via Bitswap and converts it to a
  /// Graphsync [Block] protobuf with a CID prefix.
  Future<Block?> _fetchGraphsyncBlock(CID cid, SelectorBudget budget) async {
    if (!await _blockStore.hasBlock(cid.toString())) {
      if (!_graphsyncConfig.fallBackToBitswap) {
        return null;
      }
      final core.Block? fetched = await _bitswap.wantBlock(cid.toString());
      if (fetched != null) {
        final valid = await fetched.validate();
        if (!valid) {
          _logger.warning('Bitswap fallback returned invalid block for $cid');
          return null;
        }
        await _blockStore.putBlock(fetched);
      } else {
        return null;
      }
    }

    final response = await _blockStore.getBlock(cid.toString());
    if (!response.found) {
      return null;
    }
    final core.Block block = core.Block.fromProto(response.block);
    budget.checkBlock(block.data.length);

    return Block(prefix: block.cid.toPrefixBytes(), data: block.data);
  }

  // --------------------------------------------------------------------------
  // Client-side API
  // --------------------------------------------------------------------------

  /// Sends a Graphsync request to [peer] for the subgraph described by [selector]
  /// and returns a stream of responses.
  ///
  /// The returned stream emits every [GraphsyncResponse] received from the
  /// peer, including progress and terminal responses. Blocks are stored in the
  /// local blockstore as they arrive. The caller can use [pauseRequest],
  /// [resumeRequest], or [cancelRequest] to control the transfer.
  Future<Stream<GraphsyncResponse>> requestGraphFromPeer(
    String peer,
    CID root,
    Selector selector, {
    GraphsyncPriority priority = GraphsyncPriority.normal,
    int? maxDepth,
    int? maxBlocks,
    int? maxBytes,
  }) async {
    if (!_isRunning) {
      throw StateError('GraphsyncHandler is not running');
    }
    if (!_router.isConnectedPeer(peer)) {
      throw StateError('Peer $peer is not connected');
    }

    final context = await _startClientRequest(
      peer,
      root,
      selector,
      priority: priority,
      maxDepth: maxDepth,
      maxBlocks: maxBlocks,
      maxBytes: maxBytes,
    );

    return context.responses;
  }

  /// Starts a client request and returns the internal context. Shared by
  /// [requestGraphFromPeer] and [fetchGraphFromPeer] so the latter can keep a
  /// reference to the context even after the response handler removes it from
  /// [_clientRequests].
  Future<_ClientRequestContext> _startClientRequest(
    String peer,
    CID root,
    Selector selector, {
    GraphsyncPriority priority = GraphsyncPriority.normal,
    int? maxDepth,
    int? maxBlocks,
    int? maxBytes,
  }) async {
    final requestId = _nextRequestId++;
    final context = _ClientRequestContext(requestId: requestId, peer: peer);
    _clientRequests[requestId] = context;

    final extensions = <String, Uint8List>{};
    if (maxDepth != null) {
      extensions['graphsync/max-depth'] = _encodeIntBytes(maxDepth);
    }
    if (maxBlocks != null) {
      extensions['graphsync/max-blocks'] = _encodeIntBytes(maxBlocks);
    }
    if (maxBytes != null) {
      extensions['graphsync/max-bytes'] = _encodeIntBytes(maxBytes);
    }

    final message = _protocol.createRequest(
      id: requestId,
      root: root.toBytes(),
      selector: await encodeSelectorDagCbor(selector),
      priority: priority,
      extensions: extensions,
    );

    unawaited(
      _router
          .sendMessage(
            peer,
            message.writeToBuffer(),
            protocolId: GraphsyncProtocol.protocolID,
          )
          .catchError((Object e) {
            context.error(RequestHandlingError('Failed to send request: $e'));
            return Future<void>.value();
          }),
    );

    return context;
  }

  /// Convenience method that fetches all blocks for a Graphsync request from
  /// [peer] and returns them as a list.
  ///
  /// Throws [RequestTimeoutError] if the request does not complete within
  /// [timeout].
  Future<List<core.Block>> fetchGraphFromPeer(
    String peer,
    CID root,
    Selector selector, {
    GraphsyncPriority priority = GraphsyncPriority.normal,
    int? maxDepth,
    int? maxBlocks,
    int? maxBytes,
    Duration timeout = GraphsyncProtocol.defaultTimeout,
  }) async {
    final context = await _startClientRequest(
      peer,
      root,
      selector,
      priority: priority,
      maxDepth: maxDepth,
      maxBlocks: maxBlocks,
      maxBytes: maxBytes,
    );

    final terminal = await context.responses
        .firstWhere(
          (GraphsyncResponse response) =>
              response.status == ResponseStatus.RS_COMPLETED ||
              response.status == ResponseStatus.RS_REJECTED ||
              response.status == ResponseStatus.RS_ERROR ||
              response.status == ResponseStatus.RS_CANCELLED,
        )
        .timeout(
          timeout,
          onTimeout: () {
            _clientRequests.remove(context.requestId);
            context.error(RequestTimeoutError('${context.requestId}'));
            throw RequestTimeoutError('${context.requestId}');
          },
        );

    if (terminal.status != ResponseStatus.RS_COMPLETED) {
      throw GraphTraversalError(
        'Graphsync request failed with status ${terminal.status}: '
        '${terminal.metadata['error'] ?? terminal.metadata['message']}',
      );
    }

    return context.blocks;
  }

  /// Requests a graph from the network by its root CID and an IPLD selector.
  ///
  /// If a connected peer is available, a Graphsync request is sent. Otherwise,
  /// the method falls back to Bitswap for the root block.
  Future<core.Block?> requestGraph(
    String cidStr,
    ipld.IPLDSelector selector,
  ) async {
    _logger.debug('Initiating Graphsync request for CID: $cidStr');

    try {
      final CID cid = CID.decode(cidStr);
      final specSelector = selector.toSpecSelector();

      final connected = _router.listConnectedPeers();
      if (connected.isEmpty) {
        _logger.debug(
          'No connected peers, falling back to Bitswap for $cidStr',
        );
        final core.Block? bitswapBlock = await _bitswap.wantBlock(cidStr);
        if (bitswapBlock != null) {
          await _blockStore.putBlock(bitswapBlock);
        }
        return bitswapBlock;
      }

      final peer = connected.first;
      final blocks = await fetchGraphFromPeer(peer, cid, specSelector);

      if (blocks.isNotEmpty) {
        return blocks.firstWhere(
          (block) => block.cid.toString() == cidStr,
          orElse: () => blocks.first,
        );
      }

      _logger.debug(
        'Graphsync returned no blocks for $cidStr, falling back to Bitswap',
      );
      final core.Block? bitswapBlock = await _bitswap.wantBlock(cidStr);
      if (bitswapBlock != null) {
        await _blockStore.putBlock(bitswapBlock);
      }
      return bitswapBlock;
    } catch (e, stackTrace) {
      _logger.error('Failed to initiate Graphsync request', e, stackTrace);
      throw GraphTraversalError('Failed to request graph: $e');
    }
  }

  /// Sends a pause update request to [peer] for the given [requestId].
  Future<void> pauseRequest(int requestId, String peer) async {
    final message = _protocol.createPauseRequest(requestId);
    await _router.sendMessage(
      peer,
      message.writeToBuffer(),
      protocolId: GraphsyncProtocol.protocolID,
    );
  }

  /// Sends an unpause (resume) update request to [peer] for the given [requestId].
  Future<void> resumeRequest(int requestId, String peer) async {
    final message = _protocol.createUnpauseRequest(requestId);
    await _router.sendMessage(
      peer,
      message.writeToBuffer(),
      protocolId: GraphsyncProtocol.protocolID,
    );
  }

  /// Sends a cancel update request to [peer] for the given [requestId].
  Future<void> cancelRequest(int requestId, String peer) async {
    final message = _protocol.createCancelRequest(requestId);
    await _router.sendMessage(
      peer,
      message.writeToBuffer(),
      protocolId: GraphsyncProtocol.protocolID,
    );
  }

  Uint8List _encodeIntBytes(int value) {
    final bytes = <int>[];
    var remaining = value;
    do {
      bytes.insert(0, remaining & 0xFF);
      remaining >>= 8;
    } while (remaining > 0);
    return Uint8List.fromList(bytes.isEmpty ? [0] : bytes);
  }

  Future<void> _handleResponse(
    String peer,
    GraphsyncResponse response,
    List<Block> blocks,
  ) async {
    final context = _clientRequests[response.id];
    if (context == null) {
      _logger.debug(
        'Received response for unknown request ${response.id} from $peer',
      );
      return;
    }

    for (final protoBlock in blocks) {
      try {
        final block = await core.Block.fromData(
          Uint8List.fromList(protoBlock.data),
          format: _codecFromPrefix(Uint8List.fromList(protoBlock.prefix)),
        );
        final valid = await block.validate();
        if (!valid) {
          _logger.warning(
            'Invalid block received for request ${response.id} from $peer',
          );
          continue;
        }
        if (!_prefixMatches(block.cid.toPrefixBytes(), protoBlock.prefix)) {
          _logger.warning(
            'Block prefix mismatch for request ${response.id} from $peer',
          );
          continue;
        }
        await _blockStore.putBlock(block);
        context.addBlock(block);
      } catch (e, stackTrace) {
        _logger.warning(
          'Failed to decode block for request ${response.id}',
          e,
          stackTrace,
        );
      }
    }

    if (response.status == ResponseStatus.RS_PAUSED) {
      context.paused = true;
    } else if (response.status == ResponseStatus.RS_IN_PROGRESS) {
      context.paused = false;
    }

    context.addResponse(response);

    final isTerminal =
        response.status == ResponseStatus.RS_COMPLETED ||
        response.status == ResponseStatus.RS_REJECTED ||
        response.status == ResponseStatus.RS_ERROR ||
        response.status == ResponseStatus.RS_CANCELLED;

    if (isTerminal) {
      context.complete();
      _clientRequests.remove(response.id);
    }
  }

  String _codecFromPrefix(Uint8List prefix) {
    if (prefix.isEmpty) return 'raw';
    if (prefix[0] == 0x01) {
      final (codecLen, codecCode) = CID.readVarint(prefix, 1);
      try {
        return EncodingUtils.getCodecFromCode(codecCode);
      } catch (_) {
        return 'raw';
      }
    }
    return 'dag-pb';
  }

  bool _prefixMatches(List<int> computed, List<int> received) {
    if (computed.length != received.length) return false;
    for (var i = 0; i < computed.length; i++) {
      if (computed[i] != received[i]) return false;
    }
    return true;
  }
}

/// Context for a single server-side Graphsync request.
class _ServerRequestContext {
  _ServerRequestContext({
    required this.requestId,
    required this.peer,
    required this.budget,
  });

  final int requestId;
  final String peer;
  final SelectorBudget budget;
  bool paused = false;
  bool cancelled = false;
  Completer<void>? _resumeCompleter;

  void pause() {
    paused = true;
    _resumeCompleter ??= Completer<void>();
  }

  void resume() {
    paused = false;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  void cancel() {
    cancelled = true;
    paused = false;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  Future<void> waitWhilePaused() async {
    if (!paused || cancelled) return;
    _resumeCompleter ??= Completer<void>();
    await _resumeCompleter!.future;
  }
}

/// Context for a single client-side Graphsync request.
class _ClientRequestContext {
  _ClientRequestContext({required this.requestId, required this.peer});

  final int requestId;
  final String peer;
  bool paused = false;
  final List<core.Block> blocks = [];
  final _responseController = StreamController<GraphsyncResponse>.broadcast();
  final _completer = Completer<List<core.Block>>();

  Stream<GraphsyncResponse> get responses => _responseController.stream;

  void addResponse(GraphsyncResponse response) {
    _responseController.add(response);
  }

  void addBlock(core.Block block) {
    blocks.add(block);
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete(List.unmodifiable(blocks));
    }
    _responseController.close();
  }

  void error(Object error) {
    _responseController.addError(error);
    _responseController.close();
  }
}
