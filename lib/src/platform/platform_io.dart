import 'dart:io';
import 'dart:typed_data';

import 'platform_stub.dart';

/// IO implementation of the IPFS platform interface.
class IpfsPlatformIO implements IpfsPlatform {
  @override
  bool get isWeb => false;

  @override
  bool get isIO => true;

  @override
  String get pathSeparator => Platform.pathSeparator;

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  @override
  Future<bool> exists(String path) async {
    return await File(path).exists() || await Directory(path).exists();
  }

  @override
  Future<void> delete(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    await Directory(path).create(recursive: true);
  }

  @override
  Future<List<String>> listDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final entities = await dir.list().toList();
    return entities.map((e) => e.path).toList();
  }
}

/// Returns the IO platform implementation.
IpfsPlatform getPlatform() => IpfsPlatformIO();
