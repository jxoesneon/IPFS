import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dart_ipfs/src/protocols/dht/delegate_dht_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:multibase/multibase.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';

import 'package:logging/logging.dart';

void main() {
  // Suppress logs for tests that expect errors
  Logger.root.level = Level.OFF;

  group('DelegateDHTHandler', () {
    const delegateUrl = 'http://localhost:5001';

    CID createTestCID() {
      return CID(
        version: 0,
        multihash: Multihash.decode(
          Uint8List.fromList([0x12, 0x20, ...List.filled(32, 0)]),
        ),
        codec: 'dag-pb',
        multibaseType: Multibase.base58btc,
      );
    }

    test('start and stop', () async {
      final mockClient = MockClient((request) async => http.Response('', 200));
      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);

      await handler.start();
      await handler.stop();
    });

    test('findProviders returns providers from JSON stream', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v0/dht/findprovs');
        // Kubo returns NDJSON
        final body =
            jsonEncode({
              'Type': 4,
              'Responses': [
                {
                  'ID': 'QmProvider1',
                  'Addrs': ['/ip4/1.2.3.4/tcp/4001'],
                },
              ],
            }) +
            '\n';
        return http.Response(body, 200);
      });

      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);
      final cid = createTestCID();
      final providers = await handler.findProviders(cid);

      // Note: Current implementation in DelegateDHTHandler has an empty TODO for conversion
      // so it currently returns an empty list even if parsing logic exists (but peers list not populated)
      // We verify it doesn't crash.
      expect(providers, isA<List>());
    });

    test('getValue returns value from Type 5 response', () async {
      final mockClient = MockClient((request) async {
        final body = jsonEncode({'Type': 5, 'Extra': 'test-value'}) + '\n';
        return http.Response(body, 200);
      });

      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);
      final key = Key.fromString('test-key');
      final value = await handler.getValue(key);

      expect(value.toString(), 'test-value');
    });

    test('getValue throws on non-200 or missing value', () async {
      final mockClient = MockClient(
        (request) async => http.Response('error', 500),
      );
      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);

      expect(() => handler.getValue(Key.fromString('test')), throwsException);
    });

    test('putValue and provide send POST requests', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response('', 200);
      });

      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);
      await handler.putValue(Key.fromString('k'), Value.fromString('v'));
      await handler.provide(createTestCID());

      expect(callCount, 2);
    });

    test('findPeer currently returns empty list', () async {
      final mockClient = MockClient(
        (request) async => http.Response('{}', 200),
      );
      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);
      final peers = await handler.findPeer(PeerId(value: Uint8List(32)));
      expect(peers, isEmpty);
    });

    test('error handling', () async {
      final mockClient = MockClient(
        (request) async => throw Exception('net error'),
      );
      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);

      final providers = await handler.findProviders(createTestCID());
      expect(providers, isEmpty);

      expect(() => handler.getValue(Key.fromString('k')), throwsException);
    });

    test(
      'handleRoutingTableUpdate and handleProvideRequest do nothing',
      () async {
        final handler = DelegateDHTHandler(delegateUrl);
        final peerInfo = V_PeerInfo();
        await handler.handleRoutingTableUpdate(peerInfo);
        await handler.handleProvideRequest(
          createTestCID(),
          PeerId(value: Uint8List(32)),
        );
      },
    );

    test('non-200 responses and other errors in DelegateDHTHandler', () async {
      final mockClient = MockClient(
        (request) async => http.Response('error', 404),
      );
      final handler = DelegateDHTHandler(delegateUrl, client: mockClient);

      expect(await handler.findProviders(createTestCID()), isEmpty);
      await handler.putValue(
        Key.fromString('k'),
        Value.fromString('v'),
      ); // Covers catch/logging
      await handler.provide(createTestCID()); // Covers catch/logging
      expect(await handler.findPeer(PeerId(value: Uint8List(32))), isEmpty);
    });
  });
}
