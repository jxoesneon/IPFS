// src/core/data_structures/blockstore.dart
import 'dart:async';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:path/path.dart' as p;

/// Persistent storage for content-addressed blocks in IPFS.
///
/// **Platform Note**: Storage behavior is platform-dependent. On VM platforms,
/// it uses the local file system. On Web platforms, it uses IndexedDB via the
/// [IpfsPlatform] abstraction.
class BlockStore implements IBlockStore {
  /// Creates a new [BlockStore] at the given [path].
  BlockStore({required this.path}) : _logger = Logger('BlockStore') {
    _pinManager = PinManager(this);
  }
  final Map<String, Block> _blocks = {};
  late final PinManager _pinManager;

  /// The filesystem path where blocks are stored.
  final String path;

  /// Returns the [PinManager] for this blockstore.
  PinManager get pinManager => _pinManager;

  final Logger _logger;

  @override
  /// Returns a [Future] that completes when the [BlockStore] and its pin manager have started.
  Future<void> start() async {
    _logger.debug('Starting BlockStore at $path...');
    try {
      await _initializeStorage();

      // Load pin state
      final pinsFile = p.join(path, 'pins.json');
      await _pinManager.load(pinsFile);

      _logger.debug(
        'BlockStore started successfully with ${_blocks.length} blocks',
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to start BlockStore', e, stackTrace);
      rethrow;
    }
  }

  @override
  /// Returns a [Future] that completes when the [BlockStore] has stopped and its state is saved.
  Future<void> stop() async {
    _logger.debug('Stopping BlockStore...');
    try {
      // Save pin state
      final pinsFile = p.join(path, 'pins.json');
      await _pinManager.save(pinsFile);

      await _cleanup();
      _logger.debug('BlockStore stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop BlockStore', e, stackTrace);
      rethrow;
    }
  }

  @override
  /// Returns a [Future] that resolves to a [GetBlockResponse] for the given [cid].
  Future<GetBlockResponse> getBlock(String cid) async {
    try {
      // Check in-memory index first
      final cachedBlock = _blocks[cid];
      if (cachedBlock != null) {
        return BlockResponseFactory.successGet(cachedBlock.toProto());
      }

      // Try loading from disk if not in memory (lazy load)
      final blockPath = p.join(path, cid);
      if (await getPlatform().exists(blockPath)) {
        final data = await getPlatform().readBytes(blockPath);
        if (data != null) {
          final block = await Block.fromData(data);
          _blocks[cid] = block; // Update index
          return BlockResponseFactory.successGet(block.toProto());
        }
      }

      _logger.debug('Block not found: $cid');
      return BlockResponseFactory.notFound();
    } catch (e) {
      _logger.error('Failed to get block $cid', e);
      return BlockResponseFactory.notFound();
    }
  }

  @override
  /// Returns a [Future] that resolves to an [AddBlockResponse] after storing the given [block].
  Future<AddBlockResponse> putBlock(Block block) async {
    try {
      final cidStr = block.cid.toString();
      final blockPath = p.join(path, cidStr);

      // Save to disk first
      final alreadyOnDisk = await getPlatform().exists(blockPath);
      final alreadyIndexed = _blocks.containsKey(cidStr);
      if (!alreadyOnDisk) {
        await getPlatform().writeBytes(blockPath, block.data);
      }

      // Update index
      _blocks[cidStr] = block;

      if (alreadyOnDisk || alreadyIndexed) {
        _logger.debug('Block already exists: $cidStr');
        return BlockResponseFactory.successAdd('Block already exists');
      }

      _logger.debug('Block added successfully: $cidStr');
      return BlockResponseFactory.successAdd('Block added successfully');
    } catch (e) {
      _logger.error('Failed to put block', e);
      return BlockResponseFactory.failureAdd('Failed to put block: $e');
    }
  }

  @override
  /// Returns a [Future] that resolves to a [RemoveBlockResponse] after removing the block with the given [cid].
  Future<RemoveBlockResponse> removeBlock(String cid) async {
    try {
      final blockPath = p.join(path, cid);
      final fileExists = await getPlatform().exists(blockPath);
      final indexed = _blocks.containsKey(cid);

      if (!fileExists && !indexed) {
        _logger.debug('Block not found for removal: $cid');
        return BlockResponseFactory.failureRemove('Block not found: $cid');
      }

      if (fileExists) {
        await getPlatform().delete(blockPath);
      }
      _blocks.remove(cid);
      _logger.debug('Block removed successfully: $cid');
      return BlockResponseFactory.successRemove('Block removed successfully');
    } catch (e) {
      _logger.error('Failed to remove block $cid', e);
      return BlockResponseFactory.failureRemove('Failed to remove block: $e');
    }
  }

  @override
  /// Returns a [Future] that resolves to `true` if a block with the given [cid] exists.
  Future<bool> hasBlock(String cid) async {
    try {
      if (_blocks.containsKey(cid)) return true;
      return await getPlatform().exists(p.join(path, cid));
    } catch (e) {
      _logger.error('Failed to check block existence', e);
      return false;
    }
  }

  @override
  /// Returns a [Future] that resolves to a [List] of all [Block]s in the store.
  Future<List<Block>> getAllBlocks() async {
    try {
      _logger.debug('Getting all blocks');
      return _blocks.values.toList();
    } catch (e) {
      _logger.error('Failed to get all blocks', e);
      return [];
    }
  }

  @override
  /// Returns a [Future] that resolves to a status map for the [BlockStore].
  Future<Map<String, dynamic>> getStatus() async {
    try {
      int totalSize = 0;
      for (var block in _blocks.values) {
        totalSize += block.size;
      }

      return {
        'total_blocks': _blocks.length,
        'total_size': totalSize,
        'pinned_blocks': _pinManager.pinnedBlockCount,
        'path': path,
      };
    } catch (e) {
      _logger.error('Failed to get status', e);
      return {'total_blocks': 0, 'total_size': 0, 'pinned_blocks': 0};
    }
  }

  @override
  /// Returns a [Future] that resolves to the number of blocks removed during garbage collection.
  ///
  /// Removes all unpinned blocks from the store.
  Future<int> gc() async {
    _logger.info('Starting Garbage Collection...');
    int removedCount = 0;

    // Get all CIDs from the current index
    final allCids = _blocks.keys.toList();

    for (final cidStr in allCids) {
      try {
        final cid = CID.decode(cidStr);
        if (!_pinManager.isBlockPinned(cid.toProto())) {
          await removeBlock(cidStr);
          removedCount++;
        }
      } catch (e) {
        _logger.warning('Failed to process block $cidStr during GC: $e');
      }
    }

    _logger.info('Garbage Collection finished. Removed $removedCount blocks.');
    return removedCount;
  }

  // Private helper methods
  /// Returns a [Future] that completes when the storage is initialized and blocks are loaded into memory.
  Future<void> _initializeStorage() async {
    if (!await getPlatform().exists(path)) {
      await getPlatform().createDirectory(path);
      return;
    }

    // Load blocks from disk into index
    final files = await getPlatform().listDirectory(path);
    for (final filePath in files) {
      final cid = p.basename(filePath);
      if (cid == 'pins.json') continue; // Skip state file

      try {
        final data = await getPlatform().readBytes(filePath);
        if (data != null) {
          _blocks[cid] = await Block.fromData(data);
        }
      } catch (e) {
        _logger.warning('Failed to load block file $cid: $e');
      }
    }
  }

  /// Returns a [Future] that completes when the in-memory block index is cleared.
  Future<void> _cleanup() async {
    _blocks.clear();
  }
}
