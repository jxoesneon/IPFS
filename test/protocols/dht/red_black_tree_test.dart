import 'dart:typed_data';

import 'package:dart_ipfs/src/protocols/dht/kademlia_tree/kademlia_tree_node.dart';
import 'package:dart_ipfs/src/protocols/dht/red_black_tree.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart' as dfs;
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

void main() {
  group('RedBlackTree', () {
    late RedBlackTree<int, String> intTree;

    setUp(() {
      intTree = RedBlackTree<int, String>(compare: (a, b) => a.compareTo(b));
    });

    test('insert adds new entries', () {
      intTree.insert(5, 'five');
      intTree.insert(3, 'three');
      intTree.insert(7, 'seven');

      expect(intTree.size, equals(3));
      expect(intTree.search(5), equals('five'));
      expect(intTree.search(3), equals('three'));
      expect(intTree.search(7), equals('seven'));
    });

    test('insert updates existing entry on duplicate key', () {
      intTree.insert(5, 'five');
      expect(intTree.size, equals(1));
      expect(intTree.search(5), equals('five'));

      // Insert same key with new value
      intTree.insert(5, 'FIVE_UPDATED');

      // Size should remain 1 (no duplicate added)
      expect(intTree.size, equals(1));
      // Value should be updated
      expect(intTree.search(5), equals('FIVE_UPDATED'));
    });

    test('operator[] returns correct value', () {
      intTree.insert(10, 'ten');
      intTree.insert(20, 'twenty');

      expect(intTree[10], equals('ten'));
      expect(intTree[20], equals('twenty'));
      expect(intTree[30], isNull); // Non-existent key
    });

    test('operator[]= inserts or updates entry', () {
      intTree[1] = 'one';
      intTree[2] = 'two';

      expect(intTree.size, equals(2));
      expect(intTree[1], equals('one'));

      // Update via operator
      intTree[1] = 'ONE_UPDATED';
      expect(intTree.size, equals(2));
      expect(intTree[1], equals('ONE_UPDATED'));
    });

    test('entries list is updated correctly', () {
      intTree.insert(1, 'one');
      intTree.insert(2, 'two');
      intTree.insert(3, 'three');

      expect(intTree.entries.length, equals(3));

      // Update existing entry
      intTree.insert(2, 'TWO_UPDATED');

      expect(intTree.entries.length, equals(3)); // Still 3

      // Find the entry for key 2
      final entry2 = intTree.entries.firstWhere((e) => e.key == 2);
      expect(entry2.value, equals('TWO_UPDATED'));
    });

    test('clear removes all entries', () {
      intTree.insert(1, 'one');
      intTree.insert(2, 'two');

      expect(intTree.size, equals(2));

      intTree.clear();

      expect(intTree.size, equals(0));
      expect(intTree.isEmpty, isTrue);
      expect(intTree.entries, isEmpty);
    });
  });

  group('RedBlackTree with PeerId keys', () {
    late RedBlackTree<p2p.PeerId, KademliaTreeNode> peerTree;

    // Comparator that compares PeerIds by their bytes
    int peerIdComparator(p2p.PeerId a, p2p.PeerId b) {
      for (int i = 0; i < a.value.length && i < b.value.length; i++) {
        if (a.value[i] != b.value[i]) {
          return a.value[i].compareTo(b.value[i]);
        }
      }
      return a.value.length.compareTo(b.value.length);
    }

    setUp(() {
      peerTree = RedBlackTree<p2p.PeerId, KademliaTreeNode>(
        compare: peerIdComparator,
      );
    });

    p2p.PeerId makePeerId(int fillValue) =>
        p2p.PeerId(value: Uint8List.fromList(List.filled(64, fillValue)));

    KademliaTreeNode makeNode(p2p.PeerId peerId) => KademliaTreeNode(
          dfs.PeerId(value: peerId.value),
          0,
          dfs.PeerId(value: peerId.value),
          lastSeen: 0,
        );

    test('handles PeerId keys correctly', () {
      final peer1 = makePeerId(1);
      final peer2 = makePeerId(2);
      final peer3 = makePeerId(3);

      peerTree[peer1] = makeNode(peer1);
      peerTree[peer2] = makeNode(peer2);
      peerTree[peer3] = makeNode(peer3);

      expect(peerTree.size, equals(3));
      expect(peerTree[peer1], isNotNull);
      expect(peerTree[peer2], isNotNull);
      expect(peerTree[peer3], isNotNull);
    });

    test('duplicate PeerId updates existing node', () {
      final peer1 = makePeerId(1);
      final node1 = makeNode(peer1);

      peerTree[peer1] = node1;
      expect(peerTree.size, equals(1));

      // Create new node with same peerId
      final node1Updated = KademliaTreeNode(
        dfs.PeerId(value: peer1.value),
        100, // different distance
        dfs.PeerId(value: peer1.value),
        lastSeen: 999,
      );

      peerTree[peer1] = node1Updated;

      // Size should remain 1
      expect(peerTree.size, equals(1));

      // Retrieved node should have updated values
      final retrieved = peerTree[peer1]!;
      expect(retrieved.distance, equals(100));
      expect(retrieved.lastSeen, equals(999));
    });
  });
}
