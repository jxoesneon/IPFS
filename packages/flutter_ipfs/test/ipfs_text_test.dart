import 'dart:typed_data';
import 'dart:convert';

import 'package:dart_ipfs/dart_ipfs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ipfs/flutter_ipfs.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockIPFSNode implements IPFSNode {
  final Map<String, Uint8List> storage = {};

  @override
  Future<Uint8List?> get(String cid, {
    String path = '',
    GatewayMode gatewayMode = GatewayMode.internal,
    String customGatewayUrl = '',
  }) async {
    final key = path.isEmpty ? cid : '$cid/$path';
    return storage[key];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IpfsText', () {
    testWidgets('fetches and displays UTF-8 text', (tester) async {
      final mockNode = _MockIPFSNode();
      mockNode.storage['bafytext1'] = Uint8List.fromList(utf8.encode('Decentralized Web'));

      await tester.pumpWidget(
        IpfsScope(
          node: mockNode,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: IpfsText(
              cid: 'bafytext1',
              placeholder: (context) => Text('Loading text...'),
            ),
          ),
        ),
      );

      expect(find.text('Loading text...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Decentralized Web'), findsOneWidget);
    });
  });
}
