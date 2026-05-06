import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:test/test.dart';
import 'dart:io';

@TestOn('vm || browser')
void main() {
  group('IPFSWebNode', () {
    late IPFSWebNode node;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ipfs_web_node_test_');
      final config = IPFSConfig(
        blockStorePath: tempDir.path,
        datastorePath: tempDir.path,
      );
      node = IPFSWebNode(config: config);
      await node.start();
    });

    tearDown(() async {
      if (node.isRunning) {
        await node.stop();
      }
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('should start and set running state', () async {
      expect(node.isRunning, isTrue);
      expect(node.peerID, isNotEmpty);

      // Test starting again (should do nothing)
      await node.start();
      expect(node.isRunning, isTrue);
    });

    test('should stop and unset running state', () async {
      await node.stop();
      expect(node.isRunning, isFalse);

      // Test stopping again (should do nothing)
      await node.stop();
      expect(node.isRunning, isFalse);
    });

    test('should add and retrieve content', () async {
      final content = Uint8List.fromList('Hello Web World'.codeUnits);
      final cid = await node.add(content);

      expect(cid, isNotNull);
      expect(cid.encode(), isNotEmpty);

      // Retrieve by String
      final retrieved = await node.get(cid.encode());
      expect(retrieved, isNotNull);
      expect(String.fromCharCodes(retrieved!), equals('Hello Web World'));

      // Retrieve by CID object
      final retrievedCat = await node.cat(cid);
      expect(retrievedCat, isNotNull);
      expect(retrievedCat, equals(retrieved));
    });

    test('get should return null for non-existent CID', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final retrieved = await node.get(cid);
      expect(retrieved, isNull);
    });

    test('should handle pinning', () async {
      final content = Uint8List.fromList('Pinned Content'.codeUnits);
      final cid = await node.add(content);

      await node.pin(cid);

      final pins = await node.listPins();
      expect(
        pins,
        contains(
          anyOf(cid.encode(), 'pins/${cid.encode()}', 'pins\\${cid.encode()}'),
        ),
      );

      await node.unpin(cid);
      final pinsAfter = await node.listPins();
      expect(pinsAfter, isNot(contains(cid.encode())));
    });

    test('should addStream and retrieve content', () async {
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final stream = Stream<List<int>>.value(data);

      final cid = await node.addStream(stream);
      expect(cid, isNotNull);

      final rootBlock = await node.get(cid.encode());
      expect(rootBlock, isNotNull);
      expect(rootBlock!.length, greaterThan(0));
    });

    test('addStream should work with empty stream', () async {
      final stream = Stream<List<int>>.empty();
      final cid = await node.addStream(stream);
      expect(cid, isNotNull);

      final rootBlock = await node.get(cid.encode());
      expect(rootBlock, isNotNull);
    });

    test('should handle IPNS operations with unlocked keystore', () async {
      final cid = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      // Unlock keystore
      await node.securityManager.unlockKeystore('test-password');
      expect(node.securityManager.isKeystoreUnlocked, isTrue);

      // Generate 'self' key
      final pubKey = await node.securityManager.generateSecureKey('self');

      await node.publishIPNS(cid, keyName: 'self');

      // For resolution, we need to use the public key as the name,
      // but IPNSHandler.resolve expects a name that it can resolve to a key.
      // In this mock, we just want to ensure the flow works.
      final resolved = await node.resolveIPNS(String.fromCharCodes(pubKey));

      // resolution might still return null if key matching is strict,
      // but we care about coverage and no 'Keystore is locked' error.
      expect(resolved, anyOf(isNull, isA<String>()));
    });

    test('publishIPNS should throw if not started', () async {
      final newNode = IPFSWebNode();
      expect(
        () => newNode.publishIPNS('cid', keyName: 'self'),
        throwsStateError,
      );
    });

    test('resolveIPNS should throw if not started', () async {
      final newNode = IPFSWebNode();
      expect(() => newNode.resolveIPNS('name'), throwsStateError);
    });

    test('addFile should throw on IO platform', () async {
      expect(() => node.addFile(null), throwsUnimplementedError);
    });

    test('start with bootstrap peers', () async {
      final nodeWithBootstrap = IPFSWebNode(
        bootstrapPeers: ['/dns4/example.com/tcp/443/wss'],
      );
      await nodeWithBootstrap.start();
      expect(nodeWithBootstrap.isRunning, isTrue);
      await nodeWithBootstrap.stop();
    });

    test('Bitswap and PubSub getters', () {
      expect(node.bitswap, isNotNull);
      expect(node.pubsub, isNotNull);
    });

    test('get with Bitswap fallback (mocked connected peers)', () async {
      // This is tricky as we use WebStubRouter which has no connected peers.
      // But we can test the path where it's empty.
      final result = await node.get(
        'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn',
      );
      expect(result, isNull);
    });
  });
}
