@TestOn('vm')
import 'dart:io';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E pinning', () {
    late Directory repo;
    IPFSNode? node;

    setUp(() async {
      repo = await makeRepoDir('pinning');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('pin then pinnedCids lists the CID', () async {
      final cid = await node!.addFile(utf8Bytes('pin me'));

      await node!.pin(cid);
      expect(await node!.pinnedCids, contains(cid));
    });

    test('unpin removes the CID from pinnedCids', () async {
      final cid = await node!.addFile(utf8Bytes('unpin me'));
      await node!.pin(cid);
      expect(await node!.pinnedCids, contains(cid));

      expect(await node!.unpin(cid), isTrue);
      expect(await node!.pinnedCids, isNot(contains(cid)));
    });

    test('unpin of a never-pinned CID returns false', () async {
      final cid = await node!.addFile(utf8Bytes('not pinned'));
      expect(await node!.unpin(cid), isFalse);
    });

    test('multiple pins accumulate additively', () async {
      final cid1 = await node!.addFile(utf8Bytes('one'));
      final cid2 = await node!.addFile(utf8Bytes('two'));
      final cid3 = await node!.addFile(utf8Bytes('three'));

      await node!.pin(cid1);
      await node!.pin(cid2);
      await node!.pin(cid3);

      final pins = await node!.pinnedCids;
      expect(pins, containsAll(<String>[cid1, cid2, cid3]));
    });

    test('a directory pin persists the root CID', () async {
      final rootCid = await node!.addDirectory({
        'a.txt': utf8Bytes('a'),
        'b.txt': utf8Bytes('b'),
      });

      await node!.pin(rootCid);
      expect(await node!.pinnedCids, contains(rootCid));
    });

    test('pins survive a node restart on the same repo', () async {
      final cid = await node!.addFile(utf8Bytes('durable pin'));
      await node!.pin(cid);
      await node!.stop();
      node = null;

      final node2 = await IPFSNode.create(offlineConfig(repo.path));
      try {
        await node2.start();
        expect(await node2.pinnedCids, contains(cid));
        expect(await node2.cat(cid), equals(utf8Bytes('durable pin')));
      } finally {
        await stopQuietly(node2);
      }
    });

    test('pins survive a stop/start cycle on the same node', () async {
      final cid = await node!.addFile(utf8Bytes('cycle pin'));
      await node!.pin(cid);

      await node!.stop();
      await node!.start();

      expect(await node!.pinnedCids, contains(cid));
    });
  });
}
