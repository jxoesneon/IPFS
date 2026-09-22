@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E Mutable File System', () {
    late Directory repo;
    IPFSNode? node;

    setUp(() async {
      repo = await makeRepoDir('mfs');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    Future<Uint8List> readAll(String path) async {
      final stream = await node!.mfs.read(path);
      final builder = BytesBuilder();
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.toBytes();
    }

    test('write then read round-trips file content', () async {
      await node!.mfs.write(
        '/hello.txt',
        Stream.value(utf8.encode('hello mfs')),
        create: true,
      );

      expect(await readAll('/hello.txt'), equals(utf8.encode('hello mfs')));
    });

    test('mkdir creates directories listable via ls', () async {
      await node!.mfs.mkdir('/docs', parents: true);
      await node!.mfs.write(
        '/docs/a.txt',
        Stream.value(utf8.encode('aaa')),
        create: true,
      );

      final entries = await node!.mfs.ls('/docs');
      expect(entries.map((e) => e.name), contains('a.txt'));
    });

    test('nested mkdir with parents creates the full path', () async {
      await node!.mfs.mkdir('/a/b/c', parents: true);
      await node!.mfs.write(
        '/a/b/c/deep.txt',
        Stream.value(utf8.encode('d')),
        create: true,
      );

      expect(await readAll('/a/b/c/deep.txt'), equals(utf8.encode('d')));
    });

    test('stat reports file metadata', () async {
      await node!.mfs.write(
        '/s.txt',
        Stream.value(utf8.encode('stat me')),
        create: true,
      );

      final stat = await node!.mfs.stat('/s.txt');
      expect(stat.size, greaterThan(0));
      expect(stat.hash, isNotEmpty);
      expect(stat.type, equals('file'));
    });

    test('cp duplicates a file', () async {
      await node!.mfs.write(
        '/orig.txt',
        Stream.value(utf8.encode('copy me')),
        create: true,
      );
      await node!.mfs.cp('/orig.txt', '/copy.txt');

      expect(await readAll('/copy.txt'), equals(utf8.encode('copy me')));
    });

    test('mv relocates a file', () async {
      await node!.mfs.write(
        '/from.txt',
        Stream.value(utf8.encode('moved')),
        create: true,
      );
      await node!.mfs.mv('/from.txt', '/to.txt');

      expect(await readAll('/to.txt'), equals(utf8.encode('moved')));
      await expectLater(readAll('/from.txt'), throwsA(anything));
    });

    test('rm removes a file', () async {
      await node!.mfs.write(
        '/tmp.txt',
        Stream.value(utf8.encode('x')),
        create: true,
      );
      await node!.mfs.rm('/tmp.txt');

      await expectLater(readAll('/tmp.txt'), throwsA(anything));
    });

    test('flush returns the root CID', () async {
      await node!.mfs.write(
        '/f.txt',
        Stream.value(utf8.encode('f')),
        create: true,
      );
      final root = await node!.mfs.flush(path: '/');

      expect(root.encode(), isNotEmpty);
      expect(root.encode(), equals(node!.mfs.rootCid.encode()));
    });

    test(
      'MFS content persists across a node restart on the same repo',
      () async {
        await node!.mfs.mkdir('/keep', parents: true);
        await node!.mfs.write(
          '/keep/file.txt',
          Stream.value(utf8.encode('stays')),
          create: true,
        );
        await node!.mfs.sync();
        await node!.stop();
        node = null;

        final node2 = await IPFSNode.create(offlineConfig(repo.path));
        try {
          await node2.start();
          final stream = await node2.mfs.read('/keep/file.txt');
          final builder = BytesBuilder();
          await for (final chunk in stream) {
            builder.add(chunk);
          }
          expect(builder.toBytes(), equals(utf8.encode('stays')));
        } finally {
          await stopQuietly(node2);
        }
        node = await IPFSNode.create(offlineConfig(repo.path));
        await node!.start();
      },
    );

    test('flush returns the flushed path CID and is deterministic', () async {
      await node!.mfs.mkdir('/fl', parents: true);
      final stat = await node!.mfs.stat('/fl');
      final flushed = await node!.mfs.flush(path: '/fl');
      expect(flushed.encode(), equals(stat.hash));
      final r1 = await node!.mfs.flush();
      final r2 = await node!.mfs.flush();
      expect(r1.encode(), equals(r2.encode()));
    });

    test('touch then stat reports mtime', () async {
      await node!.mfs.write(
        '/meta.txt',
        Stream.value(utf8.encode('m')),
        create: true,
      );
      await node!.mfs.touch('/meta.txt', mtimeSecs: 1700000000);
      final stat = await node!.mfs.stat('/meta.txt');
      expect(stat.mtime, equals(1700000000));
    });

    test('cp from an /ipfs path clones content into MFS', () async {
      await node!.mfs.write(
        '/src.txt',
        Stream.value(utf8.encode('via ipfs')),
        create: true,
      );
      final stat = await node!.mfs.stat('/src.txt');
      await node!.mfs.cp('/ipfs/${stat.hash}', '/dst.txt');
      expect(await readAll('/dst.txt'), equals(utf8.encode('via ipfs')));
    });

    test('write without create fails on a missing path', () async {
      await expectLater(
        node!.mfs.write('/nope.txt', Stream.value(utf8.encode('x'))),
        throwsA(anything),
      );
    });

    test('reading a missing path throws', () async {
      await expectLater(readAll('/nope.txt'), throwsA(anything));
    });
  });
}
