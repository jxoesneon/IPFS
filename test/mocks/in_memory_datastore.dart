// test/mocks/in_memory_datastore.dart
import 'dart:async';
import 'package:dart_ipfs/src/storage/datastore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';

/// In-memory implementation of Datastore for testing.
///
/// Provides a lightweight, fast, and fully functional datastore
/// without requiring file system operations. Perfect for unit tests
/// and mocking complex integrations.
///
/// Unlike Hive-based datastore, this:
/// - Requires no temp directory setup
/// - Has instant cleanup (no file deletion)
/// - Is completely deterministic
/// - Supports concurrent operations safely
class InMemoryDatastore extends Datastore {
  final Map<String, Block> _blocks = {};
  final Set<String> _pinnedCIDs = {};
  bool _isOpen = false;

  InMemoryDatastore() : super('in-memory');

  @override
  Future<void> init() async {
    _isOpen = true;
  }

  @override
  Future<void> put(String cid, Block block) async {
    _ensureOpen();
    _blocks[cid] = block;
  }

  @override
  Future<Block?> get(String cid) async {
    _ensureOpen();
    return _blocks[cid];
  }

  @override
  Future<void> delete(String cid) async {
    _ensureOpen();
    if (await isPinned(cid)) {
      throw DatastoreError('Cannot delete pinned block');
    }
    _blocks.remove(cid);
  }

  @override
  Future<bool> has(String cid) async {
    _ensureOpen();
    return _blocks.containsKey(cid);
  }

  @override
  Future<void> pin(String cid) async {
    _ensureOpen();
    _pinnedCIDs.add(cid);
  }

  @override
  Future<void> unpin(String cid) async {
    _ensureOpen();
    _pinnedCIDs.remove(cid);
  }

  @override
  Future<bool> isPinned(String cid) async {
    _ensureOpen();
    return _pinnedCIDs.contains(cid);
  }

  @override
  Future<Set<String>> loadPinnedCIDs() async {
    _ensureOpen();
    return Set.from(_pinnedCIDs);
  }

  @override
  Future<void> persistPinnedCIDs(Set<String> pinnedCIDs) async {
    _ensureOpen();
    _pinnedCIDs.clear();
    _pinnedCIDs.addAll(pinnedCIDs);
  }

  @override
  Future<List<String>> getAllKeys() async {
    _ensureOpen();
    return _blocks.keys.toList();
  }

  @override
  Future<void> close() async {
    if (!_isOpen) return;
    _isOpen = false;
    _blocks.clear();
    _pinnedCIDs.clear();
  }

  @override
  int get numBlocks => _blocks.length;

  @override
  int get size {
    return _blocks.values.fold<int>(0, (sum, block) => sum + block.data.length);
  }

  /// Test helper: Check if datastore is open
  bool get isOpen => _isOpen;

  /// Test helper: Get all blocks (for verification)
  Map<String, Block> getAllBlocks() {
    return Map.unmodifiable(_blocks);
  }

  void _ensureOpen() {
    if (!_isOpen) {
      throw StateError('Datastore is closed');
    }
  }
}
