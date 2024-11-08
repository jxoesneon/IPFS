import 'dart:async';
import '../utils/logger.dart';
import 'package:hive/hive.dart';
import '../core/data_structures/block.dart';
// lib/src/storage/datastore.dart

class DatastoreError extends Error {
  final String message;
  DatastoreError(this.message);

  @override
  String toString() => 'DatastoreError: $message';
}

/// Persistent datastore implementation using Hive
class Datastore {
  static const String BLOCKS_BOX = 'blocks';
  static const String PINS_BOX = 'pins';

  final String _basePath;
  late final Box<List<int>> _blocksBox;
  late final Box<bool> _pinsBox;
  final _logger = Logger('Datastore');

  Datastore(this._basePath);

  /// Initializes the datastore
  Future<void> init() async {
    try {
      Hive.init(_basePath);

      _blocksBox = await Hive.openBox<List<int>>(BLOCKS_BOX);
      _pinsBox = await Hive.openBox<bool>(PINS_BOX);

      _logger.info('Datastore initialized at: $_basePath');
    } catch (e, stack) {
      _logger.error('Failed to initialize datastore', e, stack);
      throw DatastoreError('Initialization failed: $e');
    }
  }

  /// Stores a block
  Future<void> put(String cid, Block block) async {
    try {
      await _blocksBox.put(cid, block.data);
      _logger.debug('Stored block: $cid');
    } catch (e) {
      _logger.error('Failed to store block: $cid', e);
      throw DatastoreError('Failed to store block: $e');
    }
  }

  /// Retrieves a block by CID
  Future<Block?> get(String cid) async {
    try {
      final data = await _blocksBox.get(cid);
      if (data == null) return null;

      return Block.fromData(data);
    } catch (e) {
      _logger.error('Failed to retrieve block: $cid', e);
      throw DatastoreError('Failed to retrieve block: $e');
    }
  }

  /// Pins a block
  Future<void> pin(String cid) async {
    await _pinsBox.put(cid, true);
    _logger.debug('Pinned block: $cid');
  }

  /// Unpins a block
  Future<void> unpin(String cid) async {
    await _pinsBox.delete(cid);
    _logger.debug('Unpinned block: $cid');
  }

  /// Checks if a block is pinned
  Future<bool> isPinned(String cid) async {
    return await _pinsBox.get(cid) ?? false;
  }

  /// Checks if a block exists in the datastore
  Future<bool> has(String cid) async {
    try {
      final exists = await _blocksBox.containsKey(cid);
      _logger.debug('Block existence check: $cid = $exists');
      return exists;
    } catch (e) {
      _logger.error('Failed to check block existence: $cid', e);
      throw DatastoreError('Failed to check block existence: $e');
    }
  }

  /// Closes the datastore
  Future<void> close() async {
    await _blocksBox.close();
    await _pinsBox.close();
    _logger.info('Datastore closed');
  }

  /// Loads all pinned CIDs from storage
  Future<Set<String>> loadPinnedCIDs() async {
    try {
      final pinnedCIDs =
          await _pinsBox.keys.map((key) => key.toString()).toSet();
      _logger.debug('Loaded ${pinnedCIDs.length} pinned CIDs');
      return pinnedCIDs;
    } catch (e) {
      _logger.error('Failed to load pinned CIDs', e);
      throw DatastoreError('Failed to load pinned CIDs: $e');
    }
  }

  /// Persists a set of pinned CIDs to storage
  Future<void> persistPinnedCIDs(Set<String> pinnedCIDs) async {
    try {
      // Clear existing pins
      await _pinsBox.clear();

      // Add new pins
      for (final cid in pinnedCIDs) {
        await _pinsBox.put(cid, true);
      }
      _logger.debug('Persisted ${pinnedCIDs.length} pinned CIDs');
    } catch (e) {
      _logger.error('Failed to persist pinned CIDs', e);
      throw DatastoreError('Failed to persist pinned CIDs: $e');
    }
  }

  /// Deletes a block from storage
  Future<void> delete(String cid) async {
    try {
      if (await isPinned(cid)) {
        throw DatastoreError('Cannot delete pinned block');
      }

      await _blocksBox.delete(cid);
      _logger.debug('Deleted block: $cid');
    } catch (e) {
      _logger.error('Failed to delete block: $cid', e);
      throw DatastoreError('Failed to delete block: $e');
    }
  }

  /// Returns the total number of blocks in the datastore
  int get numBlocks => _blocksBox.length;

  /// Returns the total size of all blocks in the datastore in bytes
  int get size {
    int totalSize = 0;
    for (var data in _blocksBox.values) {
      totalSize += data.length;
    }
    return totalSize;
  }
}
