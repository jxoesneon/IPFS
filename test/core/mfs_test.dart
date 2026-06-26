import 'dart:convert';

import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/storage/hive_datastore.dart';
import 'package:test/test.dart';

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
      await mfs.stop();
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

      expect(info.type, equals('directory'));
      expect(info.hash, isNotNull);
      expect(info.size, equals(0));
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

    test('mv moves content', () async {
      await mfs.write('/source.txt', Stream.value(utf8.encode('move me')));
      await mfs.mv('/source.txt', '/dest.txt');

      final rootContents = await mfs.ls('/');
      expect(rootContents.any((l) => l.name == 'source.txt'), isFalse);
      expect(rootContents.any((l) => l.name == 'dest.txt'), isTrue);

      final readStream = await mfs.read('/dest.txt');
      final readData = await readStream.expand((b) => b).toList();
      expect(utf8.decode(readData), equals('move me'));
    });

    test('flush returns root CID', () async {
      await mfs.mkdir('/flushed');
      final rootCid = await mfs.flush(path: '/');
      expect(rootCid, isNotNull);
    });

    test('chcid changes CID version', () async {
      await mfs.mkdir('/chcid_dir');
      final before = await mfs.stat('/chcid_dir');
      await mfs.chcid('/chcid_dir', cidVersion: 1);
      final after = await mfs.stat('/chcid_dir');
      expect(after.hash, isNot(equals(before.hash)));
    });

    group('write offset/truncate', () {
      test('write with offset patches existing file', () async {
        await mfs.write('/patch.txt', Stream.value(utf8.encode('hello world')));
        await mfs.write(
          '/patch.txt',
          Stream.value(utf8.encode('X')),
          offset: 0,
          truncate: false,
        );

        final readStream = await mfs.read('/patch.txt');
        final readData = await readStream.expand((b) => b).toList();
        expect(utf8.decode(readData), equals('Xello world'));
      });

      test('truncate true zeros leading bytes and writes at offset', () async {
        await mfs.write('/trunc.txt', Stream.value(utf8.encode('initial')));
        await mfs.write(
          '/trunc.txt',
          Stream.value(utf8.encode('abc')),
          offset: 4,
          truncate: true,
        );

        final readStream = await mfs.read('/trunc.txt');
        final readData = await readStream.expand((b) => b).toList();
        expect(readData.length, equals(7));
        expect(readData.sublist(0, 4), equals([0, 0, 0, 0]));
        expect(utf8.decode(readData.sublist(4)), equals('abc'));
      });

      test('truncate false requires existing file', () async {
        expect(
          () => mfs.write(
            '/new.txt',
            Stream.value(utf8.encode('data')),
            create: false,
            truncate: false,
          ),
          throwsException,
        );
      });

      test('count limits bytes written', () async {
        await mfs.write(
          '/count.txt',
          Stream.value(utf8.encode('hello world')),
          count: 5,
        );

        final readStream = await mfs.read('/count.txt');
        final readData = await readStream.expand((b) => b).toList();
        expect(utf8.decode(readData), equals('hello'));
      });

      test('negative offset or count throws ArgumentError', () async {
        expect(
          () => mfs.write(
            '/neg.txt',
            Stream.value(utf8.encode('data')),
            offset: -1,
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => mfs.write(
            '/neg.txt',
            Stream.value(utf8.encode('data')),
            count: -1,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    test('stat honors cid-base', () async {
      await mfs.mkdir('/base', cidVersion: 1);
      final stat = await mfs.stat('/base', cidBase: 'base32');
      expect(stat.hash, startsWith('b'));
    });
  });
}
