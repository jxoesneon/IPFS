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

/// Graphsync protocol handler for efficient DAG transfer.
///
/// Handles requests, responses, and coordinates with Bitswap and
/// IPLD for graph traversal and block fetching.
class GraphsyncHandler {
  /// Creates a Graphsync handler.
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

  /// Starts the Graphsync protocol handler.
  Future<void> start() async {
    _router.registerProtocol(GraphsyncProtocol.protocolID);
    _router.registerProtocolHandler(
      GraphsyncProtocol.protocolID,
      (packet) => _handleMessage(packet.srcPeerId, packet.datagram),
    );

    _logger.debug('Starting GraphsyncHandler...');
    try {
      // Initialize graphsync protocol
      _logger.debug('GraphsyncHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start GraphsyncHandler', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _handleMessage(String peer, Uint8List data) async {
    final message = GraphsyncMessage.fromBuffer(data);

    for (final request in message.requests) {
      if (request.cancel) {
        await _handleCancelRequest(request.id);
      } else if (request.pause) {
        await _handlePauseRequest(request.id);
      } else if (request.unpause) {
        await _handleUnpauseRequest(request.id);
      } else {
        await _handleNewRequest(peer, request);
      }
    }
  }

  /// Stops the Graphsync handler.
  Future<void> stop() async {
    _logger.debug('Stopping GraphsyncHandler...');
    try {
      // Cleanup graphsync connections and resources
      _logger.debug('GraphsyncHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop GraphsyncHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Returns the current status of the Graphsync handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'enabled': _config.enableGraphsync,
      'active_requests': 0, // Add actual metrics here
      'total_requests': 0,
      'bytes_received': 0,
      'bytes_sent': 0,
    };
  }

  Future<void> _handleCancelRequest(int requestId) async {
    _logger.debug('Handling cancel request for ID: $requestId');
    try {
      // Send cancellation response
      final response = _protocol.createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_CANCELLED,
        metadata: {'message': 'Request cancelled by peer'},
      );

      // Convert to bytes and send response
      final responseBytes = response.writeToBuffer();
      await _router.broadcastMessage(
        GraphsyncProtocol.protocolID,
        responseBytes,
      );

      _logger.debug('Cancel request handled successfully for ID: $requestId');
    } catch (e, stackTrace) {
      _logger.error('Error handling cancel request', e, stackTrace);
      throw RequestHandlingError('Failed to handle cancel request: $e');
    }
  }

  Future<void> _handlePauseRequest(int requestId) async {
    _logger.debug('Handling pause request for ID: $requestId');
    try {
      final response = _protocol.createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_PAUSED,
        metadata: {'message': 'Request paused by peer'},
      );

      final responseBytes = response.writeToBuffer();
      await _router.broadcastMessage(
        GraphsyncProtocol.protocolID,
        responseBytes,
      );

      _logger.debug('Pause request handled successfully for ID: $requestId');
    } catch (e, stackTrace) {
      _logger.error('Error handling pause request', e, stackTrace);
      throw RequestHandlingError('Failed to handle pause request: $e');
    }
  }

  Future<void> _handleUnpauseRequest(int requestId) async {
    _logger.debug('Handling unpause request for ID: $requestId');
    try {
      final response = _protocol.createResponse(
        requestId: requestId,
        status: ResponseStatus.RS_IN_PROGRESS,
        metadata: {'message': 'Request resumed'},
      );

      final responseBytes = response.writeToBuffer();
      await _router.broadcastMessage(
        GraphsyncProtocol.protocolID,
        responseBytes,
      );

      _logger.debug('Unpause request handled successfully for ID: $requestId');
    } catch (e, stackTrace) {
      _logger.error('Error handling unpause request', e, stackTrace);
      throw RequestHandlingError('Failed to handle unpause request: $e');
    }
  }

  Future<void> _handleNewRequest(String peer, GraphsyncRequest request) async {
    _logger.debug('Handling new request ${request.id} from ${peer.toString()}');

    try {
      // Validate request fields
      if (!request.hasRoot() || !request.hasSelector()) {
        throw MessageError('Invalid request: missing root or selector');
      }

      // Create initial response
      final response = _protocol.createResponse(
        requestId: request.id,
        status: ResponseStatus.RS_IN_PROGRESS,
        metadata: {'message': 'Request accepted'},
      );

      // Send initial response
      await _router.broadcastMessage(
        GraphsyncProtocol.protocolID,
        response.writeToBuffer(),
      );

      // Process the request using IPLD and Bitswap
      try {
        final rootBytes = Uint8List.fromList(request.root);
        final selectorBytes = Uint8List.fromList(request.selector);

        // First try to get the root block using Bitswap
        final rootCID = CID.fromBytes(rootBytes);
        final rootBlock = await _bitswap.wantBlock(rootCID.toString());
        if (rootBlock == null) {
          throw GraphTraversalError('Root block not found');
        }

        // Now get the root node from IPLD
        final root = await _ipld.get(rootCID);
        if (root == null) {
          throw GraphTraversalError('Root node not found');
        }

        // Execute selector query
        final results = await _ipld.executeSelector(
          rootCID,
          await IPLDSelector.fromBytesAsync(selectorBytes),
        );

        // Process results and fetch missing blocks via Bitswap
        int processed = 0;
        final total = results.length;

        for (final result in results) {
          processed++;

          // Try to get block via Bitswap if not in local store
          if (!await _blockStore.hasBlock(result.cid.toString())) {
            final block = await _bitswap.wantBlock(result.cid.toString());
            if (block != null) {
              await _blockStore.putBlock(block);
            }
          }

          // Create progress response
          final progressResponse = _protocol.createProgressResponse(
            requestId: request.id,
            blocksProcessed: processed,
            totalBlocks: total,
          );

          await _router.broadcastMessage(
            GraphsyncProtocol.protocolID,
            progressResponse.writeToBuffer(),
          );
        }

        // Send completion response
        final completionResponse = _protocol.createResponse(
          requestId: request.id,
          status: ResponseStatus.RS_COMPLETED,
          metadata: {
            'message': 'Request completed successfully',
            'blocksProcessed': '$processed',
            'totalBlocks': '$total',
          },
        );

        await _router.broadcastMessage(
          GraphsyncProtocol.protocolID,
          completionResponse.writeToBuffer(),
        );
      } catch (e) {
        // Send error response
        final errorResponse = _protocol.createResponse(
          requestId: request.id,
          status: ResponseStatus.RS_ERROR,
          metadata: {'error': e.toString()},
        );

        await _router.broadcastMessage(
          GraphsyncProtocol.protocolID,
          errorResponse.writeToBuffer(),
        );
        rethrow;
      }
    } catch (e, stackTrace) {
      _logger.error('Error handling new request', e, stackTrace);
      throw GraphTraversalError('Failed to handle new request: $e');
    }
  }

  /// Requests a graph by CID with the given selector.
  Future<Block?> requestGraph(String cidStr, IPLDSelector selector) async {
    _logger.debug('Requesting graph for CID: $cidStr with selector');

    try {
      final cid = CID.decode(cidStr);
      final rootBytes = cid.toBytes();
      final selectorBytes = await selector.toBytes();
      final requestId = (DateTime.now().millisecondsSinceEpoch % 2147483647);

      final request = _protocol.createRequest(
        id: requestId,
        root: rootBytes,
        selector: selectorBytes,
        priority: GraphsyncPriority.normal,
      );

      await _router.broadcastMessage(
        GraphsyncProtocol.protocolID,
        request.writeToBuffer(),
      );

      // Get block via Bitswap and convert to appropriate type
      final bitswapBlock = await _bitswap.wantBlock(cidStr);
      if (bitswapBlock != null) {
        await _blockStore.putBlock(bitswapBlock);
        // Convert Bitswap block to Graphsync block
        return Future.value(_convertToGraphsyncBlock(bitswapBlock));
      }
      return Future.value(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to request graph', e, stackTrace);
      throw GraphTraversalError('Failed to request graph: $e');
    }
  }

  Block _convertToGraphsyncBlock(core.Block bitswapBlock) {
    return Block(
      prefix: bitswapBlock.cid.toBytes().sublist(0, 1),
      data: bitswapBlock.data,
    );
  }
}
