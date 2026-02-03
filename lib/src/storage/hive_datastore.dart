import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:hive/hive.dart';

/// Hive-based implementation of the [Datastore] interface.
///
/// This enterprise-grade implementation provides persistent key-value storage
/// using Hive, with automatic key routing to specialized boxes based on
/// key prefixes for optimal performance and organization.
///
/// **Key Routing:**
/// - `/blocks/*` → blocks box (block data storage)
/// - `/pins/*` → pins box (pinning metadata)
/// - `/dht/*` → dht box (DHT protocol data)
/// - All other keys → default box
///
/// **Thread Safety:** All operations are atomic at the Hive level.
/// **Consistency:** All boxes use `List<int>` storage for uniform API.
class HiveDatastore implements Datastore {
  /// Creates a HiveDatastore instance with the specified base path.
  ///
  /// Call [init] before using any other methods.
  HiveDatastore(this._basePath);
  static const String _boxBlocks = 'blocks';
  static const String _boxPins = 'pins';
  static const String _boxDht = 'dht';
  static const String _boxDefault = 'default';

  final String _basePath;
  late final Box<List<int>> _blocksBox;
  late final Box<List<int>> _pinsBox;
  late final Box<List<int>> _dhtBox;
  late final Box<List<int>> _defaultBox;

  final _logger = Logger('HiveDatastore');
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;

    try {
      Hive.init(_basePath);
      _blocksBox = await Hive.openBox<List<int>>(_boxBlocks);
      _pinsBox = await Hive.openBox<List<int>>(_boxPins);
      _dhtBox = await Hive.openBox<List<int>>(_boxDht);
      _defaultBox = await Hive.openBox<List<int>>(_boxDefault);
      _initialized = true;
      _logger.info('HiveDatastore initialized at $_basePath');
    } catch (e) {
      _logger.error('Failed to initialize HiveDatastore', e);
      rethrow;
    }
  }

  /// Routes a key to the appropriate Hive box based on its prefix.
  Box<List<int>> _getBox(Key key) {
    final path = key.toString();
    if (path.startsWith('/blocks/')) return _blocksBox;
    if (path.startsWith('/pins/')) return _pinsBox;
    if (path.startsWith('/dht/')) return _dhtBox;
    return _defaultBox;
  }

  /// Extracts the inner key by stripping the routing prefix.
  String _getInnerKey(Key key) {
    final path = key.toString();
    if (path.startsWith('/blocks/')) return path.substring('/blocks/'.length);
    if (path.startsWith('/pins/')) return path.substring('/pins/'.length);
    if (path.startsWith('/dht/')) return path.substring('/dht/'.length);
    return path;
  }

  /// Returns the prefix string for a given box.
  String _getPrefixForBox(Box<List<int>> box) {
    if (box == _blocksBox) return '/blocks/';
    if (box == _pinsBox) return '/pins/';
    if (box == _dhtBox) return '/dht/';
    return '';
  }

  @override
  Future<void> put(Key key, Uint8List value) async {
    _ensureInitialized();
    final box = _getBox(key);
    final innerKey = _getInnerKey(key);
    await box.put(innerKey, value.toList());
  }

  @override
  Future<Uint8List?> get(Key key) async {
    _ensureInitialized();
    final box = _getBox(key);
    final innerKey = _getInnerKey(key);
    final value = box.get(innerKey);
    return value != null ? Uint8List.fromList(value) : null;
  }

  @override
  Future<bool> has(Key key) async {
    _ensureInitialized();
    final box = _getBox(key);
    final innerKey = _getInnerKey(key);
    return box.containsKey(innerKey);
  }

  @override
  Future<void> delete(Key key) async {
    _ensureInitialized();
    final box = _getBox(key);
    final innerKey = _getInnerKey(key);
    await box.delete(innerKey);
  }

  @override
  Stream<QueryEntry> query(Query q) async* {
    _ensureInitialized();

    // Determine which boxes to query based on prefix
    final boxesToQuery = _selectBoxes(q.prefix);

    for (final box in boxesToQuery) {
      final boxPrefix = _getPrefixForBox(box);

      for (final innerKey in box.keys) {
        final fullKey = '$boxPrefix$innerKey';

        // Apply prefix filter
        if (q.prefix != null && !fullKey.startsWith(q.prefix!)) {
          continue;
        }

        final key = Key(fullKey);
        Uint8List? value;

        // Load value unless keys-only query
        if (!q.keysOnly) {
          final rawValue = box.get(innerKey);
          if (rawValue != null) {
            value = Uint8List.fromList(rawValue);
          }
        }

        // Apply custom filters if provided
        if (q.filters != null && value != null) {
          bool passesFilters = true;
          for (final filter in q.filters!) {
            if (!filter.filter(MapEntry(key, value))) {
              passesFilters = false;
              break;
            }
          }
          if (!passesFilters) continue;
        }

        yield QueryEntry(key, value);
      }
    }
  }

  /// Selects which boxes to query based on the query prefix.
  List<Box<List<int>>> _selectBoxes(String? prefix) {
    if (prefix == null || prefix == '/' || prefix.isEmpty) {
      return [_blocksBox, _pinsBox, _dhtBox, _defaultBox];
    }
    if (prefix.startsWith('/blocks')) return [_blocksBox];
    if (prefix.startsWith('/pins')) return [_pinsBox];
    if (prefix.startsWith('/dht')) return [_dhtBox];
    return [_defaultBox];
  }

  @override
  Future<void> close() async {
    if (!_initialized) return;

    await _blocksBox.close();
    await _pinsBox.close();
    await _dhtBox.close();
    await _defaultBox.close();
    _initialized = false;
    _logger.info('HiveDatastore closed');
  }

  /// Ensures the datastore is initialized before operations.
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('HiveDatastore not initialized. Call init() first.');
    }
  }
}

