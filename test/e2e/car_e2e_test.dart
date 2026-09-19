@TestOn('vm')
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/utils/car_writer.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E CAR import/export', () {
    late Directory repo;
    IPFSNode? node;

    setUp(() async {
      repo = await makeRepoDir('car');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node!.start();
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('exportCAR produces bytes that importCAR restores', () async {
      final data = utf8Bytes('car round-trip');
      final cid = await node!.addFile(data);

      final carBytes = await node!.exportCAR(cid);
      expect(carBytes, isNotEmpty);

      // Import into a fresh node on a separate repo.
      final repo2 = await makeRepoDir('car_import');
      final node2 = await IPFSNode.create(offlineConfig(repo2.path));
      try {
        await node2.start();
        await node2.importCAR(carBytes);
        expect(await node2.cat(cid), equals(data));
      } finally {
        await stopQuietly(node2);
        await deleteRepo(repo2);
      }
    });

    test('a directory DAG exports and re-imports fully', () async {
      final rootCid = await node!.addDirectory({
        'one.txt': utf8Bytes('first'),
        'sub': {'two.txt': utf8Bytes('second')},
      });

      final carBytes = await node!.exportCAR(rootCid);

      final repo2 = await makeRepoDir('car_dag');
      final node2 = await IPFSNode.create(offlineConfig(repo2.path));
      try {
        await node2.start();
        await node2.importCAR(carBytes);

        final links = await node2.ls(rootCid);
        expect(
          links.map((l) => l.name),
          containsAll(<String>['one.txt', 'sub']),
        );
        expect(
          await node2.get(rootCid, path: 'sub/two.txt'),
          equals(utf8Bytes('second')),
        );
      } finally {
        await stopQuietly(node2);
        await deleteRepo(repo2);
      }
    });

    test(
      'importCAR rejects a block whose data does not match its CID',
      () async {
        final block = await Block.fromData(utf8Bytes('real data'));
        final coreCid = block.cid;
        final writer = CarWriter(roots: [coreCid]);
        // Write mismatched bytes under the real CID — the importer must
        // validate the hash and refuse to store it.
        await writer.write(coreCid, Uint8List.fromList([9, 9, 9, 9]));
        final carBytes = await writer.close();

        await expectLater(node!.importCAR(carBytes), throwsA(anything));
      },
    );

    test('exportCAR for a missing root throws', () async {
      final absent = CID.computeForDataSync(utf8Bytes('absent')).encode();
      await expectLater(node!.exportCAR(absent), throwsA(anything));
    });
  });
}
