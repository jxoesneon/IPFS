@TestOn('vm')
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
      );

      expect(await readAll('/hello.txt'), equals(utf8.encode('hello mfs')));
    });

    test('mkdir creates directories listable via ls', () async {
      await node!.mfs.mkdir('/docs', parents: true);
      await node!.mfs.write('/docs/a.txt', Stream.value(utf8.encode('aaa')));

      final entries = await node!.mfs.ls('/docs');
      expect(entries.map((e) => e.name), contains('a.txt'));
    });

    test('nested mkdir with parents creates the full path', () async {
      await node!.mfs.mkdir('/a/b/c', parents: true);
      await node!.mfs.write('/a/b/c/deep.txt', Stream.value(utf8.encode('d')));

      expect(await readAll('/a/b/c/deep.txt'), equals(utf8.encode('d')));
    });

    test('stat reports file metadata', () async {
      await node!.mfs.write('/s.txt', Stream.value(utf8.encode('stat me')));

      final stat = await node!.mfs.stat('/s.txt');
      expect(stat.size, greaterThan(0));
      expect(stat.hash, isNotEmpty);
      expect(stat.type, equals('file'));
    });

    test('cp duplicates a file', () async {
      await node!.mfs.write('/orig.txt', Stream.value(utf8.encode('copy me')));
      await node!.mfs.cp('/orig.txt', '/copy.txt');

      expect(await readAll('/copy.txt'), equals(utf8.encode('copy me')));
    });

    test('mv relocates a file', () async {
      await node!.mfs.write('/from.txt', Stream.value(utf8.encode('moved')));
      await node!.mfs.mv('/from.txt', '/to.txt');

      expect(await readAll('/to.txt'), equals(utf8.encode('moved')));
      await expectLater(readAll('/from.txt'), throwsA(anything));
    });

    test('rm removes a file', () async {
      await node!.mfs.write('/tmp.txt', Stream.value(utf8.encode('x')));
      await node!.mfs.rm('/tmp.txt');

      await expectLater(readAll('/tmp.txt'), throwsA(anything));
    });

    test('flush returns the root CID', () async {
      await node!.mfs.write('/f.txt', Stream.value(utf8.encode('f')));
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

    test('reading a missing path throws', () async {
      await expectLater(readAll('/nope.txt'), throwsA(anything));
    });
  });
}
