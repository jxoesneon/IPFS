// test/protocols/dht/optimistic_provider_test.dart
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:dart_ipfs/dart_ipfs.dart' hide CID, Block, IBlock, IBlockStore;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/protocols/dht/optimistic_provider.dart';

import 'optimistic_provider_test.mocks.dart';

@GenerateNiceMocks([MockSpec<DHTClient>(), MockSpec<KademliaRoutingTable>()])
void main() {
  late MockDHTClient mockDhtClient;
  late MockKademliaRoutingTable mockRoutingTable;
  late OptimisticProvider provider;
  final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

  setUp(() {
    mockDhtClient = MockDHTClient();
    mockRoutingTable = MockKademliaRoutingTable();

    // Set up default mock behavior
    when(mockDhtClient.kademliaRoutingTable).thenReturn(mockRoutingTable);
    when(mockDhtClient.peerId).thenReturn(
      PeerId.fromBase58('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
    );
    when(
      mockDhtClient.getRoutingKey(any),
    ).thenReturn(PeerId(value: Uint8List.fromList(List.filled(32, 0x42))));
    when(mockRoutingTable.calculateDistance(any, any)).thenReturn(100);
    when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([]);

    provider = OptimisticProvider(
      dhtClient: mockDhtClient,
      config: const OptimisticProvideConfig(
        optimisticBatchSize: 2,
        maxPeersToContact: 10,
      ),
    );
  });

  group('OptimisticProvider', () {
    test('provide returns error when no peers available', () async {
      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([]);

      final result = await provider.provide(cid);

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('No peers available'));
      expect(result.peersContacted, equals(0));
    });

    test('provide succeeds with peers and returns optimistically', () async {
      final peers = List.generate(5, (i) {
        return PeerId(
          value: Uint8List.fromList([i + 1, ...List.filled(31, 0)]),
        );
      });
      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn(peers);
      when(mockDhtClient.sendMessageRaw(any, any)).thenAnswer((_) async {});

      final result = await provider.provide(cid);

      expect(result.optimisticReturn, isTrue);
      expect(result.peersContacted, equals(5));
      // At least the optimistic batch (2) should have completed.
      // In practice, since mocks resolve instantly, all may complete.
      expect(result.putsSucceeded + result.putsFailed, greaterThanOrEqualTo(2));
      expect(result.putsSucceeded, greaterThan(0));
    });

    test('provide handles send failures gracefully', () async {
      final peers = List.generate(3, (i) {
        return PeerId(
          value: Uint8List.fromList([i + 1, ...List.filled(31, 0)]),
        );
      });
      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn(peers);
      when(
        mockDhtClient.sendMessageRaw(any, any),
      ).thenThrow(Exception('Network error'));

      final result = await provider.provide(cid);

      expect(result.optimisticReturn, isTrue);
      expect(result.peersContacted, equals(3));
      // All puts in the batch should have failed
      expect(result.putsSucceeded, equals(0));
    });

    test('provide respects maxPeersToContact limit', () async {
      final peers = List.generate(50, (i) {
        return PeerId(
          value: Uint8List.fromList([i + 1, ...List.filled(31, 0)]),
        );
      });
      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn(peers);
      when(mockDhtClient.sendMessageRaw(any, any)).thenAnswer((_) async {});

      final providerLimited = OptimisticProvider(
        dhtClient: mockDhtClient,
        config: const OptimisticProvideConfig(
          optimisticBatchSize: 2,
          maxPeersToContact: 10,
        ),
      );

      final result = await providerLimited.provide(cid);

      expect(result.peersContacted, equals(10));
    });

    test('provideAll provides multiple CIDs', () async {
      final cid2 = CID.decode('QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG');
      final peers = List.generate(3, (i) {
        return PeerId(
          value: Uint8List.fromList([i + 1, ...List.filled(31, 0)]),
        );
      });
      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn(peers);
      when(mockDhtClient.sendMessageRaw(any, any)).thenAnswer((_) async {});

      final results = await provider.provideAll([cid, cid2]);

      expect(results, hasLength(2));
      for (final result in results) {
        expect(result.optimisticReturn, isTrue);
        expect(result.peersContacted, equals(3));
      }
    });

    test('provide catches unexpected exceptions', () async {
      when(
        mockRoutingTable.findClosestPeers(any, any),
      ).thenThrow(Exception('Routing table corrupted'));

      final result = await provider.provide(cid);

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('waitForBackgroundCompletion completes', () async {
      final peers = List.generate(3, (i) {
        return PeerId(
          value: Uint8List.fromList([i + 1, ...List.filled(31, 0)]),
        );
      });
      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn(peers);
      when(mockDhtClient.sendMessageRaw(any, any)).thenAnswer((_) async {});

      await provider.provide(cid);
      // Should not hang
      await provider.waitForBackgroundCompletion();
      expect(provider.hasPendingBackgroundOps, isFalse);
    });

    test('OptimisticProvideResult toJson', () {
      final result = OptimisticProvideResult(
        duration: const Duration(milliseconds: 500),
        peersContacted: 10,
        putsSucceeded: 8,
        putsFailed: 2,
        optimisticReturn: true,
        backgroundComplete: true,
      );
      final json = result.toJson();
      expect(json['duration_ms'], equals(500));
      expect(json['peers_contacted'], equals(10));
      expect(json['puts_succeeded'], equals(8));
      expect(json['puts_failed'], equals(2));
      expect(json['optimistic_return'], isTrue);
      expect(json['background_complete'], isTrue);
      expect(result.isSuccess, isTrue);
    });

    test('OptimisticProvideResult with error', () {
      final result = OptimisticProvideResult(
        duration: Duration.zero,
        peersContacted: 0,
        putsSucceeded: 0,
        putsFailed: 0,
        optimisticReturn: false,
        error: 'Something went wrong',
      );
      expect(result.isSuccess, isFalse);
      expect(result.toJson()['error'], equals('Something went wrong'));
    });

    test('OptimisticProvideConfig defaults', () {
      const config = OptimisticProvideConfig();
      expect(config.confidenceThreshold, equals(0.90));
      expect(config.maxPeersToContact, equals(40));
      expect(config.optimisticBatchSize, equals(3));
      expect(config.estimatedNetworkSize, equals(10000));
    });

    test('provide with single peer', () async {
      final peer = PeerId(
        value: Uint8List.fromList([1, ...List.filled(31, 0)]),
      );
      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([peer]);
      when(mockDhtClient.sendMessageRaw(any, any)).thenAnswer((_) async {});

      final result = await provider.provide(cid);

      expect(result.peersContacted, equals(1));
      expect(result.optimisticReturn, isTrue);
    });
  });
}
