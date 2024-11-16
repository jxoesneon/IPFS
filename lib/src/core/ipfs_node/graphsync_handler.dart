// src/core/ipfs_node/graphsync_handler.dart
import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';

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
    IPLDSelector? selector,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _logger.debug('Requesting graph for root CID: $rootCid');

    try {
      final request = _GraphsyncRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rootCid: rootCid,
        selector: selector ?? IPLDSelector.all(),
        timeout: timeout,
      );

      _activeRequests[request.id] = request;
      _logger.verbose('Created request ${request.id} for CID: $rootCid');

      final blocks =
          await _traverseGraph(rootCid, selector ?? IPLDSelector.all());

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
      String requestId, String rootCid, IPLDSelector selector) async {
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
      String rootCid, IPLDSelector selector) async {
    final blocks = <Block>[];
    final visited = <String>{};
    final request = _activeRequests[rootCid];

    Future<void> traverse(String cid) async {
      if (request?._cancelled == true) {
        throw StateError('Request cancelled');
      }

      if (visited.contains(cid)) return;
      visited.add(cid);

      final response = await _blockStore.getBlock(cid);
      if (response.found && response.hasBlock()) {
        final blockProto = response.block;
        final block = Block.fromProto(blockProto);
        blocks.add(block);

        switch (selector.type) {
          case SelectorType.all:
            final node = MerkleDAGNode.fromBytes(block.data);
            for (final link in node.links) {
              await traverse(link.cid.toString());
            }
            break;

          case SelectorType.none:
            break;

          case SelectorType.matcher:
            if (_matchesCriteria(block, selector.criteria)) {
              final node = MerkleDAGNode.fromBytes(block.data);
              for (final link in node.links) {
                await traverse(link.cid.toString());
              }
            }
            break;

          case SelectorType.recursive:
            if (selector.maxDepth == null ||
                visited.length <= selector.maxDepth!) {
              final node = MerkleDAGNode.fromBytes(block.data);
              if (!selector.stopAtLink!) {
                for (final link in node.links) {
                  await traverse(link.cid.toString());
                }
              }
            }
            break;

          case SelectorType.explore:
            if (selector.fieldPath != null) {
              final node = MerkleDAGNode.fromBytes(block.data);
              final value = _resolveFieldPath(node, selector.fieldPath!);
              if (value is String && value.startsWith('ipfs://')) {
                await traverse(value.substring(7));
              }
            }
            break;

          case SelectorType.union:
            final node = MerkleDAGNode.fromBytes(block.data);
            for (final subSelector in selector.subSelectors ?? []) {
              if (_matchesCriteria(block, subSelector.criteria)) {
                for (final link in node.links) {
                  await traverse(link.cid.toString());
                }
                break;
              }
            }
            break;

          case SelectorType.intersection:
          case SelectorType.condition:
            final node = MerkleDAGNode.fromBytes(block.data);
            if (_matchesCriteria(block, selector.criteria)) {
              for (final link in node.links) {
                await traverse(link.cid.toString());
              }
            }
            break;

          case SelectorType.exploreRecursive:
            if (selector.maxDepth == null ||
                visited.length <= selector.maxDepth!) {
              final node = MerkleDAGNode.fromBytes(block.data);
              blocks.add(block);
              for (final link in node.links) {
                await traverse(link.cid.toString());
              }
            }
            break;

          case SelectorType.exploreUnion:
            final node = MerkleDAGNode.fromBytes(block.data);
            for (final subSelector in selector.subSelectors ?? []) {
              if (_matchesCriteria(block, subSelector.criteria)) {
                for (final link in node.links) {
                  await traverse(link.cid.toString());
                }
              }
            }
            break;

          case SelectorType.exploreAll:
            final node = MerkleDAGNode.fromBytes(block.data);
            blocks.add(block);
            for (final link in node.links) {
              await traverse(link.cid.toString());
            }
            break;

          case SelectorType.exploreRange:
            final node = MerkleDAGNode.fromBytes(block.data);
            if (node.links.isNotEmpty) {
              final start = selector.startIndex ?? 0;
              final end = selector.endIndex ?? node.links.length;
              for (var i = start; i < end && i < node.links.length; i++) {
                await traverse(node.links[i].cid.toString());
              }
            }
            break;

          case SelectorType.exploreFields:
            final node = MerkleDAGNode.fromBytes(block.data);
            for (final field in selector.fields ?? []) {
              final value = _resolveFieldPath(node, field);
              if (value is String && value.startsWith('ipfs://')) {
                await traverse(value.substring(7));
              }
            }
            break;

          case SelectorType.exploreIndex:
            final node = MerkleDAGNode.fromBytes(block.data);
            final index = selector.startIndex ?? 0;
            if (index >= 0 && index < node.links.length) {
              await traverse(node.links[index].cid.toString());
            }
            break;
        }
      }
    }

    await traverse(rootCid);
    return blocks;
  }

  bool _matchesCriteria(Block block, Map<String, dynamic> criteria) {
    if (criteria.isEmpty) return true;

    try {
      final node = MerkleDAGNode.fromBytes(block.data);
      for (final entry in criteria.entries) {
        final value = _resolveFieldPath(node, entry.key);
        if (value == null || value != entry.value) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  dynamic _resolveFieldPath(MerkleDAGNode node, String path) {
    final parts = path.split('.');
    dynamic current = node;

    for (final part in parts) {
      if (current == null) return null;
      if (current is MerkleDAGNode) {
        switch (part) {
          case 'cid':
            current = current.cid;
            break;
          case 'links':
            current = current.links;
            break;
          case 'data':
            current = current.data;
            break;
          default:
            current = null;
        }
      } else if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
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
  final IPLDSelector selector;
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

/// Internal class to track Graphsync responses
class _GraphsyncResponse {
  final String requestId;
  final String rootCid;
  final List<Block> _blocks = [];
  bool _cancelled = false;

  _GraphsyncResponse({
    required this.requestId,
    required this.rootCid,
  });

  void addBlocks(List<Block> blocks) {
    if (!_cancelled) {
      _blocks.addAll(blocks);
    }
  }

  List<Block> get blocks => List.unmodifiable(_blocks);

  Future<void> cancel() async {
    _cancelled = true;
    _blocks.clear();
  }

  bool get isCancelled => _cancelled;
}
