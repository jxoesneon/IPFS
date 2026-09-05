import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ipfs/flutter_ipfs.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIPFSNode implements IPFSNode {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IpfsScope', () {
    testWidgets('provides ambient node to child widgets', (tester) async {
      final fakeNode = _FakeIPFSNode();
      IPFSNode? retrievedNode;

      await tester.pumpWidget(
        IpfsScope(
          node: fakeNode,
          child: Builder(
            builder: (context) {
              retrievedNode = IpfsScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedNode, equals(fakeNode));
    });

    testWidgets('maybeOf returns null when no scope present', (tester) async {
      IPFSNode? retrievedNode;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            retrievedNode = IpfsScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(retrievedNode, isNull);
    });

    testWidgets('of throws descriptive FlutterError when scope missing', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(
              () => IpfsScope.of(context),
              throwsA(isA<FlutterError>()),
            );
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('updateShouldNotify fires when node instance changes', (tester) async {
      final node1 = _FakeIPFSNode();
      final node2 = _FakeIPFSNode();
      int builds = 0;

      Widget buildTree(IPFSNode n) {
        return IpfsScope(
          node: n,
          child: Builder(
            builder: (context) {
              IpfsScope.of(context);
              builds++;
              return const SizedBox();
            },
          ),
        );
      }

      await tester.pumpWidget(buildTree(node1));
      expect(builds, equals(1));

      await tester.pumpWidget(buildTree(node2));
      expect(builds, equals(2));
    });
  });
}
