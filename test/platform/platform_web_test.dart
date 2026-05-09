@TestOn('browser')
import 'dart:typed_data';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:test/test.dart';

void main() {
  group('IpfsPlatformWeb', () {
    late IpfsPlatform platform;

    setUp(() {
      platform = getPlatform();
    });

    test('isWeb should be true', () {
      expect(platform.isWeb, isTrue);
      expect(platform.isIO, isFalse);
    });

    test('should write and read bytes from IndexedDB', () async {
      final path = 'test_file.bin';
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      await platform.writeBytes(path, data);
      final retrieved = await platform.readBytes(path);

      expect(retrieved, equals(data));
    });

    test('should check for existence', () async {
      final path = 'exists_test.txt';
      final data = Uint8List.fromList('hello'.codeUnits);

      expect(await platform.exists(path), isFalse);

      await platform.writeBytes(path, data);
      expect(await platform.exists(path), isTrue);
    });

    test('should delete files', () async {
      final path = 'delete_test.txt';
      final data = Uint8List.fromList('to be deleted'.codeUnits);

      await platform.writeBytes(path, data);
      expect(await platform.exists(path), isTrue);

      await platform.delete(path);
      expect(await platform.exists(path), isFalse);
    });

    test('should list directory contents via prefix matching', () async {
      await platform.writeBytes('dir/file1.txt', Uint8List(0));
      await platform.writeBytes('dir/subdir/file2.txt', Uint8List(0));
      await platform.writeBytes('other/file3.txt', Uint8List(0));

      final list = await platform.listDirectory('dir');
      expect(list, contains('dir/file1.txt'));
      expect(list, contains('dir/subdir/file2.txt'));
      expect(list, isNot(contains('other/file3.txt')));
    });

    test('should delete directory contents', () async {
      await platform.writeBytes('cleanup/1.txt', Uint8List(0));
      await platform.writeBytes('cleanup/2.txt', Uint8List(0));
      
      expect(await platform.exists('cleanup/1.txt'), isTrue);
      expect(await platform.exists('cleanup/2.txt'), isTrue);

      await platform.delete('cleanup');
      
      expect(await platform.exists('cleanup/1.txt'), isFalse);
      expect(await platform.exists('cleanup/2.txt'), isFalse);
    });

    test('should get file length', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      await platform.writeBytes('length_test.bin', data);
      
      expect(await platform.getLength('length_test.bin'), equals(3));
    });

    test('operatingSystem should be web', () {
      expect(platform.operatingSystem, equals('web'));
    });
  });
}
