import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_adapter.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_routing_table.dart';
import 'package:dart_ipfs/src/protocols/dht/xor_distance_metric.dart';

@GenerateMocks([KademliaRoutingTable])
import 'kademlia_routing_adapter_test.mocks.dart';

void main() {
  group('KademliaRoutingAdapter', () {
    late KademliaRoutingAdapter adapter;
    late MockKademliaRoutingTable mockRoutingTable;

    setUp(() {
      mockRoutingTable = MockKademliaRoutingTable();
      adapter = KademliaRoutingAdapter(mockRoutingTable);
    });

    test('exposes XOR distance metric', () {
      expect(adapter.distanceMetric, isA<XorDistanceMetric>());
    });

    group('findClosestPeers', () {
      test('delegates to underlying routing table', () {
        final target = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final expectedPeers = [
          PeerId(value: Uint8List.fromList([5, 6, 7, 8])),
          PeerId(value: Uint8List.fromList([9, 10, 11, 12])),
        ];

        when(mockRoutingTable.findClosestPeers(target, 20))
            .thenReturn(expectedPeers);

        final result = adapter.findClosestPeers(target, k: 20);

        expect(result, equals(expectedPeers));
        verify(mockRoutingTable.findClosestPeers(target, 20)).called(1);
      });

      test('uses default k value', () {
        final target = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        when(mockRoutingTable.findClosestPeers(target, 20))
            .thenReturn([]);

        adapter.findClosestPeers(target);

        verify(mockRoutingTable.findClosestPeers(target, 20)).called(1);
      });
    });

    group('findClosestPeersToKey', () {
      test('converts key to PeerId and delegates', () {
        final key = [1, 2, 3, 4];
        final expectedPeers = [
          PeerId(value: Uint8List.fromList([5, 6, 7, 8])),
        ];

        when(mockRoutingTable.findClosestPeers(any, 20))
            .thenReturn(expectedPeers);

        final result = adapter.findClosestPeersToKey(key, k: 20);

        expect(result, equals(expectedPeers));
        verify(mockRoutingTable.findClosestPeers(any, 20)).called(1);
      });

      test('uses default k value', () {
        final key = [1, 2, 3, 4];
        when(mockRoutingTable.findClosestPeers(any, 20))
            .thenReturn([]);

        adapter.findClosestPeersToKey(key);

        verify(mockRoutingTable.findClosestPeers(any, 20)).called(1);
      });
    });

    group('addPeer', () {
      test('delegates to underlying routing table', () async {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final associatedPeerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final address = '192.168.1.1';

        when(mockRoutingTable.addPeer(peerId, associatedPeerId, address: address))
            .thenAnswer((_) async {});

        await adapter.addPeer(peerId, associatedPeerId, address: address);

        verify(mockRoutingTable.addPeer(peerId, associatedPeerId, address: address))
            .called(1);
      });

      test('handles null address', () async {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));
        final associatedPeerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));

        when(mockRoutingTable.addPeer(peerId, associatedPeerId, address: null))
            .thenAnswer((_) async {});

        await adapter.addPeer(peerId, associatedPeerId);

        verify(mockRoutingTable.addPeer(peerId, associatedPeerId, address: null))
            .called(1);
      });
    });

    group('removePeer', () {
      test('delegates to underlying routing table', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));

        when(mockRoutingTable.removePeer(peerId)).thenReturn(null);

        adapter.removePeer(peerId);

        verify(mockRoutingTable.removePeer(peerId)).called(1);
      });
    });

    group('containsPeer', () {
      test('delegates to underlying routing table', () {
        final peerId = PeerId(value: Uint8List.fromList([1, 2, 3, 4]));

        when(mockRoutingTable.containsPeer(peerId)).thenReturn(true);

        final result = adapter.containsPeer(peerId);

        expect(result, isTrue);
        verify(mockRoutingTable.containsPeer(peerId)).called(1);
      });
    });

    group('peerCount', () {
      test('delegates to underlying routing table', () {
        when(mockRoutingTable.peerCount).thenReturn(42);

        final result = adapter.peerCount;

        expect(result, equals(42));
        verify(mockRoutingTable.peerCount).called(1);
      });
    });

    group('clear', () {
      test('delegates to underlying routing table', () {
        when(mockRoutingTable.clear()).thenReturn(null);

        adapter.clear();

        verify(mockRoutingTable.clear()).called(1);
      });
    });
  });
}
