// src/protocols/graphsync/graphsync_handler.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart' as core;
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/errors/graphsync_errors.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_protocol.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_types.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Graphsync protocol handler for efficient DAG (Directed Acyclic Graph) transfer.
///
/// Implements the Graphsync protocol, allowing peers to request subgraphs
/// specified by IPLD selectors. Coordinates with Bitswap for block retrieval
/// and IPLD for graph traversal.
class GraphsyncHandler {
  /// Creates a new [GraphsyncHandler] with required dependencies.
  ///
  /// Parameters:
  /// - [config]: Global IPFS configuration for debug/logging settings.
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
      _config = config;

  final BitswapHandler _bitswap;
  final IPLDHandler _ipld;
  final RouterInterface _router;
  final BlockStore _blockStore;
  final Logger _logger;
  final GraphsyncProtocol _protocol;
  final IPFSConfig _config;

  bool _isRunning = false;

  // Metrics tracking
  int _activeRequests = 0;
  int _totalRequestsReceived = 0;
  int _totalBytesSent = 0;
  int _totalBytesReceived = 0;

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

  /// Handles incoming Graphsync messages from a peer.
  Future<void> _handleMessage(String peer, Uint8List data) async {
    _totalBytesReceived += data.length;
    try {
      final GraphsyncMessage message = GraphsyncMessage.fromBuffer(data);

      for (final GraphsyncRequest request in message.requests) {
        if (request.cancel) {
          await _handleCancelRequest(request.id);
        } else if (request.pause) {
          await _handlePauseRequest(request.id);
        } else if (request.unpause) {
          await _handleUnpauseRequest(request.id);
        } else {
          _totalRequestsReceived++;
          await _handleNewRequest(peer, request);
        }
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

  /// Stops the Graphsync handler and unregisters it from the router.
  Future<void> stop() async {
    if (!_isRunning) return;

    _logger.debug('Stopping GraphsyncHandler...');
    try {
      // Unregistration logic would go here if supported by RouterInterface
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
      'enabled': _config.enableGraphsync,
      'active_requests': _activeRequests,
      'total_requests_received': _totalRequestsReceived,
      'bytes_received': _totalBytesReceived,
      'bytes_sent': _totalBytesSent,
    };
  }

  /// Handles a request to cancel an ongoing Graphsync operation.
  Future<void> _handleCancelRequest(int requestId) async {
    _logger.debug('Handling cancel request for ID: $requestId');
    try {
      final GraphsyncMessage response = _protocol.createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_CANCELLED,
        metadata: {'message': 'Request cancelled by peer'},
      );

      await _sendResponse(response);
      _logger.debug('Cancel request handled for ID: $requestId');
    } catch (e, stackTrace) {
      _logger.error('Error handling cancel request', e, stackTrace);
      throw RequestHandlingError('Failed to handle cancel request: $e');
    }
  }

  /// Handles a request to pause an ongoing Graphsync operation.
  Future<void> _handlePauseRequest(int requestId) async {
    _logger.debug('Handling pause request for ID: $requestId');
    try {
      final GraphsyncMessage response = _protocol.createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_PAUSED,
        metadata: {'message': 'Request paused by peer'},
      );

      await _sendResponse(response);
    } catch (e, stackTrace) {
      _logger.error('Error handling pause request', e, stackTrace);
      throw RequestHandlingError('Failed to handle pause request: $e');
    }
  }

  /// Handles a request to resume a paused Graphsync operation.
  Future<void> _handleUnpauseRequest(int requestId) async {
    _logger.debug('Handling unpause request for ID: $requestId');
    try {
      final GraphsyncMessage response = _protocol.createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_IN_PROGRESS,
        metadata: {'message': 'Request resumed'},
      );

      await _sendResponse(response);
    } catch (e, stackTrace) {
      _logger.error('Error handling unpause request', e, stackTrace);
      throw RequestHandlingError('Failed to handle unpause request: $e');
    }
  }

  /// Processes a new Graphsync request from a peer.
  ///
  /// Validates the request, acceptance, and initiates graph traversal using
  /// IPLD selectors. Progress updates are sent back to the requester.
  Future<void> _handleNewRequest(String peer, GraphsyncRequest request) async {
    _logger.debug('Handling new Graphsync request ${request.id} from $peer');
    _activeRequests++;

    try {
      if (!request.hasRoot() || !request.hasSelector()) {
        throw MessageError('Invalid request: missing root or selector');
      }

      // Acceptance response
      await _sendResponse(
        _protocol.createResponse(
          requestId: request.id,
          status: ResponseStatus.RS_IN_PROGRESS,
          metadata: {'message': 'Request accepted'},
        ),
      );

      final CID rootCID = CID.fromBytes(Uint8List.fromList(request.root));
      final IPLDSelector selector = await IPLDSelector.fromBytesAsync(
        Uint8List.fromList(request.selector),
      );

      // Traversal and block fetching logic
      try {
        final List<SelectorResult> results = await _ipld.executeSelector(
          rootCID,
          selector,
        );

        if (results.isEmpty) {
          throw GraphTraversalError(
            'Root node not found or selector matched nothing: $rootCID',
          );
        }

        int processed = 0;
        final int total = results.length;

        for (final SelectorResult result in results) {
          processed++;

          // Ensure we have the block locally or fetch via Bitswap
          if (!await _blockStore.hasBlock(result.cid.toString())) {
            final core.Block? fetched = await _bitswap.wantBlock(
              result.cid.toString(),
            );
            if (fetched != null) {
              await _blockStore.putBlock(fetched);
            } else {
              throw BlockNotFoundError(result.cid.toString());
            }
          }

          // Send progress update
          await _sendResponse(
            _protocol.createProgressResponse(
              requestId: request.id,
              blocksProcessed: processed,
              totalBlocks: total,
            ),
          );
        }

        // Completion response
        await _sendResponse(
          _protocol.createResponse(
            requestId: request.id,
            status: ResponseStatus.RS_COMPLETED,
            metadata: {
              'message': 'Graph transfer completed',
              'blocksProcessed': '$processed',
            },
          ),
        );
      } catch (e) {
        await _sendResponse(
          _protocol.createResponse(
            requestId: request.id,
            status: ResponseStatus.RS_ERROR,
            metadata: {'error': e.toString()},
          ),
        );
        rethrow;
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling Graphsync request ${request.id}',
        e,
        stackTrace,
      );
      rethrow;
    } finally {
      _activeRequests--;
    }
  }

  /// Requests a graph from the network by its root CID and an IPLD selector.
  ///
  /// Parameters:
  /// - [cidStr]: The string representation of the root CID.
  /// - [selector]: The selector defining the subgraph to retrieve.
  ///
  /// Returns the root [Block] of the graph if successfully retrieved.
  Future<Block?> requestGraph(String cidStr, IPLDSelector selector) async {
    _logger.debug('Initiating Graphsync request for CID: $cidStr');

    try {
      final CID cid = CID.decode(cidStr);
      final Uint8List selectorBytes = await selector.toBytes();
      final int requestId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

      final GraphsyncMessage message = _protocol.createRequest(
        id: requestId,
        root: cid.toBytes(),
        selector: selectorBytes,
        priority: GraphsyncPriority.normal,
      );

      await _router.broadcastMessage(
        GraphsyncProtocol.protocolID,
        message.writeToBuffer(),
      );

      // Fallback to Bitswap for the root block if necessary
      final core.Block? bitswapBlock = await _bitswap.wantBlock(cidStr);
      if (bitswapBlock != null) {
        await _blockStore.putBlock(bitswapBlock);
        return _convertToGraphsyncBlock(bitswapBlock);
      }
      return null;
    } catch (e, stackTrace) {
      _logger.error('Failed to initiate Graphsync request', e, stackTrace);
      throw GraphTraversalError('Failed to request graph: $e');
    }
  }

  /// Helper to send a Graphsync response via the router.
  Future<void> _sendResponse(GraphsyncMessage message) async {
    final Uint8List buffer = message.writeToBuffer();
    _totalBytesSent += buffer.length;

    await _router.broadcastMessage(GraphsyncProtocol.protocolID, buffer);
  }

  /// Converts a core [core.Block] to a Graphsync [Block] protobuf.
  Block _convertToGraphsyncBlock(core.Block bitswapBlock) {
    return Block(
      prefix: bitswapBlock.cid.toBytes().sublist(0, 1),
      data: bitswapBlock.data,
    );
  }
}
