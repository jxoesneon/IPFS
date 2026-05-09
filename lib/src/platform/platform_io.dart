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
  String get operatingSystem => Platform.operatingSystem;

  @override
  String get version => Platform.version;

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> writeString(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  @override
  Future<String?> readString(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsString();
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
  Future<String> createTempDirectory([String? prefix]) async {
    final dir = await Directory.systemTemp.createTemp(prefix ?? 'ipfs_');
    return dir.path;
  }

  @override
  Future<List<String>> listDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final entities = await dir.list().toList();
    return entities.map((e) => e.path.replaceAll('\\', '/')).toList();
  }

  @override
  Future<int> getLength(String path) async {
    return await File(path).length();
  }

  @override
  Future<String?> promptPassword(String message) async {
    if (!stdin.hasTerminal) return null;
    stdout.write(message);
    final previousEcho = stdin.echoMode;
    stdin.echoMode = false;
    try {
      final input = stdin.readLineSync();
      stdout.writeln();
      return input;
    } finally {
      stdin.echoMode = previousEcho;
    }
  }
}

/// Returns the IO platform implementation.
IpfsPlatform getPlatform() => IpfsPlatformIO();
