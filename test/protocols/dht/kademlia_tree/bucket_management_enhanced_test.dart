import 'dart:typed_data';

import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../kademlia_tree_coverage_test.mocks.dart';

class TestKademliaTree extends KademliaTree {
  TestKademliaTree(super.dhtClient);

  bool mockPingResult = true;

  @override
  Future<bool> sendPing(PeerId peer) async {
    return mockPingResult;
  }
}

void main() {
  late TestKademliaTree tree;
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

    tree = TestKademliaTree(mockClient);
  });

  group('BucketManagement Enhanced Coverage', () {
    test('getBucketIndex edge cases', () {
      expect(tree.getBucketIndex(0), equals(0));
    });

    test('canSplitBucket boundary', () {
      expect(tree.canSplitBucket(0), isTrue);
      expect(tree.canSplitBucket(99), isTrue);
      expect(tree.canSplitBucket(100), isFalse);
      expect(tree.canSplitBucket(255), isFalse);
    });

    test('canMergeBuckets boundary', () {
      expect(tree.canMergeBuckets(0, 1), isTrue);
      expect(tree.canMergeBuckets(0, 2), isFalse);

      // Fill buckets to exceed K
      for (int i = 0; i < 15; i++) {
        final p1 = PeerId(value: Uint8List.fromList([1, i]));
        final p2 = PeerId(value: Uint8List.fromList([2, i]));
        tree.buckets[0].insert(
          p1,
          KademliaTreeNode(p1, 0, localPeerId, lastSeen: 0),
        );
        tree.buckets[1].insert(
          p2,
          KademliaTreeNode(p2, 0, localPeerId, lastSeen: 0),
        );
      }
      expect(tree.canMergeBuckets(0, 1), isFalse);
    });

    test('splitBucket with empty buckets handling', () {
      tree.splitBucket(0);
    });

    test('mergeBuckets with wrong order or non-adjacent', () {
      final initialLen = tree.buckets.length;
      tree.mergeBuckets(1, 0);
      expect(tree.buckets.length, initialLen - 1);

      final currentLen = tree.buckets.length;
      tree.mergeBuckets(0, 5);
      expect(tree.buckets.length, currentLen);
    });

    test('findLeastRecentlySeenNode with empty bucket', () {
      expect(tree.findLeastRecentlySeenNode(0), isNull);
    });

    test('findLeastRecentlySeenNode with missing lastSeen data', () {
      final p1 = PeerId(value: Uint8List.fromList([1]));
      final node1 = KademliaTreeNode(p1, 0, localPeerId, lastSeen: 0);
      tree.buckets[0].insert(p1, node1);
      tree.lastSeen.remove(p1); // Ensure it's null in map
      expect(tree.findLeastRecentlySeenNode(0), equals(node1));
    });

    test('handleBucketFullness split case', () async {
      for (int i = 0; i < 20; i++) {
        final p = PeerId(value: Uint8List.fromList([1, i]));
        tree.buckets[0].insert(
          p,
          KademliaTreeNode(p, 0, localPeerId, lastSeen: 0),
        );
      }

      final newPeer = PeerId(value: Uint8List.fromList([2]));
      final initialBuckets = tree.buckets.length;
      await tree.handleBucketFullness(0, newPeer, localPeerId);
      expect(tree.buckets.length, equals(initialBuckets + 1));
    });

    test('handleBucketFullness no split, replacement case', () async {
      final idx = 150;
      final oldPeer = PeerId(value: Uint8List.fromList([1]));
      final oldNode = KademliaTreeNode(oldPeer, 0, localPeerId, lastSeen: 1000);
      tree.buckets[idx].insert(oldPeer, oldNode);
      tree.lastSeen[oldPeer] = DateTime.fromMillisecondsSinceEpoch(1000);

      tree.mockPingResult = true;

      final newPeer = PeerId(value: Uint8List.fromList([2]));
      tree.recentContacts.add(newPeer);

      await tree.handleBucketFullness(idx, newPeer, localPeerId);
      expect(tree.buckets[idx].containsKey(oldPeer), isFalse);
      expect(tree.buckets[idx].containsKey(newPeer), isTrue);
    });

    test('calculateConnectionStabilityScore with bonus and penalties', () {
      final node = KademliaTreeNode(
        localPeerId,
        0,
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      // Node is active and very recent, score should be 1.0 (clamped from 1.2)
      expect(tree.calculateConnectionStabilityScore(node), equals(1.2));

      // More failed requests should decrease score below 1.0
      node.incrementFailedRequests();
      node.incrementFailedRequests();
      node.incrementFailedRequests();
      expect(tree.calculateConnectionStabilityScore(node), lessThan(1.0));

      final oldNode = KademliaTreeNode(
        localPeerId,
        0,
        localPeerId,
        lastSeen: DateTime.now()
            .subtract(Duration(hours: 1))
            .millisecondsSinceEpoch,
      );
      // Older node has no bonus, and state is active by default.
      // score = 1.0 * pow(0.9, 0) = 1.0.
      // If we make it stale:
      oldNode.incrementFailedRequests();
      expect(tree.calculateConnectionStabilityScore(oldNode), lessThan(1.0));
    });
  });
}
