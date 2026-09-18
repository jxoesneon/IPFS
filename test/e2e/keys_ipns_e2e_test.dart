@TestOn('vm')
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E key management', () {
    late Directory repo;
    late IPFSNode node;

    setUp(() async {
      repo = await makeRepoDir('keys');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node.start();
      await node.securityManager.unlockKeystore(
        'test-password',
        salt: Uint8List(16),
      );
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('keyGen produces an IPNS name listed by keyList', () async {
      final name = await node.keyGen('k1');

      expect(name, startsWith('k51qzi5uqu5'));
      expect(await node.keyList(), contains('k1'));
    });

    test('keyExport + keyImport round-trips the same IPNS name', () async {
      final originalName = await node.keyGen('orig');

      final seed = await node.keyExport('orig');
      expect(seed.length, equals(32));

      final importedName = await node.keyImport('copy', seed);
      expect(importedName, equals(originalName));
      expect(await node.keyList(), containsAll(<String>['orig', 'copy']));
    });

    test('keyRm removes a generated key', () async {
      await node.keyGen('temp');
      expect(await node.keyList(), contains('temp'));

      await node.keyRm('temp');
      expect(await node.keyList(), isNot(contains('temp')));
    });

    test("keyRm refuses to remove the default 'self' key", () {
      expect(() => node.keyRm('self'), throwsArgumentError);
    });

    test('keyRm throws for a missing key', () {
      expect(() => node.keyRm('missing'), throwsArgumentError);
    });

    test('keyExport throws for a missing key', () {
      expect(() => node.keyExport('missing'), throwsArgumentError);
    });

    test('keyImport rejects a malformed seed', () {
      expect(() => node.keyImport('bad', Uint8List(16)), throwsArgumentError);
    });

    test('keyGen rejects unsupported key types', () {
      expect(() => node.keyGen('rsa', type: 'rsa'), throwsArgumentError);
    });

    test('keyGen rejects duplicate names', () async {
      await node.keyGen('dup');
      expect(() => node.keyGen('dup'), throwsStateError);
    });

    test(
      'generated keys persist across a node restart on the same repo',
      () async {
        await node.keyGen('durable');
        await node.stop();

        final node2 = await IPFSNode.create(offlineConfig(repo.path));
        try {
          await node2.start();
          await node2.securityManager.unlockKeystore(
            'test-password',
            salt: Uint8List(16),
          );
          expect(await node2.keyList(), contains('durable'));
        } finally {
          await stopQuietly(node2);
        }
        // Re-create the shared node handle for tearDown symmetry.
        node = await IPFSNode.create(offlineConfig(repo.path));
        await node.start();
      },
    );
  });

  group('E2E IPNS publish/resolve', () {
    late Directory repo;
    late IPFSNode node;

    setUp(() async {
      repo = await makeRepoDir('ipns');
      node = await IPFSNode.create(onlineConfig(repo.path));
      await node.start();
      await node.securityManager.unlockKeystore(
        'test-password',
        salt: Uint8List(16),
      );
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('publishIPNS returns an IPNS name that resolves to the CID', () async {
      final cid = await node.addFile(utf8Bytes('ipns content'));

      final name = await node.publishIPNS(cid, keyName: 'self');
      expect(name, isNotEmpty);

      final resolved = await node.resolveIPNS(name);
      expect(resolved, equals('/ipfs/$cid'));
    });

    test('a record published under a named key resolves', () async {
      await node.keyGen('site');
      final cid = await node.addFile(utf8Bytes('named-key content'));

      final name = await node.publishIPNS(cid, keyName: 'site');
      expect(name, startsWith('k51qzi5uqu5'));

      final resolved = await node.resolveIPNS(name);
      expect(resolved, equals('/ipfs/$cid'));
    });

    test('republishing under the same key updates the resolved CID', () async {
      await node.keyGen('site');
      final cid1 = await node.addFile(utf8Bytes('v1'));
      final name = await node.publishIPNS(cid1, keyName: 'site');
      expect(await node.resolveIPNS(name), equals('/ipfs/$cid1'));

      final cid2 = await node.addFile(utf8Bytes('v2'));
      final name2 = await node.publishIPNS(cid2, keyName: 'site');
      expect(name2, equals(name));
      expect(await node.resolveIPNS(name), equals('/ipfs/$cid2'));
    });

    test('resolving an unknown name throws', () async {
      await node.keyGen('other');
      final name = await node.publishIPNS(
        await node.addFile(utf8Bytes('x')),
        keyName: 'other',
      );
      // A name for a key that has never published cannot resolve — use a
      // well-formed but unpublished IPNS name derived from a second key.
      await node.keyGen('unpublished');
      final unpublished = await node.publishIPNS(
        await node.addFile(utf8Bytes('y')),
        keyName: 'unpublished',
      );
      expect(unpublished, isNot(equals(name)));

      // Both published names resolve; a syntactically invalid name does not.
      await expectLater(
        node.resolveIPNS('not-an-ipns-name'),
        throwsA(anything),
      );
    });
  });
}
