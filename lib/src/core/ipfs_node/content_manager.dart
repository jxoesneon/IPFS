// src/core/ipfs_node/content_manager.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as fixnum;

import '../../proto/generated/core/pin.pb.dart';
import '../../protocols/bitswap/bitswap_handler.dart';
import '../../transport/http_gateway_client.dart';
import '../../utils/logger.dart';
import '../cid.dart';
import '../data_structures/block.dart';
import '../data_structures/blockstore.dart';
import '../data_structures/directory.dart';
import '../data_structures/link.dart';
import '../data_structures/merkle_dag_node.dart';
import '../data_structures/pin.dart';
import '../errors/node_errors.dart';
import '../interfaces/i_lifecycle.dart';
import '../security/denylist_service.dart';
import '../storage/datastore.dart';
import 'datastore_handler.dart';
import 'ipfs_node.dart';

/// Manages content-related operations for the IPFS node.
class ContentManager implements ILifecycle {
  /// Creates a [ContentManager] with injected dependencies.
  ContentManager({
    required DatastoreHandler datastoreHandler,
    required StreamController<String> newContentController,
    BlockStore? blockStore,
    BitswapHandler? bitswapHandler,
    DenylistService? denylistService,
  }) : _datastoreHandler = datastoreHandler,
       _newContentController = newContentController,
       _blockStore = blockStore,
       _bitswapHandler = bitswapHandler,
       _denylistService = denylistService,
       _logger = Logger('ContentManager');

  final DatastoreHandler _datastoreHandler;
  final BlockStore? _blockStore;
  final BitswapHandler? _bitswapHandler;
  final DenylistService? _denylistService;
  final Logger _logger;
  final HttpGatewayClient _httpGatewayClient = HttpGatewayClient();
  final StreamController<String> _newContentController;

  @override
  Future<void> start() async {
    _logger.debug('Starting ContentManager...');
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping ContentManager...');
  }

  /// Adds a raw file to IPFS and returns its CID.
  Future<String> addFile(Uint8List data) async {
    try {
      final block = await Block.fromData(data);
      await _datastoreHandler.putBlock(block);
      await _blockStore?.putBlock(block);
      _newContentController.add(block.cid.toString());
      _logger.info('Added file with CID: ${block.cid}');
      return block.cid.toString();
    } catch (e, stackTrace) {
      _logger.error('Error adding file', e, stackTrace);
      rethrow;
    }
  }

  /// Adds file content from a [dataStream].
  Future<String> addFileStream(Stream<List<int>> dataStream) async {
    try {
      final builder = BytesBuilder();
      await for (final chunk in dataStream) {
        builder.add(chunk);
      }
      return addFile(builder.takeBytes());
    } catch (e, stackTrace) {
      _logger.error('Error adding file from stream', e, stackTrace);
      rethrow;
    }
  }

  /// Adds a directory to IPFS and returns its root CID.
  Future<String> addDirectory(Map<String, dynamic> directoryContent) async {
    try {
      final directoryManager = IPFSDirectoryManager();

      for (final entry in directoryContent.entries) {
        final name = entry.key;
        final value = entry.value;

        if (value is Uint8List) {
          final cid = await addFile(value);
          directoryManager.addEntry(
            IPFSDirectoryEntry(
              name: name,
              hash: CID.decode(cid).toBytes(),
              size: fixnum.Int64(value.length),
              isDirectory: false,
            ),
          );
        } else if (value is Map<String, dynamic>) {
          final subDirCid = await addDirectory(value);
          directoryManager.addEntry(
            IPFSDirectoryEntry(
              name: name,
              hash: CID.decode(subDirCid).toBytes(),
              size: fixnum.Int64(0),
              isDirectory: true,
            ),
          );
        } else {
          _logger.warning(
            'Skipping unsupported directory entry type: ${value.runtimeType}',
          );
        }
      }

      final pbNode = directoryManager.build();
      final block = await Block.fromData(
        pbNode.writeToBuffer(),
        format: 'dag-pb',
      );

      await _datastoreHandler.putBlock(block);
      await _blockStore?.putBlock(block);
      _logger.info('Added directory with CID: ${block.cid}');
      return block.cid.toString();
    } catch (e, stackTrace) {
      _logger.error('Error adding directory', e, stackTrace);
      rethrow;
    }
  }

  /// Gets the content associated with [cid].
  Future<Uint8List?> get(
    String cid, {
    String path = '',
    GatewayMode gatewayMode = GatewayMode.internal,
    String customGatewayUrl = '',
  }) async {
    try {
      final denylist = _denylistService;
      if (denylist != null && denylist.isBlockedByCidString(cid)) {
        final action = denylist.recordHit(cid, source: 'rpc');
        if (action == 'block') {
          throw StateError('Content blocked by operator policy');
        }
      }

      if (gatewayMode != GatewayMode.internal) {
        return await _getViaGateway(cid, gatewayMode, customGatewayUrl);
      }

      final block = await _datastoreHandler.getBlock(cid);

      if (block != null) {
        return await _extractBlockData(block, path);
      }

      final blockResult = await _blockStore?.getBlock(cid);
      if (blockResult != null && blockResult.found) {
        return await _extractBlockData(
          Block.fromProto(blockResult.block),
          path,
        );
      }

      if (_bitswapHandler != null) {
        _logger.debug('Attempting to retrieve block $cid via Bitswap');
        final networkBlock = await _bitswapHandler.wantBlock(cid);
        if (networkBlock != null) {
          await _datastoreHandler.putBlock(networkBlock);
          return networkBlock.data;
        }
      }

      _logger.debug(
        'P2P retrieval failed, attempting HTTP gateway fallback for $cid',
      );
      return await _httpGatewayClient.get(cid);
    } catch (e, stackTrace) {
      _logger.error('Error retrieving content for CID $cid', e, stackTrace);
      return null;
    }
  }

  Future<Uint8List?> _getViaGateway(
    String cid,
    GatewayMode mode,
    String customUrl,
  ) async {
    String url;
    switch (mode) {
      case GatewayMode.public:
        url = 'https://ipfs.io/ipfs';
        break;
      case GatewayMode.local:
        url = 'http://127.0.0.1:8080/ipfs';
        break;
      case GatewayMode.custom:
        url = customUrl;
        break;
      default:
        url = 'https://ipfs.io/ipfs';
    }
    _logger.debug('Retrieving via Gateway ($url): $cid');
    return await _httpGatewayClient.get(cid, baseUrl: url);
  }

  Future<Uint8List?> _extractBlockData(Block block, String path) async {
    if (path.isEmpty) {
      return block.data;
    } else {
      final node = MerkleDAGNode.fromBytes(block.data);
      if (node.isDirectory) {
        return await _resolvePathInDirectory(node, path);
      }
    }
    return null;
  }

  Future<Uint8List?> _resolvePathInDirectory(
    MerkleDAGNode dirNode,
    String path,
  ) async {
    final pathParts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (pathParts.isEmpty) return null;

    for (final link in dirNode.links) {
      if (link.name == pathParts[0]) {
        final childBlock = await _datastoreHandler.getBlock(
          link.cid.toString(),
        );
        if (childBlock == null) return null;

        if (pathParts.length == 1) {
          return childBlock.data;
        } else {
          final childNode = MerkleDAGNode.fromBytes(childBlock.data);
          return await _resolvePathInDirectory(
            childNode,
            pathParts.sublist(1).join('/'),
          );
        }
      }
    }
    return null;
  }

  /// Lists the links within a directory identified by [cid].
  Future<List<Link>> ls(String cid) async {
    try {
      Block? block = await _datastoreHandler.getBlock(cid);

      if (block == null && _bitswapHandler != null) {
        block = await _bitswapHandler.wantBlock(cid);
      }

      if (block == null) {
        final blockResult = await _blockStore?.getBlock(cid);
        if (blockResult != null && blockResult.found) {
          block = Block.fromProto(blockResult.block);
        }
      }

      if (block == null) {
        _logger.warning('Directory not found: $cid');
        return [];
      }

      try {
        final node = MerkleDAGNode.fromBytes(block.data);
        if (!node.isDirectory) {
          _logger.warning('CID does not point to a directory: $cid');
          return [];
        }

        return node.links;
      } catch (e) {
        _logger.warning('Failed to parse MerkleDAGNode for CID $cid: $e');
        return [];
      }
    } catch (e, stackTrace) {
      _logger.error('Error listing directory $cid', e, stackTrace);
      rethrow;
    }
  }

  /// Recursively pins a [cid] to prevent garbage collection.
  Future<void> pin(String cid) async {
    try {
      if (_blockStore == null) {
        throw ComponentError('BlockStore', 'Required for pinning');
      }

      final pin = Pin(
        cid: CID.decode(cid),
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: _blockStore,
      );

      final success = await pin.pin();
      if (!success) {
        throw Exception('Failed to pin CID: $cid');
      }

      await _datastoreHandler.persistPinnedCIDs({cid});
      _logger.info('Pinned CID: $cid');
    } catch (e, stackTrace) {
      _logger.error('Error pinning CID $cid', e, stackTrace);
      rethrow;
    }
  }

  /// Unpins a [cid] from the node.
  Future<bool> unpin(String cid) async {
    try {
      if (_blockStore == null) {
        throw ComponentError('BlockStore', 'Required for unpinning');
      }

      final pin = Pin(
        cid: CID.decode(cid),
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: _blockStore,
      );

      final success = await pin.unpin();
      if (success) {
        final pinKey = Key('/pins/$cid');
        await _datastoreHandler.datastore.delete(pinKey);
      }
      _logger.info('Unpinned CID: $cid (Success: $success)');
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error unpinning CID $cid', e, stackTrace);
      return false;
    }
  }

  /// Imports blocks from a [carFile] into the local datastore.
  Future<void> importCAR(Uint8List carFile) async {
    try {
      await _datastoreHandler.importCAR(carFile);
      _logger.info('Imported CAR file successfully');
    } catch (e, stackTrace) {
      _logger.error('Error importing CAR file', e, stackTrace);
      rethrow;
    }
  }

  /// Exports the DAG rooted at [cid] as a [Uint8List] in CAR format.
  Future<Uint8List> exportCAR(String cid) async {
    try {
      final carData = await _datastoreHandler.exportCAR(cid);
      _logger.info('Exported CAR for CID: $cid');
      return carData;
    } catch (e, stackTrace) {
      _logger.error('Error exporting CAR file for CID $cid', e, stackTrace);
      rethrow;
    }
  }
}
