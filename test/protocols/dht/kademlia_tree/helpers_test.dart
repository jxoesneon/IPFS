
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia_node.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_kademlia.pb.dart' as common_pb;
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';

@GenerateMocks([DHTClient])
import 'helpers_test.mocks.dart';

void main() {
  group('DHT Helpers', () {
    test('calculateDistance returns correct XOR distance', () {
      final p1 = PeerId(value: Uint8List.fromList([0, 0, 1]));
      final p2 = PeerId(value: Uint8List.fromList([0, 0, 2]));
      // [1] ^ [2] = 3
      expect(calculateDistance(p1, p2), 3);
      
      final p3 = PeerId(value: Uint8List.fromList([1, 0, 0]));
      final p4 = PeerId(value: Uint8List.fromList([2, 0, 0]));
      // [1]^ [2] = 3. shifted by 16 bits = 3 * 256^2 = 196608
      expect(calculateDistance(p3, p4), 196608);
    });

    test('getBucketIndex returns correct index', () {
      expect(getBucketIndex(0), 0);
      expect(getBucketIndex(1), 255); // bitLength 1 -> 255 - (1-1) = 255
      expect(getBucketIndex(2), 254); // bitLength 2 -> 255 - (2-1) = 254
      expect(getBucketIndex(4), 253); // bitLength 3 -> 255 - (3-1) = 253
    });

    test('findClosestNode finds the best node in subtree', () {
      final target = PeerId(value: Uint8List.fromList([0, 0, 10]));
      
      final root = KademliaNode()
        ..peerId = (common_pb.KademliaId()..id = [0, 0, 1]);
      
      final child1 = KademliaNode()
        ..peerId = (common_pb.KademliaId()..id = [0, 0, 5]);
      
      final child2 = KademliaNode()
        ..peerId = (common_pb.KademliaId()..id = [0, 0, 9]);
      
      root.children.addAll([child1, child2]);
      
      final result = findClosestNode(root, target);
      expect(result?.peerId.id, [0, 0, 9]);
    });

    test('splitNode creates children correctly', () {
      final node = KademliaNode()
        ..peerId = (common_pb.KademliaId()..id = [0, 0, 1])
        ..associatedPeerId = (common_pb.KademliaId()..id = [0, 0, 2]);
      
      splitNode(node);
      
      expect(node.children.length, 2);
      expect(node.children[0].peerId.id, [0, 0, 1]);
      expect(node.children[1].peerId.id, [0, 0, 2]);
    });

    test('mergeNodes clears children', () {
      final node = KademliaNode();
      node.children.addAll([KademliaNode(), KademliaNode()]);
      
      mergeNodes(node);
      expect(node.children.isEmpty, true);
    });

    test('findNode returns closer peers on success', () async {
      final mockClient = MockDHTClient();
      final peer = PeerId(value: Uint8List.fromList([0, 0, 1]));
      final target = PeerId(value: Uint8List.fromList([0, 0, 10]));
      
      final foundPeer = PeerId(value: Uint8List.fromList([0, 0, 9]));
      when(mockClient.findPeer(peer)).thenAnswer((_) async => foundPeer);
      
      final result = await findNode(mockClient, peer, target);
      expect(result.length, 1);
      expect(result[0].value, [0, 0, 9]);
    });

    test('findNode returns empty list on failure', () async {
      final mockClient = MockDHTClient();
      final peer = PeerId(value: Uint8List.fromList([0, 0, 1]));
      final target = PeerId(value: Uint8List.fromList([0, 0, 10]));
      
      when(mockClient.findPeer(peer)).thenThrow(Exception('test error'));
      
      final result = await findNode(mockClient, peer, target);
      expect(result, isEmpty);
    });
  });
}
