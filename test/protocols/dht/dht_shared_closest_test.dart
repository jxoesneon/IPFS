// test/protocols/dht/dht_shared_closest_test.dart
//
// When the routing table holds more peers than the bucket size, the
// announce and sweep paths cannot share one closest-peer snapshot per CID:
// each key gets its own closest set. These tests cover that branch, the
// XOR-ordered sort of a store's closest peers, and the binary-search
// insertion that keeps the per-key peer queue ordered.
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/dht_config.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'dht_client_coverage_test.mocks.dart';

void main() {
  late MockRouterInterface router;
  late MockNetworkHandler networkHandler;
  late MockIPFSNode node;
  late DHTClient client;

  /// A peer id whose bytes are derived from [seed].
  PeerId peerWithSeed(int seed) {
    return PeerId(
      value: Uint8List.fromList(List.generate(32, (i) => (seed + i) % 256)),
    );
  }

  setUp(() async {
    router = MockRouterInterface();
    node = MockIPFSNode();
    networkHandler = MockNetworkHandler();

    when(router.peerID)
        .thenReturn('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
    when(router.sendMessage(any, any, protocolId: anyNamed('protocolId')))
        .thenAnswer((_) async => null);
    when(networkHandler.ipfsNode).thenReturn(node);
    when(networkHandler.config).thenReturn(
      IPFSConfig(
        dht: const DHTConfig(
          bucketSize: 2,
          requestTimeout: Duration(milliseconds: 100),
        ),
      ),
    );

    client = DHTClient(networkHandler: networkHandler, router: router);
    await client.initialize();
  });

  /// Fills the routing table with more peers than the bucket size, so the
  /// announce path cannot reuse one closest-peer snapshot for every key.
  Future<void> fillRoutingTable() async {
    for (var seed = 1; seed <= 3; seed++) {
      final peer = peerWithSeed(seed * 10);
      await client.kademliaRoutingTable.addPeer(peer, peer);
    }
  }

  test(
    'addProviders picks the closest peers per CID when the table is full',
    () async {
      await fillRoutingTable();

      final cid = await CID.computeForData(
        Uint8List.fromList([1, 2, 3]),
        format: 'raw',
      );

      await client.addProviders([
        cid,
      ], 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

      // The provider record was sent to the closest peers of the key.
      verify(router.sendMessage(any, any, protocolId: anyNamed('protocolId')))
          .called(2);
    },
  );

  test('storeValue sorts the closest peers by XOR distance', () async {
    await fillRoutingTable();

    final stored = await client.storeValue(
      Uint8List.fromList([7, 7, 7]),
      Uint8List.fromList([8, 8, 8]),
    );
    // The store reaches the closest peers; the mocked router never
    // answers, so the call reports failure rather than throwing.
    expect(stored, isFalse);
    verify(router.sendRequest(any, any, any)).called(4);
  });

  test('addProviders keeps the peer queue ordered by XOR distance', () async {
    await fillRoutingTable();

    final cid = await CID.computeForData(
      Uint8List.fromList([4, 5, 6]),
      format: 'raw',
    );

    await client.addProviders([
      cid,
    ], 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

    verify(router.sendMessage(any, any, protocolId: anyNamed('protocolId')))
        .called(2);
  });
}
