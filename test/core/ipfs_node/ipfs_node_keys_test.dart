import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/di/service_container.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:test/test.dart';

import '../../mocks/in_memory_datastore.dart';

void main() {
  group('IPFSNode key management', () {
    late ServiceContainer container;
    late IPFSNode node;
    late Directory tempRepoDir;
    late Directory tempBlockDir;
    final testSalt = Uint8List(16)..fillRange(0, 16, 0);

    setUp(() async {
      tempRepoDir = Directory.systemTemp.createTempSync('ipfs_key_test_repo_');
      tempBlockDir = Directory.systemTemp.createTempSync(
        'ipfs_key_test_blocks_',
      );

      container = ServiceContainer();
      final config = IPFSConfig(offline: true, dataPath: tempRepoDir.path);
      final metrics = MetricsCollector(config);
      container.registerSingleton(metrics);
      container.registerSingleton(SecurityManager(config.security, metrics));

      final blockStore = BlockStore(path: tempBlockDir.path);
      final datastore = InMemoryDatastore();
      await datastore.init();
      container.registerSingleton<BlockStore>(blockStore);
      container.registerSingleton<DatastoreHandler>(
        DatastoreHandler(datastore),
      );
      container.registerSingleton<IPLDHandler>(IPLDHandler(config, blockStore));

      node = IPFSNode.fromContainer(container);
      await node.securityManager.unlockKeystore(
        'test-password',
        salt: testSalt,
      );
    });

    tearDown(() {
      if (tempRepoDir.existsSync()) tempRepoDir.deleteSync(recursive: true);
      if (tempBlockDir.existsSync()) tempBlockDir.deleteSync(recursive: true);
    });

    test('keyGen returns a base36 IPNS name for the stored key', () async {
      final name = await node.keyGen('mykey');

      // The returned name must be the IPNS name derived from the stored
      // key's public key -- i.e., the same key getSecureKey resolves for
      // IPNSHandler.publish(cid, keyName: 'mykey').
      final keyPair = await node.securityManager.getSecureKey('mykey');
      final publicKey = await keyPair.extractPublicKey();
      expect(deriveIpnsName(Uint8List.fromList(publicKey.bytes)), equals(name));
    });

    test('keyGen -> keyList -> keyRm roundtrip', () async {
      await node.keyGen('roundtrip');

      final names = await node.keyList();
      expect(names, contains('roundtrip'));

      await node.keyRm('roundtrip');

      expect(await node.keyList(), isNot(contains('roundtrip')));
      expect(
        () => node.securityManager.getSecureKey('roundtrip'),
        throwsArgumentError,
      );
    });

    test('keyExport -> keyImport roundtrip preserves the IPNS name', () async {
      final originalName = await node.keyGen('original');

      final seed = await node.keyExport('original');
      expect(seed.length, equals(32));

      final importedName = await node.keyImport('copy', seed);
      expect(importedName, equals(originalName));
      expect(await node.keyList(), containsAll(['original', 'copy']));
    });

    test('keyExport throws for a missing key', () async {
      expect(() => node.keyExport('missing'), throwsArgumentError);
    });

    test("keyRm refuses to remove the default 'self' key", () async {
      expect(() => node.keyRm('self'), throwsArgumentError);
    });

    test('keyRm throws for a missing key', () async {
      expect(() => node.keyRm('missing'), throwsArgumentError);
    });

    test('keyGen throws for a duplicate name', () async {
      await node.keyGen('dup');
      expect(() => node.keyGen('dup'), throwsStateError);
    });

    test('keyGen throws for an unsupported key type', () async {
      expect(() => node.keyGen('rsa-key', type: 'rsa'), throwsArgumentError);
    });

    test('keyImport rejects seeds with invalid length', () async {
      expect(() => node.keyImport('bad', Uint8List(16)), throwsArgumentError);
    });

    test('key operations throw when the keystore is locked', () async {
      node.securityManager.lockKeystore();

      expect(() => node.keyGen('nope'), throwsStateError);
      expect(() => node.keyImport('nope', Uint8List(32)), throwsStateError);
      expect(() => node.keyExport('nope'), throwsStateError);
    });
  });
}
