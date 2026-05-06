// src/core/data_structures/blockstore.dart
import 'dart:io';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:path/path.dart' as p;

/// Persistent storage for content-addressed blocks in IPFS.
class BlockStore implements IBlockStore {
  /// Creates a new BlockStore at the given [path].
  BlockStore({required this.path}) : _logger = Logger('BlockStore') {
    _pinManager = PinManager(this);
  }
  final Map<String, Block> _blocks = {};
  late final PinManager _pinManager;

  /// The filesystem path where blocks are stored.
  final String path;

  /// Returns the pin manager for this blockstore.
  PinManager get pinManager => _pinManager;

  final Logger _logger;

  @override
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
  Future<GetBlockResponse> getBlock(String cid) async {
    try {
      // Check in-memory index first
      final cachedBlock = _blocks[cid];
      if (cachedBlock != null) {
        return BlockResponseFactory.successGet(cachedBlock.toProto());
      }

      // Try loading from disk if not in memory (lazy load)
      final blockFile = File(p.join(path, cid));
      if (await blockFile.exists()) {
        final data = await blockFile.readAsBytes();
        final block = await Block.fromData(data);
        _blocks[cid] = block; // Update index
        return BlockResponseFactory.successGet(block.toProto());
      }

      _logger.debug('Block not found: $cid');
      return BlockResponseFactory.notFound();
    } catch (e) {
      _logger.error('Failed to get block $cid', e);
      return BlockResponseFactory.notFound();
    }
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    try {
      final cidStr = block.cid.toString();

      // Save to disk first
      final blockFile = File(p.join(path, cidStr));
      final alreadyOnDisk = await blockFile.exists();
      final alreadyIndexed = _blocks.containsKey(cidStr);
      if (!alreadyOnDisk) {
        await blockFile.parent.create(recursive: true);
        await blockFile.writeAsBytes(block.data);
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
  Future<RemoveBlockResponse> removeBlock(String cid) async {
    try {
      final blockFile = File(p.join(path, cid));
      final fileExists = await blockFile.exists();
      final indexed = _blocks.containsKey(cid);

      if (!fileExists && !indexed) {
        _logger.debug('Block not found for removal: $cid');
        return BlockResponseFactory.failureRemove('Block not found: $cid');
      }

      if (fileExists) {
        await blockFile.delete();
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
  Future<bool> hasBlock(String cid) async {
    try {
      if (_blocks.containsKey(cid)) return true;
      return await File(p.join(path, cid)).exists();
    } catch (e) {
      _logger.error('Failed to check block existence', e);
      return false;
    }
  }

  @override
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
  Future<void> _initializeStorage() async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return;
    }

    // Load blocks from disk into index
    final files = dir.listSync();
    for (final entity in files) {
      if (entity is File) {
        final cid = p.basename(entity.path);
        if (cid == 'pins.json') continue; // Skip state file

        try {
          final data = await entity.readAsBytes();
          _blocks[cid] = await Block.fromData(data);
        } catch (e) {
          _logger.warning('Failed to load block file $cid: $e');
        }
      }
    }
  }

  Future<void> _cleanup() async {
    _blocks.clear();
  }
}
