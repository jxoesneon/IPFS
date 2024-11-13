// src/core/ipfs_node/graphsync_handler.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';

/// Handles Graphsync protocol operations for an IPFS node
class GraphsyncHandler {
  final IPFSConfig _config;
  final BlockStore _blockStore;
  late final Logger _logger;
  bool _isRunning = false;

  // Track active requests and responses
  final Map<String, _GraphsyncRequest> _activeRequests = {};
  final Map<String, _GraphsyncResponse> _activeResponses = {};

  GraphsyncHandler(this._config, this._blockStore) {
    _logger = Logger('GraphsyncHandler',
        debug: _config.debug, verbose: _config.verboseLogging);
    _logger.debug('GraphsyncHandler instance created');
  }

  /// Starts the Graphsync handler
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('GraphsyncHandler already running');
      return;
    }

    try {
      _logger.debug('Starting GraphsyncHandler...');
      _isRunning = true;
      _logger.debug('GraphsyncHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start GraphsyncHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the Graphsync handler
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('GraphsyncHandler already stopped');
      return;
    }

    try {
      _logger.debug('Stopping GraphsyncHandler...');

      // Cancel all active requests and responses
      for (final request in _activeRequests.values) {
        await request.cancel();
      }
      _activeRequests.clear();

      for (final response in _activeResponses.values) {
        await response.cancel();
      }
      _activeResponses.clear();

      _isRunning = false;
      _logger.debug('GraphsyncHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop GraphsyncHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Requests a graph of blocks starting from the given root CID
  Future<List<Block>> requestGraph(
    String rootCid, {
    List<String> selector = const ['links'],
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _logger.debug('Requesting graph for root CID: $rootCid');

    try {
      final request = _GraphsyncRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rootCid: rootCid,
        selector: selector,
        timeout: timeout,
      );

      _activeRequests[request.id] = request;
      _logger.verbose('Created request ${request.id} for CID: $rootCid');

      final blocks = await _traverseGraph(rootCid, selector);

      _logger.debug('Retrieved ${blocks.length} blocks for CID: $rootCid');
      return blocks;
    } catch (e, stackTrace) {
      _logger.error('Error requesting graph', e, stackTrace);
      rethrow;
    } finally {
      _activeRequests.remove(rootCid);
    }
  }

  /// Responds to a graph request by providing the requested blocks
  Future<void> respondToRequest(
      String requestId, String rootCid, List<String> selector) async {
    _logger.debug('Responding to request $requestId for CID: $rootCid');

    try {
      final response = _GraphsyncResponse(
        requestId: requestId,
        rootCid: rootCid,
      );

      _activeResponses[requestId] = response;

      final blocks = await _traverseGraph(rootCid, selector);
      response.addBlocks(blocks);

      _logger.debug('Sent ${blocks.length} blocks for request $requestId');
    } catch (e, stackTrace) {
      _logger.error('Error responding to request', e, stackTrace);
      rethrow;
    } finally {
      _activeResponses.remove(requestId);
    }
  }

  Future<List<Block>> _traverseGraph(
      String rootCid, List<String> selector) async {
    final blocks = <Block>[];
    final visited = <String>{};

    Future<void> traverse(String cid) async {
      if (visited.contains(cid)) return;
      visited.add(cid);

      final response = await _blockStore.getBlock(cid);
      if (!response.found) return;

      final block = Block.fromProto(response.block);
      blocks.add(block);

      if (selector.contains('links')) {
        final node = MerkleDAGNode.fromBytes(block.data);
        for (final link in node.links) {
          await traverse(link.cid.encode());
        }
      }
    }

    await traverse(rootCid);
    return blocks;
  }

  /// Gets the current status of the Graphsync handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'active_requests': _activeRequests.length,
      'active_responses': _activeResponses.length,
    };
  }
}

/// Internal class to track Graphsync requests
class _GraphsyncRequest {
  final String id;
  final String rootCid;
  final List<String> selector;
  final Duration timeout;
  Timer? _timeoutTimer;
  bool _cancelled = false;

  _GraphsyncRequest({
    required this.id,
    required this.rootCid,
    required this.selector,
    required this.timeout,
  }) {
    _timeoutTimer = Timer(timeout, cancel);
  }

  Future<void> cancel() async {
    _cancelled = true;
    _timeoutTimer?.cancel();
  }
}
