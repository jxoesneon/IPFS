import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ipfs/flutter_ipfs.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockIPFSNode implements IPFSNode {
  final Map<String, Uint8List> storage = {};
  final Set<String> calls = {};
  bool shouldFail = false;

  @override
  Future<Uint8List?> get(String cid, {
    String path = '',
    GatewayMode gatewayMode = GatewayMode.internal,
    String customGatewayUrl = '',
  }) async {
    final key = path.isEmpty ? cid : '/';
    calls.add(key);
    if (shouldFail) {
      throw Exception('Mock network failure');
    }
    return storage[key];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// 1x1 transparent PNG bytes for Image.memory testing
final Uint8List _tinyPngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
]);

void main() {
  group('IpfsImage', () {
    testWidgets('displays placeholder while resolving and Image.memory on complete', (tester) async {
      final mockNode = _MockIPFSNode();
      mockNode.storage['bafyimage1'] = _tinyPngBytes;

      final cache = IpfsCacheManager();

      await tester.pumpWidget(
        IpfsScope(
          node: mockNode,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: IpfsImage(
              cid: 'bafyimage1',
              cacheManager: cache,
              placeholder: (context) => const Text('Loading...'),
            ),
          ),
        ),
      );

      // Initially shows placeholder
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      // Await future completion
      await tester.pumpAndSettle();

      // Now shows Image widget
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);

      // Verifies cache was populated
      expect(cache.containsKey('bafyimage1'), isTrue);
    });

    testWidgets('uses cache directly on subsequent builds', (tester) async {
      final mockNode = _MockIPFSNode();
      mockNode.storage['bafyimage2'] = _tinyPngBytes;
      final cache = IpfsCacheManager();
      cache.put('bafyimage2', _tinyPngBytes);

      await tester.pumpWidget(
        IpfsScope(
          node: mockNode,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: IpfsImage(
              cid: 'bafyimage2',
              cacheManager: cache,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      // Node was never called because it was cached
      expect(mockNode.calls.contains('bafyimage2'), isFalse);
    });

    testWidgets('displays errorWidget when node fetch throws', (tester) async {
      final mockNode = _MockIPFSNode();
      mockNode.shouldFail = true;

      await tester.pumpWidget(
        IpfsScope(
          node: mockNode,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: IpfsImage(
              cid: 'bafyfail',
              placeholder: (context) => const Text('Loading...'),
              errorWidget: (context, error) => const Text('Error Occurred'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Error Occurred'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
