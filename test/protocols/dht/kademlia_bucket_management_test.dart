import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/add_peer.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/helpers.dart' as helpers;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'kademlia_tree_coverage_test.mocks.dart';

void main() {
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

  group('BucketManagement Extension Tests', () {
    test('getBucketIndex returns correct indices for various distances', () {
      // Distance 0 should return 0
      expect(tree.getBucketIndex(0), 0);

      // Distance 1 (bit length 1) -> (1 - 1) = 0
      expect(tree.getBucketIndex(1), 0);

      // Distance 2 (bit length 2) -> (2 - 1) = 1
      expect(tree.getBucketIndex(2), 1);

      // Distance 3 (bit length 3) -> (3 - 1) = 2
      expect(tree.getBucketIndex(3), 2);

      // The test passed 'largeDist' which was 1 << 62.
      // helpers.calculateDistance returns BIT LENGTH, not the XOR value.
      // So if I pass an int to getBucketIndex, it expects a BIT LENGTH.
    });

    test('canSplitBucket logic', () {
      expect(tree.canSplitBucket(0), isTrue);
      expect(tree.canSplitBucket(99), isTrue);
      expect(tree.canSplitBucket(100), isFalse);
      expect(tree.canSplitBucket(255), isFalse);
    });

    test('canMergeBuckets logic', () {
      // Create some nodes in adjacent buckets
      // peer1: dist XOR = 1, bitLength = 1, Index 0
      final peer1 = PeerId(value: Uint8List.fromList(List.filled(31, 0) + [1]));
      // peer2: dist XOR = 2, bitLength = 2, Index 1
      final peer2 = PeerId(value: Uint8List.fromList(List.filled(31, 0) + [2]));

      tree.addPeer(peer1, localPeerId);
      tree.addPeer(peer2, localPeerId);

      expect(tree.canMergeBuckets(0, 1), isTrue);
      expect(tree.canMergeBuckets(0, 2), isFalse);
    });

    test('splitBucket moves nodes correctly', () {
      // Use bucket index 5
      int idx = 5;
      // bitLength = idx + 1 = 6. XOR = 2^5 = 32.
      final peer1 = PeerId(
        value: Uint8List.fromList(List.filled(31, 0) + [32]),
      );
      tree.addPeer(peer1, localPeerId);
      expect(tree.getBucketIndex(6), 5); // bitLength 6 -> bucket 5

      // Add another peer that would fall into the NEW bucket (6) after split
      // bitLength = 7. XOR = 2^6 = 64.
      final peer2 = PeerId(
        value: Uint8List.fromList(List.filled(31, 0) + [64]),
      );
      // We manually add it to bucket 5 for the test of split
      final node2 = KademliaTreeNode(
        peer2,
        7,
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      tree.buckets[5].insert(peer2, node2);

      expect(tree.buckets[5].size, 2);

      tree.splitBucket(5);

      // Should now be 257 buckets
      expect(tree.buckets.length, 257);
      // peer1 (bitLength 6) should stay in bucket 5
      expect(tree.buckets[5].containsKey(peer1), isTrue);
      // peer2 (bitLength 7) should move to bucket 6
      expect(tree.buckets[6].containsKey(peer2), isTrue);
    });

    test('mergeBuckets combines nodes', () {
      final peer1 = PeerId(
        value: Uint8List.fromList(List.filled(31, 0) + [1]),
      ); // bitLength 1 -> Index 0
      final peer2 = PeerId(
        value: Uint8List.fromList(List.filled(31, 0) + [2]),
      ); // bitLength 2 -> Index 1

      tree.addPeer(peer1, localPeerId);
      tree.addPeer(peer2, localPeerId);

      // Verify initial state
      expect(tree.buckets[0].size, 1);
      expect(tree.buckets[1].size, 1);

      tree.mergeBuckets(0, 1);

      expect(tree.buckets[0].size, 2);
      expect(tree.buckets.length, 255);
    });

    test('findLeastRecentlySeenNode', () {
      final peer1 = PeerId(
        value: Uint8List.fromList(List.filled(31, 0) + [1]),
      ); // bitLength 1 -> Index 0
      tree.addPeer(peer1, localPeerId);

      final node = tree.findLeastRecentlySeenNode(0);
      expect(node?.peerId, peer1);

      expect(tree.findLeastRecentlySeenNode(255), isNull);
    });

    test('calculateConnectionStabilityScore with various states', () {
      final peer = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final node = KademliaTreeNode(
        peer,
        1,
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      node.state = KademliaNodeState.active;
      double scoreActive = tree.calculateConnectionStabilityScore(node);

      node.state = KademliaNodeState.stale;
      double scoreStale = tree.calculateConnectionStabilityScore(node);

      node.state = KademliaNodeState.failed;
      double scoreFailed = tree.calculateConnectionStabilityScore(node);

      expect(scoreActive, greaterThan(scoreStale));
      expect(scoreStale, greaterThan(scoreFailed));

      // Test RTT
      node.state = KademliaNodeState.active;
      node.lastRtt = 100;
      double scoreLowRtt = tree.calculateConnectionStabilityScore(node);
      node.lastRtt = 900;
      double scoreHighRtt = tree.calculateConnectionStabilityScore(node);
      expect(scoreLowRtt, greaterThan(scoreHighRtt));

      // Test failed requests
      node.lastRtt = 0;
      node.resetFailedRequests();
      double scoreNoFail = tree.calculateConnectionStabilityScore(node);
      for (int i = 0; i < 5; i++) node.incrementFailedRequests();
      double scoreManyFail = tree.calculateConnectionStabilityScore(node);
      expect(scoreNoFail, greaterThan(scoreManyFail));
    });

    test('handleBucketFullness - split path', () async {
      // Use bucket 50 which can be split
      int idx = 50;
      // bitLength = 51. XOR = 2^50.
      final p1 = PeerId(
        value: Uint8List.fromList(List.filled(31, 0) + [1])
          ..setRange(0, 32, List.filled(32, 0))
          ..setRange(25, 26, [1]),
      ); // This is complex, let's just use a peer that falls into bucket 50

      // Peer with bit length 51 has index 50
      // 51 bits = 6 bytes + 3 bits. 32 bytes total. 32-7 = 25.
      final pInBucket50 = PeerId(
        value: Uint8List.fromList(List.filled(32, 0)..setRange(25, 26, [4])),
      ); // 2^((32-25-1)*8 + 3) = 2^(6*8 + 3) = 2^51. Bit length 51.
      tree.addPeer(pInBucket50, localPeerId);
      expect(
        tree.getBucketIndex(
          helpers.calculateDistance(pInBucket50, localPeerId),
        ),
        50,
      );

      final pExtra = PeerId(value: Uint8List.fromList(List.filled(32, 255)));
      await tree.handleBucketFullness(50, pExtra, localPeerId);

      expect(tree.buckets.length, greaterThan(256));
    });

    test('handleBucketFullness - replacement path', () async {
      // Use bucket 200 (can't split)
      int idx = 200;
      final peer1 = PeerId(value: Uint8List.fromList(List.filled(31, 0) + [1]));
      final node1 = KademliaTreeNode(
        peer1,
        1,
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      tree.buckets[idx].insert(peer1, node1);

      // Mock ping failure
      when(
        mockRouter.sendMessage(any, any),
      ).thenThrow(TimeoutException('fail'));

      final pExtra = PeerId(
        value: Uint8List.fromList(List.filled(31, 0) + [2]),
      );
      await tree.handleBucketFullness(idx, pExtra, localPeerId);

      // node1 should be replaced because ping fails
      expect(tree.buckets[idx].containsKey(peer1), isFalse);
      expect(tree.buckets[idx].containsKey(pExtra), isTrue);
    });
  });
}
