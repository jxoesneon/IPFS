import 'dart:async';
import 'dart:typed_data';
import 'datastore.dart';

/// An in-memory implementation of [Datastore].
/// Useful for testing and ephemeral nodes.
class MemoryDatastore implements Datastore {
  final Map<Key, Uint8List> _data = {};

  @override
  Future<void> init() async {
    // No-op
  }

  @override
  Future<void> put(Key key, Uint8List value) async {
    _data[key] = value;
  }

  @override
  Future<Uint8List?> get(Key key) async {
    return _data[key];
  }

  @override
  Future<bool> has(Key key) async {
    return _data.containsKey(key);
  }

  @override
  Future<void> delete(Key key) async {
    _data.remove(key);
  }

  @override
  Stream<QueryEntry> query(Query q) async* {
    var entries = _data.entries.toList();

    // 1. Filtering
    if (q.prefix != null) {
      entries = entries.where((e) => e.key.toString().startsWith(q.prefix!)).toList();
    }

    if (q.filters != null) {
      for (final filter in q.filters!) {
        entries = entries.where((e) => filter.filter(e)).toList();
      }
    }

    // 2. Sorting
    if (q.orders != null) {
      for (final order in q.orders!) {
        entries.sort((a, b) => order.compare(a, b));
      }
    }

    // 3. Offset
    if (q.offset != null) {
      entries = entries.skip(q.offset!).toList();
    }

    // 4. Limit
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
    _data.clear();
  }
}
