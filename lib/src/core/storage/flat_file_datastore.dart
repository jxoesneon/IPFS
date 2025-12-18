import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'datastore.dart';

/// A file-system based implementation of [Datastore].
class FlatFileDatastore implements Datastore {

  FlatFileDatastore(this.path);
  final String path;

  @override
  Future<void> init() async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  File _getKeyFile(Key key) {
    // Convert Key to path. Key starts with /, remove it.
    var keyStr = key.toString();
    if (keyStr.startsWith('/')) {
      keyStr = keyStr.substring(1);
    }

    // Simple sharding/nesting can be done here if needed.
    // For now, map /a/b/c to path/a/b/c.data
    // Appending .data to avoid conflicts with directories if keys overlap node names?
    // In strict key-value, /a and /a/b usually don't coexist as value-bearing nodes?
    // Actually they might. So we should use `.data` extension or similar.

    return File(p.join(path, '$keyStr.data'));
  }

  @override
  Future<void> put(Key key, Uint8List value) async {
    final file = _getKeyFile(key);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(value, flush: true);
  }

  @override
  Future<Uint8List?> get(Key key) async {
    final file = _getKeyFile(key);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<bool> has(Key key) async {
    final file = _getKeyFile(key);
    return await file.exists();
  }

  @override
  Future<void> delete(Key key) async {
    final file = _getKeyFile(key);
    if (await file.exists()) {
      await file.delete();
      // Optional: Cleanup empty parent directories
    }
  }

  @override
  Stream<QueryEntry> query(Query q) async* {
    // Naive implementation: Walk directory
    // This is inefficient for large datasets but sufficient for the interface contract MVP.
    // For production, use an index (like BadgerDB or LevelDB wraps).
    // FlatFile is mostly for config or small data.

    final rootDir = Directory(path);
    if (!await rootDir.exists()) return;

    await for (final f in rootDir.list(recursive: true)) {
      if (f is File && f.path.endsWith('.data')) {
        // Reverse map path to Key
        final relative = p.relative(f.path, from: path);
        // Remove .data and add /
        final keyStr = '/${relative.substring(0, relative.length - 5)}';
        final key = Key(keyStr);

        // Apply filters
        bool match = true;
        if (q.prefix != null && !keyStr.startsWith(q.prefix!)) match = false;

        if (match && q.filters != null) {
          // Optimization: Load value only if needed for filter?
          // Most filters operate on Key/Value.
          // We load value lazily? QueryEntry handles it?
          // Interface expects entry with value appropriately.
          // For now, load.
          final value = await f.readAsBytes();
          final entry = MapEntry(key, value);
          for (final filter in q.filters!) {
            if (!filter.filter(entry)) {
              match = false;
              break;
            }
          }
          if (match) {
            yield QueryEntry(key, q.keysOnly ? null : value);
          }
        } else if (match) {
          Uint8List? value;
          if (!q.keysOnly) {
            value = await f.readAsBytes();
          }
          yield QueryEntry(key, value);
        }
      }
    }
    // Sorting/Offset/Limit handled by receiver or we implement buffering here?
    // MemoryDatastore buffered. Streams are lazy.
    // Ideally we apply Limit here to stop walking.
    // But sorting requires buffering.
  }

  @override
  Future<void> close() async {
    // No-op for file system
  }
}
