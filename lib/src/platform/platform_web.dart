import 'dart:async';
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'platform_stub.dart';

/// Web implementation of the IPFS platform interface using IndexedDB.
class IpfsPlatformWeb implements IpfsPlatform {
  @override
  bool get isWeb => true;

  @override
  bool get isIO => false;

  @override
  String get pathSeparator => '/';

  @override
  String get operatingSystem => 'web';

  @override
  String get version => 'browser';

  static const String _dbName = 'ipfs_storage';
  static const String _storeName = 'files';
  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    _db = await idbFactoryBrowser.open(_dbName, version: 1,
        onUpgradeNeeded: (VersionChangeEvent e) {
      final db = e.database;
      db.createObjectStore(_storeName);
    });
    return _db!;
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final db = await _getDb();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.put(bytes, path);
    await txn.completed;
  }

  @override
  Future<void> writeString(String path, String content) async {
    final bytes = Uint8List.fromList(content.codeUnits);
    await writeBytes(path, bytes);
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final db = await _getDb();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final dynamic data = await store.getObject(path);
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    return null;
  }

  @override
  Future<String?> readString(String path) async {
    final bytes = await readBytes(path);
    if (bytes == null) return null;
    return String.fromCharCodes(bytes);
  }

  @override
  Future<bool> exists(String path) async {
    final db = await _getDb();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final count = await store.count(path);
    if (count > 0) return true;

    // Check if it's a "directory"
    final range = KeyRange.lowerBound(path);
    var found = false;
    final completer = Completer<bool>();
    
    store.openCursor(range: range, direction: idbDirectionNext).listen((cursor) {
      if (cursor.key.toString().startsWith('$path/')) {
        found = true;
      }
      completer.complete(found);
    }, onDone: () {
      if (!completer.isCompleted) completer.complete(false);
    });
    
    return completer.future;
  }

  @override
  Future<void> delete(String path) async {
    final db = await _getDb();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    
    // Delete file
    await store.delete(path);
    
    // Delete "directory" contents
    final range = KeyRange.lowerBound('$path/');
    final completer = Completer<void>();
    
    store.openKeyCursor(range: range).listen((cursor) {
      if (cursor.key.toString().startsWith('$path/')) {
        cursor.delete();
        cursor.next();
      } else {
        completer.complete();
      }
    }, onDone: () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    await txn.completed;
  }

  @override
  Future<void> createDirectory(String path) async {
    // Directories are implicit in our key-value storage
  }

  @override
  Future<String> createTempDirectory([String? prefix]) async {
    final path = '${prefix ?? 'tmp'}_${DateTime.now().millisecondsSinceEpoch}';
    await createDirectory(path);
    return path;
  }

  @override
  Future<List<String>> listDirectory(String path) async {
    final db = await _getDb();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final prefix = path.endsWith('/') ? path : '$path/';
    final results = <String>[];
    final completer = Completer<List<String>>();

    final range = KeyRange.lowerBound(prefix);
    store.openKeyCursor(range: range).listen((cursor) {
      final key = cursor.key.toString();
      if (key.startsWith(prefix)) {
        results.add(key);
        cursor.next();
      } else {
        completer.complete(results);
      }
    }, onDone: () {
      if (!completer.isCompleted) completer.complete(results);
    });

    return completer.future;
  }

  @override
  Future<int> getLength(String path) async {
    final bytes = await readBytes(path);
    return bytes?.length ?? 0;
  }

  @override
  Future<String?> promptPassword(String message) async {
    // In a browser, we could use window.prompt, but it's not secure
    return null;
  }
}

/// Returns the Web platform implementation.
IpfsPlatform getPlatform() => IpfsPlatformWeb();
