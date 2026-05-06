import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/bucket_management.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'dart:typed_data';
import 'dart:math' as math;

@GenerateMocks([DHTClient, RouterInterface])
import 'bucket_management_test.mocks.dart';

class TestKademliaTree extends KademliaTree {
  TestKademliaTree(super.dhtClient);

  bool? mockPingResult;

  @override
  Future<bool> sendPing(PeerId peer) async {
    if (mockPingResult != null) return mockPingResult!;
    return true;
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

  group('BucketManagement', () {
    test('getBucketIndex returns expected values', () {
      expect(tree.getBucketIndex(1), equals(0));
      expect(tree.getBucketIndex(2), equals(1));
      expect(tree.getBucketIndex(4), equals(3));
    });

    test('splitBucket increases bucket count if bucket not empty', () {
      final initialBuckets = tree.buckets.length;
      final peer = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final node = KademliaTreeNode(peer, 1, localPeerId, lastSeen: 1000);
      tree.buckets[0].insert(peer, node);

      tree.splitBucket(0);
      expect(tree.buckets.length, equals(initialBuckets + 1));
    });

    test('mergeBuckets decreases bucket count', () {
      final initialBuckets = tree.buckets.length;
      // First split to have something to merge
      final peer = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final node = KademliaTreeNode(peer, 1, localPeerId, lastSeen: 1000);
      tree.buckets[0].insert(peer, node);
      tree.splitBucket(0);
      expect(tree.buckets.length, equals(initialBuckets + 1));

      tree.mergeBuckets(0, 1);
      expect(tree.buckets.length, equals(initialBuckets));
    });

    test('findLeastRecentlySeenNode returns oldest node', () {
      final peer1 = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final node1 = KademliaTreeNode(peer1, 1, localPeerId, lastSeen: 1000);
      final peer2 = PeerId(value: Uint8List.fromList(List.filled(32, 2)));
      final node2 = KademliaTreeNode(peer2, 1, localPeerId, lastSeen: 2000);

      tree.buckets[255].insert(peer1, node1);
      tree.buckets[255].insert(peer2, node2);
      tree.lastSeen[peer1] = DateTime.fromMillisecondsSinceEpoch(1000);
      tree.lastSeen[peer2] = DateTime.fromMillisecondsSinceEpoch(2000);

      final found = tree.findLeastRecentlySeenNode(255);
      expect(found?.peerId, equals(peer1));
    });

    test('calculateConnectionStabilityScore with different states', () {
      final node = KademliaTreeNode(
        localPeerId,
        0,
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      node.state = KademliaNodeState.active;
      final scoreActive = tree.calculateConnectionStabilityScore(node);

      node.state = KademliaNodeState.stale;
      final scoreStale = tree.calculateConnectionStabilityScore(node);

      node.state = KademliaNodeState.failed;
      final scoreFailed = tree.calculateConnectionStabilityScore(node);

      expect(scoreActive, greaterThan(scoreStale));
      expect(scoreStale, greaterThan(scoreFailed));
    });

    test('calculateConnectionStabilityScore with failed requests', () {
      final node = KademliaTreeNode(
        localPeerId,
        0,
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      final score0 = tree.calculateConnectionStabilityScore(node);

      node.incrementFailedRequests();
      final score1 = tree.calculateConnectionStabilityScore(node);

      expect(score0, greaterThan(score1));
    });

    test('calculateConnectionStabilityScore with RTT', () {
      final node = KademliaTreeNode(
        localPeerId,
        0,
        localPeerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
      node.lastRtt = 100;
      final scoreLowRtt = tree.calculateConnectionStabilityScore(node);

      node.lastRtt = 800;
      final scoreHighRtt = tree.calculateConnectionStabilityScore(node);

      expect(scoreLowRtt, greaterThan(scoreHighRtt));
    });

    test('handleBucketFullness - unresponsive node replacement', () async {
      final bucketIndex = 255;
      final oldPeer = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final oldNode = KademliaTreeNode(oldPeer, 1, localPeerId, lastSeen: 1000);
      tree.buckets[bucketIndex].insert(oldPeer, oldNode);
      tree.lastSeen[oldPeer] = DateTime.fromMillisecondsSinceEpoch(1000);

      // Mock ping to fail
      tree.mockPingResult = false;

      final newPeer = PeerId(value: Uint8List.fromList(List.filled(32, 2)));
      await tree.handleBucketFullness(bucketIndex, newPeer, localPeerId);

      expect(tree.buckets[bucketIndex].containsKey(oldPeer), isFalse);
      expect(tree.buckets[bucketIndex].containsKey(newPeer), isTrue);
    });

    test('handleBucketFullness - better candidate replacement', () async {
      final bucketIndex = 255;
      final oldPeer = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      // Old node is stale
      final oldNode = KademliaTreeNode(oldPeer, 1, localPeerId, lastSeen: 1000);
      oldNode.state = KademliaNodeState.stale;
      tree.buckets[bucketIndex].insert(oldPeer, oldNode);
      tree.lastSeen[oldPeer] = DateTime.fromMillisecondsSinceEpoch(1000);

      // Mock ping to succeed
      tree.mockPingResult = true;

      final newPeer = PeerId(value: Uint8List.fromList(List.filled(32, 2)));
      // New peer will have high stability score because it's new and active
      await tree.handleBucketFullness(bucketIndex, newPeer, localPeerId);

      expect(tree.buckets[bucketIndex].containsKey(oldPeer), isFalse);
      expect(tree.buckets[bucketIndex].containsKey(newPeer), isTrue);
    });

    test('handleBucketFullness - recently active peer replacement', () async {
      final bucketIndex = 255;
      final oldPeer = PeerId(value: Uint8List.fromList(List.filled(32, 1)));
      final oldNode = KademliaTreeNode(oldPeer, 1, localPeerId, lastSeen: 1000);
      tree.buckets[bucketIndex].insert(oldPeer, oldNode);
      tree.lastSeen[oldPeer] = DateTime.fromMillisecondsSinceEpoch(1000);

      tree.mockPingResult = true;

      final newPeer = PeerId(value: Uint8List.fromList(List.filled(32, 2)));
      tree.recentContacts.add(newPeer); // Mark as recently active

      await tree.handleBucketFullness(bucketIndex, newPeer, localPeerId);

      expect(tree.buckets[bucketIndex].containsKey(oldPeer), isFalse);
      expect(tree.buckets[bucketIndex].containsKey(newPeer), isTrue);
    });
  });
}
