import 'dart:convert';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/storage/hive_datastore.dart';
import 'package:dart_ipfs/src/platform/platform.dart';

void main() {
  group('MFSManager', () {
    late MFSManager mfs;
    late BlockStore blockStore;
    late HiveDatastore datastore;
    late String tempDir;

    setUp(() async {
      tempDir = await getPlatform().createTempDirectory('mfs_test_');
      blockStore = BlockStore(path: tempDir);
      datastore = HiveDatastore('$tempDir/datastore');

      await blockStore.start();
      await datastore.init();

      mfs = MFSManager(blockStore, datastore);
      await mfs.init();
    });

    tearDown(() async {
      await blockStore.stop();
      await datastore.close();
      await getPlatform().delete(tempDir);
    });

    test('mkdir creates directory', () async {
      await mfs.mkdir('/test');
      final contents = await mfs.ls('/');
      expect(contents.any((l) => l.name == 'test'), isTrue);
    });

    test('mkdir recursive', () async {
      await mfs.mkdir('/a/b/c', recursive: true);
      final aContents = await mfs.ls('/a');
      expect(aContents.any((l) => l.name == 'b'), isTrue);

      final bContents = await mfs.ls('/a/b');
      expect(bContents.any((l) => l.name == 'c'), isTrue);
    });

    test('write and read file', () async {
      const text = 'Hello MFS!';
      final data = Stream.value(utf8.encode(text));

      await mfs.write('/hello.txt', data);

      final readStream = await mfs.read('/hello.txt');
      final readData = await readStream.expand((b) => b).toList();
      expect(utf8.decode(readData), equals(text));
    });

    test('stat returns correct info', () async {
      await mfs.mkdir('/docs');
      final info = await mfs.stat('/docs');

      expect(info['type'], contains('Directory'));
      expect(info['cid'], isNotNull);
    });

    test('rm removes file/directory', () async {
      await mfs.mkdir('/to_remove');
      await mfs.rm('/to_remove', recursive: true);

      final contents = await mfs.ls('/');
      expect(contents.any((l) => l.name == 'to_remove'), isFalse);
    });

    test('cp copies content', () async {
      await mfs.write('/original.txt', Stream.value(utf8.encode('data')));
      await mfs.cp('/original.txt', '/copy.txt');

      final contents = await mfs.ls('/');
      expect(contents.any((l) => l.name == 'copy.txt'), isTrue);

      final readStream = await mfs.read('/copy.txt');
      final readData = await readStream.expand((b) => b).toList();
      expect(utf8.decode(readData), equals('data'));
    });
  });
}
