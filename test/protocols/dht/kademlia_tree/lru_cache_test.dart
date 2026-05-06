import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/lru_cache.dart';
import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';

void main() {
  group('LRUCache', () {
    PeerId createPeerId(int id) {
      return PeerId(value: Uint8List.fromList([id]));
    }

    KademliaTreeNode createNode(PeerId peerId) {
      return KademliaTreeNode(
        peerId,
        0,
        peerId,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
    }

    test('should store and retrieve values', () {
      final cache = LRUCache(10);
      final peerId = createPeerId(1);
      final node = createNode(peerId);

      cache.put(peerId, node);
      expect(cache.get(peerId), equals(node));
    });

    test('should return null for non-existent keys', () {
      final cache = LRUCache(10);
      expect(cache.get(createPeerId(1)), isNull);
    });

    test('should evict least recently used item when capacity is reached', () {
      final cache = LRUCache(2);
      final peerId1 = createPeerId(1);
      final node1 = createNode(peerId1);
      final peerId2 = createPeerId(2);
      final node2 = createNode(peerId2);
      final peerId3 = createPeerId(3);
      final node3 = createNode(peerId3);

      cache.put(peerId1, node1);
      cache.put(peerId2, node2);
      cache.put(peerId3, node3);

      expect(cache.get(peerId1), isNull); // Evicted
      expect(cache.get(peerId2), equals(node2));
      expect(cache.get(peerId3), equals(node3));
    });

    test('should update existing key and move to front', () {
      final cache = LRUCache(2);
      final peerId1 = createPeerId(1);
      final node1 = createNode(peerId1);
      final peerId2 = createPeerId(2);
      final node2 = createNode(peerId2);

      cache.put(peerId1, node1);
      cache.put(peerId2, node2);

      // Update peerId1
      final node1Updated = createNode(peerId1);
      cache.put(peerId1, node1Updated);

      // Now peerId2 should be the LRU
      final peerId3 = createPeerId(3);
      final node3 = createNode(peerId3);
      cache.put(peerId3, node3);

      expect(cache.get(peerId2), isNull); // Evicted
      expect(cache.get(peerId1), equals(node1Updated));
      expect(cache.get(peerId3), equals(node3));
    });

    test('get() should move middle item to front', () {
      final cache = LRUCache(3);
      final p1 = createPeerId(1);
      final p2 = createPeerId(2);
      final p3 = createPeerId(3);
      final n1 = createNode(p1);
      final n2 = createNode(p2);
      final n3 = createNode(p3);

      cache.put(p1, n1);
      cache.put(p2, n2);
      cache.put(p3, n3);
      // List: [n3, n2, n1]

      // Access middle item p2
      cache.get(p2);
      // List should be: [n2, n3, n1]

      // Now n1 is still the LRU
      final p4 = createPeerId(4);
      final n4 = createNode(p4);
      cache.put(p4, n4);
      // List should be: [n4, n2, n3]. n1 evicted.

      expect(cache.get(p1), isNull);
      expect(cache.get(p2), equals(n2));
      expect(cache.get(p3), equals(n3));
      expect(cache.get(p4), equals(n4));
    });

    test('getLRUNodes should return nodes in LRU order', () {
      final cache = LRUCache(3);
      final p1 = createPeerId(1);
      final p2 = createPeerId(2);
      final p3 = createPeerId(3);
      final n1 = createNode(p1);
      final n2 = createNode(p2);
      final n3 = createNode(p3);

      cache.put(p1, n1);
      cache.put(p2, n2);
      cache.put(p3, n3);

      final lru = cache.getLRUNodes(2);
      expect(lru.length, equals(2));
      expect(lru[0], equals(n1)); // Least recently used
      expect(lru[1], equals(n2));
    });

    test(
      'getLRUNodes should return fewer nodes if cache is smaller than count',
      () {
        final cache = LRUCache(5);
        final p1 = createPeerId(1);
        final n1 = createNode(p1);
        cache.put(p1, n1);

        final lru = cache.getLRUNodes(3);
        expect(lru.length, equals(1));
        expect(lru[0], equals(n1));
      },
    );

    test('should work with capacity 1', () {
      final cache = LRUCache(1);
      final p1 = createPeerId(1);
      final n1 = createNode(p1);
      final p2 = createPeerId(2);
      final n2 = createNode(p2);

      cache.put(p1, n1);
      expect(cache.get(p1), equals(n1));

      cache.put(p2, n2);
      expect(cache.get(p1), isNull);
      expect(cache.get(p2), equals(n2));
    });

    test('put same key multiple times should not increase size', () {
      final cache = LRUCache(2);
      final p1 = createPeerId(1);
      final n1 = createNode(p1);

      cache.put(p1, n1);
      cache.put(p1, n1);
      cache.put(p1, n1);

      final lru = cache.getLRUNodes(5);
      expect(lru.length, equals(1));
    });

    test('getLRUNodes on empty cache should return empty list', () {
      final cache = LRUCache(10);
      expect(cache.getLRUNodes(5), isEmpty);
    });

    test('should throw error for non-positive capacity', () {
      expect(() => LRUCache(0), throwsA(isA<AssertionError>()));
      expect(() => LRUCache(-1), throwsA(isA<AssertionError>()));
    });
  });
}
