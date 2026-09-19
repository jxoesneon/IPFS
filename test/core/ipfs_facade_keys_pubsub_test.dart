import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/pubsub_handler.dart';
import 'package:dart_ipfs/src/ipfs.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

/// Minimal [PubSubHandler] stub used to exercise the facade's pubsub
/// delegates with observable behavior. Only the members used by
/// [IPFS.subscribe], [IPFS.pubsubLs], and [IPFS.pubsubPeers] are implemented;
/// anything else throws via [Fake.noSuchMethod].
class _StubPubSubHandler extends Fake implements PubSubHandler {
  final Set<String> _topics = {};
  final Map<String, Set<String>> peers = {};

  @override
  List<String> get subscribedTopics => _topics.toList();

  @override
  Set<String> peersForTopic(String topic) => peers[topic] ?? const {};

  @override
  Future<void> subscribe(String topic) async {
    _topics.add(topic);
  }
}

/// Minimal [DHTHandler] stub that records announced CIDs. Registered in the
/// node's service container so that `IPFS.provide` takes the `dht != null`
/// branch without requiring real networking.
class _RecordingDHTHandler extends Fake implements DHTHandler {
  final List<String> providedCids = [];

  @override
  Future<void> provide(CID cid) async {
    providedCids.add(cid.toString());
  }
}

IPFSConfig _offlineConfig(String tag) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  return IPFSConfig(
    datastorePath: './test_tmp/ipfs_keys_pubsub_${tag}_$stamp',
    blockStorePath: './test_tmp/ipfs_keys_pubsub_${tag}_blocks_$stamp',
    keystorePath: './test_tmp/ipfs_keys_pubsub_${tag}_keystore_$stamp',
    offline: true,
  );
}

/// Unlocks the keystore of [node]'s `SecurityManager`. Each node owns a
/// scoped `ServiceContainer`, so the manager is reached through the node
/// itself rather than a shared registry.
Future<void> _unlockKeystore(IPFSNode node) {
  return node.securityManager.unlockKeystore(
    'test-password',
    salt: Uint8List(16),
  );
}

void main() {
  group('IPFS facade key management', () {
    late IPFS ipfs;
    late IPFSNode node;

    setUp(() async {
      node = await IPFSNode.create(_offlineConfig('keys'));
      ipfs = IPFS.fromNode(node);
    });

    tearDown(() async {
      await ipfs.stop();
    });

    test('keyGen returns a base36 IPNS name and keyList contains it', () async {
      await _unlockKeystore(node);

      final name = await ipfs.keyGen('k1');

      // CIDv1 libp2p-key, base36-encoded: ed25519 IPNS names always start
      // with the 'k51qzi5uqu5d' prefix.
      expect(name, matches(RegExp('^k[0-9a-z]+\$')));
      expect(name, startsWith('k51qzi5uqu5'));

      expect(await ipfs.keyList(), contains('k1'));
    });

    test('keyExport returns a 32-byte seed and keyImport roundtrips', () async {
      await _unlockKeystore(node);

      final originalName = await ipfs.keyGen('k1');

      final seed = await ipfs.keyExport('k1');
      expect(seed.length, equals(32));

      final importedName = await ipfs.keyImport('k2', seed);
      expect(importedName, equals(originalName));
      expect(await ipfs.keyList(), containsAll(['k1', 'k2']));
    });

    test('keyRm removes the key', () async {
      await _unlockKeystore(node);

      await ipfs.keyGen('k1');
      expect(await ipfs.keyList(), contains('k1'));

      await ipfs.keyRm('k1');
      expect(await ipfs.keyList(), isNot(contains('k1')));
    });

    test("keyRm refuses to remove the default 'self' key", () async {
      expect(() => ipfs.keyRm('self'), throwsArgumentError);
    });

    test('keyRm throws for a missing key', () async {
      await _unlockKeystore(node);
      expect(() => ipfs.keyRm('missing'), throwsArgumentError);
    });

    test('keyExport throws for a missing key', () async {
      await _unlockKeystore(node);
      expect(() => ipfs.keyExport('missing'), throwsArgumentError);
    });

    test('keyImport rejects seeds with invalid length', () async {
      await _unlockKeystore(node);
      expect(() => ipfs.keyImport('bad', Uint8List(16)), throwsArgumentError);
    });

    test('keyGen throws for an unsupported key type', () async {
      expect(() => ipfs.keyGen('rsa-key', type: 'rsa'), throwsArgumentError);
    });

    test('keyGen throws for a duplicate name', () async {
      await _unlockKeystore(node);
      await ipfs.keyGen('dup');
      expect(() => ipfs.keyGen('dup'), throwsStateError);
    });

    test('key operations throw StateError while the keystore is locked', () {
      // The keystore starts locked; unlockKeystore is intentionally not
      // called here.
      expect(() => ipfs.keyGen('nope'), throwsStateError);
      expect(() => ipfs.keyImport('nope', Uint8List(32)), throwsStateError);
      expect(() => ipfs.keyExport('nope'), throwsStateError);
    });
  });

  group('IPFS facade pubsub (offline defaults)', () {
    late IPFS ipfs;

    setUp(() async {
      ipfs = await IPFS.create(config: _offlineConfig('pubsub_off'));
    });

    tearDown(() async {
      await ipfs.stop();
    });

    test('pubsubLs returns an empty list when unsubscribed', () {
      expect(ipfs.pubsubLs(), isA<List<String>>());
      expect(ipfs.pubsubLs(), isEmpty);
    });

    test('pubsubPeers returns an empty list', () async {
      expect(await ipfs.pubsubPeers('t'), isA<List<String>>());
      expect(await ipfs.pubsubPeers('t'), isEmpty);
    });

    test('subscribe completes in offline mode as a no-op', () async {
      // No PubSubHandler is registered in offline mode; ProtocolManager
      // logs a warning and returns, so the subscription is not tracked.
      await ipfs.subscribe('t');
      expect(ipfs.pubsubLs(), isEmpty);
    });
  });

  group('IPFS facade pubsub (stubbed handler)', () {
    late IPFS ipfs;
    late _StubPubSubHandler pubsub;

    setUp(() async {
      // Register the stub in the node's own container before build so that
      // IPFSNode.fromContainer picks it up for the ProtocolManager. Offline
      // mode never registers its own PubSubHandler, so the stub survives the
      // build.
      pubsub = _StubPubSubHandler();
      final builder = IPFSNodeBuilder(_offlineConfig('pubsub_stub'));
      builder.container.registerSingleton<PubSubHandler>(pubsub);
      ipfs = IPFS.fromNode(await builder.build());
    });

    tearDown(() async {
      await ipfs.stop();
    });

    test('pubsubLs contains the topic after subscribe', () async {
      await ipfs.subscribe('t');
      expect(ipfs.pubsubLs(), contains('t'));
    });

    test('pubsubPeers returns the handler peers for the topic', () async {
      pubsub.peers['t'] = {'peer-a', 'peer-b'};
      expect(
        await ipfs.pubsubPeers('t'),
        containsAll(<String>['peer-a', 'peer-b']),
      );
    });
  });

  group('IPFS facade provide with a registered DHTHandler', () {
    late IPFS ipfs;
    late _RecordingDHTHandler dht;

    setUp(() async {
      final builder = IPFSNodeBuilder(_offlineConfig('provide'));
      ipfs = IPFS.fromNode(await builder.build());
      // Registered after build on purpose: the node resolves the handler
      // lazily via its container, and skipping registration at build time
      // avoids wiring the periodic Reprovider.
      dht = _RecordingDHTHandler();
      builder.container.registerSingleton<DHTHandler>(dht);
    });

    tearDown(() async {
      await ipfs.stop();
    });

    test(
      'provide delegates to DHTHandler.provide with the decoded CID',
      () async {
        await ipfs.start();
        final cid = await ipfs.addFile(
          Uint8List.fromList(utf8.encode('Provide via stub')),
        );

        await ipfs.provide(cid);

        expect(dht.providedCids, contains(cid));
      },
    );
  });
}
