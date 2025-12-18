import 'dart:typed_data';

import 'platform_stub.dart';

/// Web implementation of the IPFS platform interface.
///
/// Uses in-memory storage since the browser does not have
/// direct filesystem access.
class IpfsPlatformWeb implements IpfsPlatform {
  // Simple in-memory FS for Web initially
  final Map<String, Uint8List> _files = {};
  final Set<String> _directories = {};

  @override
  bool get isWeb => true;

  @override
  bool get isIO => false;

  @override
  String get pathSeparator => '/';

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    _files[path] = bytes;
    // Auto-create "directories" implicitly
    int lastSlash = path.lastIndexOf('/');
    if (lastSlash != -1) {
      _directories.add(path.substring(0, lastSlash));
    }
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    return _files[path];
  }

  @override
  Future<bool> exists(String path) async {
    return _files.containsKey(path) || _directories.contains(path);
  }

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
    _directories.remove(path);
  }

  @override
  Future<void> createDirectory(String path) async {
    _directories.add(path);
  }

  @override
  Future<List<String>> listDirectory(String path) async {
    // Naive implementation
    final entries = <String>[];
    for (final k in _files.keys) {
      if (k.startsWith(path)) entries.add(k);
    }
    return entries;
  }
}

/// Returns the Web platform implementation.
IpfsPlatform getPlatform() => IpfsPlatformWeb();
