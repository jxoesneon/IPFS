import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart' as ds;
import 'package:dart_ipfs/src/core/storage/flat_file_datastore.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'dht_client_coverage_test.mocks.dart';

/// Tests that locally published DHT values (including IPNS records) are
/// stored under `/dht/values/` in the persistent datastore and survive a
/// client restart (issue #86).
void main() {
  late MockRouterInterface mockRouter;
  late MockNetworkHandler mockNetworkHandler;
  late MockIPFSNode mockNode;
  late MockDHTHandler mockDhtHandler;
  late ds.Datastore storage;
  late IPFSConfig config;
  late Directory repoDir;

  DHTClient client() =>
      DHTClient(networkHandler: mockNetworkHandler, router: mockRouter);

  setUp(() async {
    repoDir = Directory.systemTemp.createTempSync('ipfs_dht_local_');
    storage = FlatFileDatastore(repoDir.path);
    await storage.init();

    mockRouter = MockRouterInterface();
    mockNetworkHandler = MockNetworkHandler();
    mockNode = MockIPFSNode();
    mockDhtHandler = MockDHTHandler();
    config = IPFSConfig();

    when(mockNetworkHandler.ipfsNode).thenReturn(mockNode);
    when(mockNetworkHandler.config).thenReturn(config);
    when(mockNode.dhtHandler).thenReturn(mockDhtHandler);
    when(mockDhtHandler.router).thenReturn(mockRouter);
    when(mockDhtHandler.storage).thenReturn(storage);
    when(
      mockRouter.peerID,
    ).thenReturn('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
    when(mockRouter.connectedPeers).thenReturn(<String>{});
  });

  tearDown(() async {
    await storage.close();
    if (repoDir.existsSync()) repoDir.deleteSync(recursive: true);
  });

  group('DHTClient local value persistence', () {
    test('storeValue writes the record to local storage', () async {
      final c = client();
      await c.initialize();

      final key = Uint8List.fromList('my-key'.codeUnits);
      final value = Uint8List.fromList('my-value'.codeUnits);
      expect(await c.storeValue(key, value), isTrue);

      final stored = await storage.get(
        ds.Key('/dht/values/${Base58().encode(key)}'),
      );
      expect(stored, isNotNull);
      expect(Uint8List.fromList(stored as List<int>), equals(value));
    });

    test('getValue resolves a locally stored record without peers', () async {
      final c = client();
      await c.initialize();

      final key = Uint8List.fromList('local-key'.codeUnits);
      final value = Uint8List.fromList('local-value'.codeUnits);
      await c.storeValue(key, value);

      expect(await c.getValue(key), equals(value));
    });

    test('records persist across client instances (restart)', () async {
      final first = client();
      await first.initialize();
      final key = Uint8List.fromList('restart-key'.codeUnits);
      final value = Uint8List.fromList('restart-value'.codeUnits);
      await first.storeValue(key, value);

      // Simulate a restart: a fresh client over the same datastore.
      final second = client();
      await second.initialize();
      expect(await second.getValue(key), equals(value));
    });

    test('storeValueRaw also persists locally', () async {
      final c = client();
      await c.initialize();

      final key = Uint8List.fromList('raw-key'.codeUnits);
      final value = Uint8List.fromList('raw-value'.codeUnits);
      expect(await c.storeValueRaw(key, value), isTrue);

      expect(await c.getValueRaw(key), equals(value));
    });

    test('a locally stored IPNS record resolves with no peers', () async {
      final c = client();
      await c.initialize();

      final signer = Ed25519Signer();
      final seed = Uint8List.fromList(List.generate(32, (i) => i));
      final keyPair = await signer.keyPairFromSeed(seed);
      final publicKey = await signer.extractPublicKeyBytes(keyPair);

      final record = await IPNSRecord.create(
        value: CID.decode(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
        keyPair: keyPair,
        sequence: 1,
      );
      final dhtKey = ipnsDhtKey(publicKey);
      final recordBytes = record.toIpnsEntry();

      expect(await c.storeValueRaw(dhtKey, recordBytes), isTrue);
      expect(await c.getValueRaw(dhtKey), equals(recordBytes));
    });
  });
}
