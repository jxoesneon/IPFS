import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/remove_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/add_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart'
    as helpers;

@GenerateMocks([DHTClient, RouterInterface])
import 'bucket_management_test.mocks.dart';

void main() {
  group('RemovePeer Extension', () {
    late KademliaTree tree;
    late MockDHTClient mockClient;
    late MockRouterInterface mockRouter;
    late PeerId localPeerId;

    setUp(() {
      mockClient = MockDHTClient();
      mockRouter = MockRouterInterface();
      localPeerId = PeerId(value: Uint8List.fromList(List.filled(32, 0)));

      when(mockClient.peerId).thenReturn(localPeerId);
      when(mockClient.router).thenReturn(mockRouter);
      when(mockRouter.peerID).thenReturn(localPeerId.toBase58());

      tree = KademliaTree(mockClient);
    });

    test('removePeer should remove an existing peer', () {
      final peerId = PeerId(
        value: Uint8List.fromList(List.filled(32, 0)..[31] = 1),
      );
      tree.addPeer(peerId, peerId);

      int bucketIndex = helpers.getBucketIndex(
        helpers.calculateDistance(peerId, localPeerId),
      );
      expect(tree.buckets[bucketIndex].search(peerId), isNotNull);

      tree.removePeer(peerId);
      expect(tree.buckets[bucketIndex].search(peerId), isNull);
    });

    test('removePeer should handle non-existent peer', () {
      final peerId = PeerId(
        value: Uint8List.fromList(List.filled(32, 0)..[31] = 2),
      );
      expect(() => tree.removePeer(peerId), returnsNormally);
    });

    test('removePeer should trigger merge when bucket becomes empty', () {
      // Find a peer for bucket 1.
      // distance should be 2^254.
      // [64, 0...] has distance 2^254.
      final peerIdB1 = PeerId(
        value: Uint8List.fromList(List.filled(32, 0)..[0] = 64),
      );
      int indexB1 = helpers.getBucketIndex(
        helpers.calculateDistance(peerIdB1, localPeerId),
      );
      expect(indexB1, equals(254));

      tree.addPeer(peerIdB1, peerIdB1);
      expect(tree.buckets[254].isEmpty, isFalse);

      int initialBucketCount = tree.buckets.length;

      tree.removePeer(peerIdB1);

      // Merging should have happened.
      // mergeBuckets(1, 0) removes bucket 1.
      // mergeBuckets(1, 2) removes bucket 2 (which was originally bucket 3).
      expect(tree.buckets.length, equals(initialBucketCount - 2));
    });

    test('removePeer should NOT trigger merge for bucket 0', () {
      final peerIdB0 = PeerId(
        value: Uint8List.fromList(List.filled(32, 0)..[0] = 128),
      );
      int indexB0 = helpers.getBucketIndex(
        helpers.calculateDistance(peerIdB0, localPeerId),
      );
      expect(indexB0, equals(255));

      tree.addPeer(peerIdB0, peerIdB0);
      int initialBucketCount = tree.buckets.length;

      tree.removePeer(peerIdB0);

      expect(tree.buckets.length, equals(initialBucketCount - 1));
    });

    test('removePeer should trigger merge for bucket 0 (closest peers)', () {
      // Closest bucket is 0. distance 1.
      final peerIdB0 = PeerId(
        value: Uint8List.fromList(List.filled(32, 0)..[31] = 1),
      );
      int indexB0 = helpers.getBucketIndex(
        helpers.calculateDistance(peerIdB0, localPeerId),
      );
      expect(indexB0, equals(0));

      tree.addPeer(peerIdB0, peerIdB0);
      int initialBucketCount = tree.buckets.length;

      tree.removePeer(peerIdB0);

      expect(tree.buckets.length, equals(initialBucketCount - 1));
    });
  });
}
