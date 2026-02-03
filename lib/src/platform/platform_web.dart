import 'dart:async';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'platform_stub.dart';

/// Web implementation of the IPFS platform interface.
///
/// Uses IndexedDB for persistent storage in browsers.
class IpfsPlatformWeb implements IpfsPlatform {
  /// Creates a new web platform instance and initializes IndexedDB.
  IpfsPlatformWeb() {
    _initDatabase();
  }

  static const String _dbName = 'ipfs_storage';
  static const String _filesStore = 'files';
  static const int _dbVersion = 1;

  Database? _db;
  final Completer<void> _dbReady = Completer<void>();

  // Fallback in-memory storage while DB initializes
  final Map<String, Uint8List> _memoryCache = {};
  final Set<String> _directories = {};

  Future<void> _initDatabase() async {
    try {
      final factory = idbFactoryBrowser;
      _db = await factory.open(
        _dbName,
        version: _dbVersion,
        onUpgradeNeeded: (VersionChangeEvent event) {
          final db = event.database;
          if (!db.objectStoreNames.contains(_filesStore)) {
            db.createObjectStore(_filesStore);
          }
        },
      );
      _dbReady.complete();
    } catch (e) {
      // If IndexedDB fails, fall back to memory
      _dbReady.complete();
    }
  }

  Future<void> _ensureReady() async {
    if (!_dbReady.isCompleted) {
      await _dbReady.future;
    }
  }

  @override
  bool get isWeb => true;

  @override
  bool get isIO => false;

  @override
  String get pathSeparator => '/';

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    await _ensureReady();

    // Always update memory cache
    _memoryCache[path] = bytes;

    // Auto-create directories
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash != -1) {
      _directories.add(path.substring(0, lastSlash));
    }

    // Persist to IndexedDB if available
    if (_db != null) {
      try {
        final txn = _db!.transaction(_filesStore, idbModeReadWrite);
        final store = txn.objectStore(_filesStore);
        await store.put(bytes, path);
        await txn.completed;
      } catch (e) {
        // Ignore IndexedDB errors, data is in memory cache
      }
    }
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    await _ensureReady();

    // Check memory cache first
    if (_memoryCache.containsKey(path)) {
      return _memoryCache[path];
    }

    // Try IndexedDB
    if (_db != null) {
      try {
        final txn = _db!.transaction(_filesStore, idbModeReadOnly);
        final store = txn.objectStore(_filesStore);
        final result = await store.getObject(path);
        if (result != null) {
          final bytes = Uint8List.fromList(List<int>.from(result as List));
          _memoryCache[path] = bytes; // Cache for faster access
          return bytes;
        }
      } catch (e) {
        // Ignore IndexedDB errors
      }
    }

    return null;
  }

  @override
  Future<bool> exists(String path) async {
    await _ensureReady();

    if (_memoryCache.containsKey(path) || _directories.contains(path)) {
      return true;
    }

    // Check IndexedDB
    if (_db != null) {
      try {
        final txn = _db!.transaction(_filesStore, idbModeReadOnly);
        final store = txn.objectStore(_filesStore);
        final result = await store.getObject(path);
        return result != null;
      } catch (e) {
        // Ignore IndexedDB errors
      }
    }

    return false;
  }

  @override
  Future<void> delete(String path) async {
    await _ensureReady();

    _memoryCache.remove(path);
    _directories.remove(path);

    if (_db != null) {
      try {
        final txn = _db!.transaction(_filesStore, idbModeReadWrite);
        final store = txn.objectStore(_filesStore);
        await store.delete(path);
        await txn.completed;
      } catch (e) {
        // Ignore IndexedDB errors
      }
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    _directories.add(path);
  }

  @override
  Future<List<String>> listDirectory(String path) async {
    await _ensureReady();

    final entries = <String>{};

    // From memory cache
    for (final k in _memoryCache.keys) {
      if (k.startsWith(path)) {
        entries.add(k);
      }
    }

    // From IndexedDB - would need cursor iteration for full list
    // For now, rely on memory cache which should contain written files

    return entries.toList();
  }
}

/// Returns the Web platform implementation.
IpfsPlatform getPlatform() => IpfsPlatformWeb();

