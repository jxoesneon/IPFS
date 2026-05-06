import 'package:dart_ipfs/src/protocols/dht/red_black_tree.dart';
import 'package:dart_ipfs/src/protocols/dht/red_black_tree/rotations.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart'
    as common_tree;
import 'package:test/test.dart';

void main() {
  group('RedBlackTree', () {
    late RedBlackTree<int, String> tree;
    late Rotations<int, String> rotations;

    setUp(() {
      tree = RedBlackTree<int, String>(compare: (a, b) => a.compareTo(b));
      rotations = Rotations<int, String>();
    });

    test('Initial tree is empty', () {
      expect(tree.isEmpty, isTrue);
      expect(tree.size, 0);
      expect(tree.root, isNull);
    });

    test('Single insertion', () {
      tree.insert(10, 'Value 10');
      expect(tree.isEmpty, isFalse);
      expect(tree.size, 1);
      expect(tree.root, isNotNull);
      expect(tree.root!.key, 10);
      expect(tree.root!.color, common_tree.NodeColor.BLACK);
    });

    test('Multiple insertions without rebalancing', () {
      tree.insert(10, 'Value 10');
      tree.insert(5, 'Value 5');
      tree.insert(15, 'Value 15');

      expect(tree.size, 3);
      expect(tree.root!.key, 10);
      expect(tree.root!.leftChild!.key, 5);
      expect(tree.root!.rightChild!.key, 15);

      expect(tree.root!.color, common_tree.NodeColor.BLACK);
      expect(tree.root!.leftChild!.color, common_tree.NodeColor.RED);
      expect(tree.root!.rightChild!.color, common_tree.NodeColor.RED);
    });

    test('Insertion Case 1: Uncle is RED (Recoloring)', () {
      // 10(B) -> 5(R), 15(R)
      tree.insert(10, '10');
      tree.insert(5, '5');
      tree.insert(15, '15');

      // Add 2, uncle (15) is RED
      tree.insert(2, '2');

      // Should recolor 5 and 15 to BLACK, 10 to RED (then root back to BLACK)
      expect(tree.root!.key, 10);
      expect(tree.root!.color, common_tree.NodeColor.BLACK);
      expect(tree.root!.leftChild!.key, 5);
      expect(tree.root!.leftChild!.color, common_tree.NodeColor.BLACK);
      expect(tree.root!.rightChild!.key, 15);
      expect(tree.root!.rightChild!.color, common_tree.NodeColor.BLACK);
      expect(tree.root!.leftChild!.leftChild!.key, 2);
      expect(tree.root!.leftChild!.leftChild!.color, common_tree.NodeColor.RED);

      expect(rotations.validateTree(tree), isTrue);
    });

    test('Insertion Case 2 & 3: Uncle is BLACK (Rotations)', () {
      // Case 3: Left-Left (Right Rotation)
      tree.insert(10, '10');
      tree.insert(5, '5');
      tree.insert(2, '2'); // Trigger Case 3

      expect(tree.root!.key, 5);
      expect(tree.root!.color, common_tree.NodeColor.BLACK);
      expect(tree.root!.leftChild!.key, 2);
      expect(tree.root!.leftChild!.color, common_tree.NodeColor.RED);
      expect(tree.root!.rightChild!.key, 10);
      expect(tree.root!.rightChild!.color, common_tree.NodeColor.RED);

      expect(rotations.validateTree(tree), isTrue);

      // Case 2 then 3: Left-Right (Left then Right Rotation)
      tree.clear();
      tree.insert(10, '10');
      tree.insert(5, '5');
      tree.insert(7, '7'); // Trigger Case 2 then Case 3

      expect(tree.root!.key, 7);
      expect(tree.root!.color, common_tree.NodeColor.BLACK);
      expect(tree.root!.leftChild!.key, 5);
      expect(tree.root!.leftChild!.color, common_tree.NodeColor.RED);
      expect(tree.root!.rightChild!.key, 10);
      expect(tree.root!.rightChild!.color, common_tree.NodeColor.RED);

      expect(rotations.validateTree(tree), isTrue);
    });

    test('Deletion: Simple red node', () {
      tree.insert(10, '10');
      tree.insert(5, '5');
      tree.insert(15, '15');

      tree.delete(5);
      expect(tree.size, 2);
      expect(tree.root!.key, 10);
      expect(tree.root!.leftChild, isNull);
      expect(tree.root!.rightChild!.key, 15);
      expect(rotations.validateTree(tree), isTrue);
    });

    test('Deletion: Black node with one red child', () {
      tree.insert(10, '10');
      tree.insert(5, '5');
      tree.delete(10);

      expect(tree.root!.key, 5);
      expect(tree.root!.color, common_tree.NodeColor.BLACK);
      expect(rotations.validateTree(tree), isTrue);
    });

    test('Search operations', () {
      tree.insert(10, '10');
      tree.insert(5, '5');
      tree.insert(15, '15');

      expect(tree.search(10), '10');
      expect(tree.search(5), '5');
      expect(tree.search(15), '15');
      expect(tree.search(20), isNull);

      expect(tree[10], '10');
      tree[20] = '20';
      expect(tree[20], '20');
    });

    test('Update existing key', () {
      tree.insert(10, 'Original');
      tree.insert(10, 'Updated');

      expect(tree.size, 1);
      expect(tree.search(10), 'Updated');
      expect(tree.entries.length, 1);
      expect(tree.entries.first.value, 'Updated');
    });

    test('Clear tree', () {
      tree.insert(10, '10');
      tree.insert(5, '5');
      tree.clear();

      expect(tree.isEmpty, isTrue);
      expect(tree.size, 0);
      expect(tree.root, isNull);
      expect(tree.entries, isEmpty);
    });

    test('Complex rebalancing after deletions', () {
      // Create a tree that requires complex fix-ups
      final values = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
      for (var v in values) {
        tree.insert(v, v.toString());
      }
      expect(rotations.validateTree(tree), isTrue);

      // Delete multiple nodes
      final toDelete = [10, 30, 50, 70, 90];
      for (var v in toDelete) {
        tree.delete(v);
        expect(rotations.validateTree(tree), isTrue);
      }

      expect(tree.size, 5);
    });

    group('Exhaustive Deletion Cases', () {
      test('Deletion Case 1: Sibling is RED', () {
        // Construct Case 1: x is black, sibling w is red
        // x must be black, parent red or black, w red
        // To have w red, w's children must be black.
        //     parent(B)
        //    /      \
        //   x(B)     w(R)
        //           /   \
        //          Sl(B) Sr(B)

        tree.insert(10, '10');
        tree.insert(5, '5');
        tree.insert(20, '20');
        tree.insert(15, '15');
        tree.insert(25, '25');

        // Tree: 10(B) -> 5(B), 20(B) -> 15(R), 25(R)
        // We need 20 to be RED.
        // If we delete 5, x is null (black leaf), parent is 10, sibling is 20.
        // But 20 is black here.

        // Let's use a specific sequence to get the desired structure.
        tree.clear();
        for (var i in [30, 20, 40, 35, 50]) {
          tree.insert(i, i.toString());
        }
        // 30(B) -> 20(B), 40(B) -> 35(R), 50(R)

        tree.delete(20);
        // After deleting 20, x is null, parent is 30, sibling is 40.
        // w(40) is BLACK. This is NOT Case 1.

        // Let's try to trigger Case 1:
        tree.clear();
        for (var i in [10, 20, 30, 40, 50, 60]) {
          tree.insert(i, i.toString());
        }
        // Structure:
        //      30(B)
        //     /    \
        //   20(B)   50(B)
        //   /      /    \
        // 10(B)  40(B)  60(B)

        // If we delete 10:
        tree.delete(10);
        expect(rotations.validateTree(tree), isTrue);
      });

      test('Case 2: Sibling is BLACK, both children are BLACK', () {
        tree.clear();
        tree.insert(20, '20');
        tree.insert(10, '10');
        tree.insert(30, '30');
        // Delete 10, sibling 30 is black, its children are null(black).
        tree.delete(10);
        expect(rotations.validateTree(tree), isTrue);
      });

      test('Case 3 & 4: Sibling BLACK, one or both children RED', () {
        // Case 4: Right child is RED
        tree.clear();
        tree.insert(20, '20');
        tree.insert(10, '10');
        tree.insert(30, '30');
        tree.insert(40, '40');
        // 20(B) -> 10(B), 30(B) -> null, 40(R)
        tree.delete(10);
        expect(rotations.validateTree(tree), isTrue);

        // Case 3: Left child is RED, Right child is BLACK
        tree.clear();
        tree.insert(20, '20');
        tree.insert(10, '10');
        tree.insert(40, '40');
        tree.insert(30, '30');
        // 20(B) -> 10(B), 40(B) -> 30(R), null
        tree.delete(10);
        expect(rotations.validateTree(tree), isTrue);
      });

      test('Mirror Cases (x is right child)', () {
        // Case 2 Mirror
        tree.clear();
        tree.insert(20, '20');
        tree.insert(10, '10');
        tree.insert(30, '30');
        tree.delete(30);
        expect(rotations.validateTree(tree), isTrue);

        // Case 4 Mirror: Sibling(10) has Left child(5) RED
        tree.clear();
        tree.insert(20, '20');
        tree.insert(10, '10');
        tree.insert(30, '30');
        tree.insert(5, '5');
        tree.delete(30);
        expect(rotations.validateTree(tree), isTrue);

        // Case 3 Mirror: Sibling(10) has Right child(15) RED
        tree.clear();
        tree.insert(20, '20');
        tree.insert(10, '10');
        tree.insert(30, '30');
        tree.insert(15, '15');
        tree.delete(30);
        expect(rotations.validateTree(tree), isTrue);
      });

      test('Delete node with two children', () {
        tree.clear();
        for (var i in [50, 25, 75, 10, 35, 60, 90]) {
          tree.insert(i, i.toString());
        }
        // Delete root
        tree.delete(50);
        expect(rotations.validateTree(tree), isTrue);
        expect(tree.search(50), isNull);
        expect(tree.size, 6);

        // Delete node with two children where successor is not immediate right child
        tree.delete(25);
        expect(rotations.validateTree(tree), isTrue);
        expect(tree.search(25), isNull);
      });

      test('Delete non-existent node', () {
        tree.insert(10, '10');
        tree.delete(20);
        expect(tree.size, 1);
      });

      test('Delete all nodes one by one', () {
        final values = [10, 20, 30, 40, 50];
        for (var v in values) {
          tree.insert(v, v.toString());
        }
        for (var v in values) {
          tree.delete(v);
          expect(rotations.validateTree(tree), isTrue);
        }
        expect(tree.isEmpty, isTrue);
      });
    });

    test('Rotation edge cases', () {
      // rotateLeft on null
      rotations.rotateLeft(tree, null);
      // rotateRight on null
      rotations.rotateRight(tree, null);

      tree.insert(10, '10');
      // rotateLeft on node with no right child
      rotations.rotateLeft(tree, tree.root);
      expect(tree.root!.key, 10);

      // rotateRight on node with no left child
      rotations.rotateRight(tree, tree.root);
      expect(tree.root!.key, 10);
    });

    test('validateTree size mismatch', () {
      tree.insert(10, '10');
      tree.size = 2; // Sabotage size
      expect(rotations.validateTree(tree), isFalse);
    });
  });
}
