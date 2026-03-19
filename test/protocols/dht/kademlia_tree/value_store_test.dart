import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/value_store.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';

@GenerateMocks([DHTClient, KademliaRoutingTable])
import 'value_store_test.mocks.dart';

void main() {
  late ValueStore valueStore;
  late MockDHTClient mockClient;
  late MockKademliaRoutingTable mockRoutingTable;

  setUp(() {
    mockClient = MockDHTClient();
    mockRoutingTable = MockKademliaRoutingTable();
    when(mockClient.kademliaRoutingTable).thenReturn(mockRoutingTable);
    valueStore = ValueStore(
      mockClient,
      valueExpiry: const Duration(milliseconds: 100),
    );
  });

  group('ValueStore', () {
    test('store replicates and retrieves value', () async {
      final key = 'test';
      final value = Uint8List.fromList([1, 2, 3]);
      final peer = PeerId(value: Uint8List.fromList([1, 1, 1]));

      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([peer]);
      when(
        mockClient.storeValueToPeer(any, any, any),
      ).thenAnswer((_) async => true);

      await valueStore.store(key, value);

      verify(mockClient.storeValueToPeer(peer, any, value)).called(1);

      final retrieved = await valueStore.retrieve(key);
      expect(retrieved, equals(value));
    });

    test('retrieve returns null for expired value', () async {
      final key = 'expired';
      final value = Uint8List.fromList([1]);

      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([]);

      await valueStore.store(key, value);

      // Wait for expiry
      await Future.delayed(const Duration(milliseconds: 150));

      final retrieved = await valueStore.retrieve(key);
      expect(retrieved, isNull);
    });

    test('republishValues handles non-expired and expired items', () async {
      final key1 = 'active';
      final key2 = 'to_expire';

      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([]);
      when(
        mockClient.storeValueToPeer(any, any, any),
      ).thenAnswer((_) async => true);

      await valueStore.store(key1, Uint8List.fromList([1]));

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 60));

      await valueStore.store(key2, Uint8List.fromList([2]));

      // Wait so key1 expires but key2 is still active
      await Future.delayed(const Duration(milliseconds: 60));

      await valueStore.republishValues();

      final keys = await valueStore.getAllKeys();
      expect(keys, contains(key2));
      expect(keys, isNot(contains(key1)));
    });

    test(
      'incrementReplicationCount and updateReplicationCount works',
      () async {
        final key = 'counts';
        when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([]);

        await valueStore.store(key, Uint8List.fromList([1]));

        await valueStore.incrementReplicationCount(key);
        await valueStore.updateReplicationCount(key, 10);

        final keys = await valueStore.getAllKeys();
        expect(keys, contains(key));
      },
    );

    test('replicateValue handles failure', () async {
      final key = 'fail';
      final peer = PeerId(value: Uint8List.fromList([1, 1, 1]));

      when(mockRoutingTable.findClosestPeers(any, any)).thenReturn([peer]);
      when(
        mockClient.storeValueToPeer(any, any, any),
      ).thenThrow(Exception('replicate error'));

      await valueStore.store(key, Uint8List.fromList([1]));
      // Verify it doesn't crash
      expect(await valueStore.retrieve(key), isNotNull);
    });
  });
}
