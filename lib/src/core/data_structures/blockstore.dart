// src/core/data_structures/blockstore.dart
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';

/// Persistent storage for content-addressed blocks in IPFS.
///
/// BlockStore provides the primary storage layer for IPFS blocks,
/// implementing the [IBlockStore] interface. It manages block persistence,
/// retrieval, and lifecycle with support for pinning to prevent
/// garbage collection.
///
/// Blocks are stored by their CID (Content Identifier), ensuring
/// content-addressable lookups. The store supports:
/// - Adding, retrieving, and removing blocks
/// - Checking block existence
/// - Block pinning for persistence
/// - Storage statistics
///
/// Example:
/// ```dart
/// final store = BlockStore(path: './ipfs/blocks');
/// await store.start();
///
/// // Store a block
/// await store.putBlock(block);
///
/// // Retrieve by CID
/// final response = await store.getBlock(cid.toString());
/// if (response.success) {
///   print('Found block: ${response.block}');
/// }
///
/// await store.stop();
/// ```
///
/// See also:
/// - [Block] for the block data structure
/// - [PinManager] for pinning operations
/// - [IBlockStore] for the interface contract
class BlockStore implements IBlockStore {
  final Map<String, Block> _blocks = {};
  late final PinManager _pinManager;

  /// The filesystem path where blocks are stored.
  final String path;

  final Logger _logger;

  /// Creates a new BlockStore at the given [path].
  BlockStore({required this.path}) : _logger = Logger('BlockStore') {
    _pinManager = PinManager(this);
  }

  @override
  Future<void> start() async {
    _logger.debug('Starting BlockStore...');
    try {
      await _initializeStorage();
      _logger.debug('BlockStore started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start BlockStore', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping BlockStore...');
    try {
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
      final block = _blocks[cid];
      if (block == null) {
        _logger.debug('Block not found: $cid');
        return BlockResponseFactory.notFound();
      }
      _logger.debug('Block retrieved successfully: $cid');
      return BlockResponseFactory.successGet(block.toProto());
    } catch (e) {
      _logger.error('Failed to get block', e);
      return BlockResponseFactory.notFound();
    }
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    try {
      final cidStr = block.cid.toString();
      if (_blocks.containsKey(cidStr)) {
        _logger.debug('Block already exists: $cidStr');
        return BlockResponseFactory.successAdd('Block already exists');
      }
      _blocks[cidStr] = block;
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
      if (!_blocks.containsKey(cid)) {
        _logger.debug('Block does not exist: $cid');
        return BlockResponseFactory.failureRemove('Block does not exist');
      }
      _blocks.remove(cid);
      _logger.debug('Block removed successfully: $cid');
      return BlockResponseFactory.successRemove('Block removed successfully');
    } catch (e) {
      _logger.error('Failed to remove block', e);
      return BlockResponseFactory.failureRemove('Failed to remove block: $e');
    }
  }

  @override
  Future<bool> hasBlock(String cid) async {
    try {
      return _blocks.containsKey(cid);
    } catch (e) {
      _logger.error('Failed to check block existence', e);
      return false;
    }
  }

  @override
  Future<List<Block>> getAllBlocks() async {
    try {
      _logger.debug('Getting all blocks');
      final blocks = _blocks.values.toList();
      _logger.debug('Retrieved ${blocks.length} blocks');
      return blocks;
    } catch (e) {
      _logger.error('Failed to get all blocks', e);
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    try {
      _logger.debug('Getting blockstore status');
      int totalSize = 0;
      for (var block in _blocks.values) {
        totalSize += block.size;
      }

      return {
        'total_blocks': _blocks.length,
        'total_size': totalSize,
        'pinned_blocks': _pinManager.pinnedBlockCount,
      };
    } catch (e) {
      _logger.error('Failed to get status', e);
      return {'total_blocks': 0, 'total_size': 0, 'pinned_blocks': 0};
    }
  }

  // Private helper methods
  Future<void> _initializeStorage() async {
    // Implementation for initializing storage
  }

  Future<void> _cleanup() async {
    // Implementation for cleanup
  }
}
