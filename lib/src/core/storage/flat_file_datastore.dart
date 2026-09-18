import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../platform/platform.dart';
import 'datastore.dart';

/// A file-system based implementation of [Datastore].
class FlatFileDatastore implements Datastore {
  /// Creates a datastore backed by files in [path].
  FlatFileDatastore(this.path);

  /// The root directory for stored data files.
  final String path;

  // Cache platform instance
  late final _platform = getPlatform();

  @override
  Future<void> init() async {
    if (!await _platform.exists(path)) {
      await _platform.createDirectory(path);
    }
  }

  String _getKeyPath(Key key) {
    // Convert Key to path. Key starts with /, remove it.
    var keyStr = key.toString();
    if (keyStr.startsWith('/')) {
      keyStr = keyStr.substring(1);
    }

    // Reject path traversal attempts
    if (keyStr.contains('..') || keyStr.contains('~') || keyStr.contains(':')) {
      throw ArgumentError('Invalid key: contains forbidden characters');
    }

    // Cross-platform path join and ensure it stays within the datastore
    final normalized = p.normalize(p.join(path, '$keyStr.data'));
    final basePath = p.normalize(path);
    if (!normalized.startsWith(basePath)) {
      throw ArgumentError('Key resolves outside datastore directory');
    }

    return normalized;
  }

  @override
  Future<void> put(Key key, Uint8List value) async {
    final filePath = _getKeyPath(key);
    await _platform.writeBytes(filePath, value);
  }

  @override
  Future<Uint8List?> get(Key key) async {
    final filePath = _getKeyPath(key);
    return await _platform.readBytes(filePath);
  }

  @override
  Future<bool> has(Key key) async {
    final filePath = _getKeyPath(key);
    return await _platform.exists(filePath);
  }

  @override
  Future<void> delete(Key key) async {
    final filePath = _getKeyPath(key);
    if (await _platform.exists(filePath)) {
      await _platform.delete(filePath);
    }
  }

  @override
  Stream<QueryEntry> query(Query q) async* {
    // Depth-first walk over the datastore directory. Every value is written
    // to a '<key>.data' file; other entries are traversed as subdirectories.
    final stack = [path];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final children = await _platform.listDirectory(current);

      for (final childPath in children) {
        // Everything the datastore writes ends in '.data'; any other entry
        // is a subdirectory that must be traversed.
        if (!childPath.endsWith('.data')) {
          stack.add(childPath);
          continue;
        }
        final relative = p.relative(childPath, from: path);
        final normalizedRelative = relative.replaceAll(r'\', '/');
        final keyStr =
            '/${normalizedRelative.substring(0, normalizedRelative.length - 5)}';
        final key = Key(keyStr);

        // Filter logic reused
        bool match = true;
        if (q.prefix != null && !keyStr.startsWith(q.prefix!)) match = false;

        if (match) {
          Uint8List? value;
          if (!q.keysOnly || (q.filters != null && q.filters!.isNotEmpty)) {
            value = await _platform.readBytes(childPath);
          }

          if (value != null && q.filters != null) {
            final entry = MapEntry(key, value);
            for (final filter in q.filters!) {
              if (!filter.filter(entry)) {
                match = false;
                break;
              }
            }
          }

          if (match) {
            yield QueryEntry(key, value);
          }
        }
      }
    }
  }

  @override
  Future<void> close() async {
    // No-op
  }
}
