// test/mocks/in_memory_datastore.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/storage/datastore.dart';

/// In-memory implementation of Datastore for testing.
///
/// Provides a lightweight, fast, and fully functional datastore
/// without requiring file system operations. Perfect for unit tests
/// and mocking complex integrations.
class InMemoryDatastore implements Datastore {
  final Map<Key, Uint8List> _data = {};
  bool _isOpen = false;

  @override
  Future<void> init() async {
    _isOpen = true;
  }

  @override
  Future<void> put(Key key, Uint8List value) async {
    _ensureOpen();
    _data[key] = value;
  }

  @override
  Future<Uint8List?> get(Key key) async {
    _ensureOpen();
    return _data[key];
  }

  @override
  Future<bool> has(Key key) async {
    _ensureOpen();
    return _data.containsKey(key);
  }

  @override
  Future<void> delete(Key key) async {
    _ensureOpen();
    _data.remove(key);
  }

  @override
  Stream<QueryEntry> query(Query q) async* {
    _ensureOpen();
    var entries = _data.entries.toList();

    // 1. Filtering by prefix
    if (q.prefix != null) {
      entries = entries.where((e) => e.key.toString().startsWith(q.prefix!)).toList();
    }

    // 2. Filtering
    if (q.filters != null) {
      for (final filter in q.filters!) {
        entries = entries.where((e) => filter.filter(e)).toList();
      }
    }

    // 3. Sorting
    if (q.orders != null) {
      for (final order in q.orders!) {
        entries.sort((a, b) => order.compare(a, b));
      }
    }

    // 4. Offset
    if (q.offset != null) {
      entries = entries.skip(q.offset!).toList();
    }

    // 5. Limit
    if (q.limit != null) {
      entries = entries.take(q.limit!).toList();
    }

    // Yield
    for (final entry in entries) {
      yield QueryEntry(entry.key, q.keysOnly ? null : entry.value);
    }
  }

  @override
  Future<void> close() async {
    if (!_isOpen) return;
    _isOpen = false;
    _data.clear();
  }

  /// Test helper: Check if datastore is open
  bool get isOpen => _isOpen;

  /// Test helper: Get all data (for verification)
  Map<Key, Uint8List> getAllData() {
    return Map.unmodifiable(_data);
  }

  void _ensureOpen() {
    if (!_isOpen) {
      throw StateError('Datastore is closed');
    }
  }
}
