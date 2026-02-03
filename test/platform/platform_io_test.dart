import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ipfs/src/platform/platform_io.dart';
import 'package:test/test.dart';

void main() {
  group('IpfsPlatformIO', () {
    late IpfsPlatformIO platform;
    late Directory tempDir;

    setUp(() async {
      platform = IpfsPlatformIO();
      tempDir = await Directory.systemTemp.createTemp('ipfs_platform_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('isWeb and isIO', () {
      expect(platform.isWeb, isFalse);
      expect(platform.isIO, isTrue);
    });

    test('pathSeparator', () {
      expect(platform.pathSeparator, equals(Platform.pathSeparator));
    });

    test('writeBytes and readBytes', () async {
      final filePath = '${tempDir.path}/test.bin';
      final data = Uint8List.fromList([1, 2, 3, 4]);

      await platform.writeBytes(filePath, data);
      expect(await File(filePath).exists(), isTrue);

      final read = await platform.readBytes(filePath);
      expect(read, equals(data));
    });

    test('readBytes returns null for non-existent file', () async {
      final read = await platform.readBytes('${tempDir.path}/missing.bin');
      expect(read, isNull);
    });

    test('exists', () async {
      final filePath = '${tempDir.path}/exists.bin';
      await File(filePath).writeAsBytes([0]);
      expect(await platform.exists(filePath), isTrue);

      final subDir = '${tempDir.path}/subdir';
      await Directory(subDir).create();
      expect(await platform.exists(subDir), isTrue);

      expect(await platform.exists('${tempDir.path}/not_here'), isFalse);
    });

    test('delete file and directory', () async {
      final file = File('${tempDir.path}/to_delete.bin');
      await file.writeAsBytes([0]);
      await platform.delete(file.path);
      expect(await file.exists(), isFalse);

      final dir = Directory('${tempDir.path}/dir_to_delete');
      await dir.create();
      await platform.delete(dir.path);
      expect(await dir.exists(), isFalse);
    });

    test('createDirectory', () async {
      final path = '${tempDir.path}/new_dir';
      await platform.createDirectory(path);
      expect(await Directory(path).exists(), isTrue);
    });

    test('listDirectory', () async {
      final subDir = '${tempDir.path}/list_test';
      await Directory(subDir).create();
      await File('$subDir/f1').create();
      await File('$subDir/f2').create();

      final list = await platform.listDirectory(subDir);
      expect(list.length, equals(2));
      expect(list, contains(endsWith('f1')));
      expect(list, contains(endsWith('f2')));
    });

    test('listDirectory returns empty for non-existent', () async {
      final list = await platform.listDirectory('${tempDir.path}/missing_dir');
      expect(list, isEmpty);
    });

    test('getPlatform helper', () {
      final p = getPlatform();
      expect(p, isA<IpfsPlatformIO>());
    });
  });
}

