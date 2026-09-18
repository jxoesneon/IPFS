@TestOn('vm')
// This file deliberately imports ONLY the umbrella library — it guards the
// export wiring: every consumer-facing type must be reachable and
// functional through `package:dart_ipfs/dart_ipfs.dart` alone.
import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E umbrella public API', () {
    test('IPFS facade completes a content journey end to end', () async {
      final repo = await makeRepoDir('facade');
      final ipfs = await IPFS.create(
        config: IPFSConfig(
          offline: true,
          dataPath: '${repo.path}/repo',
          datastorePath: '${repo.path}/repo/datastore',
          keystorePath: '${repo.path}/repo/keystore',
          blockStorePath: '${repo.path}/repo/blocks',
        ),
      );
      try {
        await ipfs.start();
        final cid = await ipfs.addFile(utf8Bytes('facade journey'));
        expect(await ipfs.cat(cid), equals(utf8Bytes('facade journey')));
        expect(await ipfs.ls(cid), isEmpty);
        await ipfs.pin(cid);
        expect(await ipfs.pinnedCids, contains(cid));
        expect(ipfs.peerID, isNotEmpty);
        expect(ipfs.messagesFor('t'), isA<Stream<PubSubMessage>>());
        expect(ipfs.pubsubLs(), isEmpty);
      } finally {
        await ipfs.stop();
        await deleteRepo(repo);
      }
    });

    test('CID decode/encode round-trips through the export', () async {
      final cid = (await Block.fromData(utf8Bytes('cid journey'))).cid;
      final encoded = cid.encode();
      final decoded = CID.decode(encoded);
      expect(decoded.encode(), equals(encoded));
      expect(CID.fromBytes(cid.toBytes()).encode(), equals(encoded));
    });

    test('Block.fromData produces a resolvable CID', () async {
      final data = utf8Bytes('block journey');
      final block = await Block.fromData(data);
      expect(block.cid.encode(), isNotEmpty);
      expect(block.data, equals(data));
    });

    test('IPLD codecs round-trip through the export', () async {
      final raw = RawCodec();
      final data = utf8Bytes('raw');
      expect(await raw.decode(await raw.encode(data)), equals(data));

      final cbor = DagCborCodec();
      final cborDecoded = await cbor.decode(
        await cbor.encode(<String, dynamic>{'k': 'v', 'n': 1}),
      );
      expect((cborDecoded as Map)['k'], equals('v'));

      final json = DagJsonCodec();
      final jsonDecoded = await json.decode(
        await json.encode(<String, dynamic>{'k': 'v'}),
      );
      expect((jsonDecoded as Map)['k'], equals('v'));
    });

    test('Ed25519Signer signs and verifies through the export', () async {
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKey = await signer.extractPublicKey(keyPair);
      final data = utf8Bytes('signed journey');

      final signature = await signer.sign(data, keyPair);
      expect(signature, hasLength(64));
      expect(await signer.verify(data, signature, publicKey), isTrue);
      expect(
        await signer.verify(utf8Bytes('other'), signature, publicKey),
        isFalse,
      );
    });

    test('InMemoryBlockStore stores and serves blocks', () async {
      final store = InMemoryBlockStore();
      final block = await Block.fromData(utf8Bytes('stored'));

      expect(await store.hasBlock(block.cid), isFalse);
      final put = await store.putBlock(block);
      expect(put.succeeded, isTrue);
      expect(await store.hasBlock(block.cid), isTrue);

      final got = await store.getBlock(block.cid);
      expect(got.succeeded, isTrue);
      expect(got.value?.data, equals(block.data));
    });

    test('PeerKeyRegistry verifies real libp2p bindings', () async {
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final pubBytes = await signer.extractPublicKeyBytes(keyPair);

      // A peer ID derived from this key must verify; a foreign ID must not.
      final registry = PeerKeyRegistry();
      final bogusId = 'QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N';
      expect(registry.registerPublicKey(bogusId, pubBytes), isFalse);
      expect(registry.hasPublicKey(bogusId), isFalse);
    });

    test('CarWriter to CarReader round-trips sections', () async {
      final block1 = await Block.fromData(utf8Bytes('car block 1'));
      final block2 = await Block.fromData(utf8Bytes('car block 2'));

      final writer = CarWriter(roots: <CID>[block1.cid]);
      await writer.write(block1.cid, block1.data);
      await writer.write(block2.cid, block2.data);
      final carBytes = await writer.close();
      expect(carBytes, isNotEmpty);

      final reader = CarReader.fromBytes(carBytes);
      final header = await reader.header;
      expect(header.version, equals(1));
      expect(header.roots.single.encode(), equals(block1.cid.encode()));

      final sections = <CarSection>[];
      await for (final section in reader.sections()) {
        sections.add(section);
      }
      expect(sections, hasLength(2));
      expect(
        sections.map((s) => s.cid.encode()),
        containsAll(<String>[block1.cid.encode(), block2.cid.encode()]),
      );
    });

    test('CarWriter v2 with index produces a readable archive', () async {
      final block = await Block.fromData(utf8Bytes('car v2 block'));
      final writer = CarWriter(roots: <CID>[block.cid], v2: true, index: true);
      await writer.write(block.cid, block.data);
      final carBytes = await writer.close();

      final reader = CarReader.fromBytes(carBytes);
      final header = await reader.header;
      expect(header.roots.single.encode(), equals(block.cid.encode()));
      expect(await reader.findCID(block.cid), isNotNull);
    });

    test('PubSubMessage is constructible through the export', () {
      final message = PubSubMessage(topic: 't', content: 'c', sender: 'peer');
      expect(message.topic, equals('t'));
      expect(message.content, equals('c'));
      expect(message.sender, equals('peer'));
    });

    test('lifecycle types are reachable through the export', () {
      final adapter = ManualMobileLifecycleAdapter();
      final coordinator = MobileLifecycleCoordinator(adapter: adapter);
      expect(coordinator.currentPowerMode, isA<IpfsPowerMode>());
      expect(coordinator.isRunning, isFalse);
    });
  });
}
