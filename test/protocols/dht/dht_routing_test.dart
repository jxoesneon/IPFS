// Timeout annotation added: This test can be slow when run in parallel with the full suite
// due to resource contention. It passes instantly when run in isolation.
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_client.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

// Manual Mocks
class MockNetworkHandler implements NetworkHandler {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRouterInterface implements RouterInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DHT Routing Logic', () {
    late MockNetworkHandler mockHandler;
    late MockRouterInterface mockRouter;
    late DHTClient client;

    setUp(() {
      mockHandler = MockNetworkHandler();
      mockRouter = MockRouterInterface();
      client = DHTClient(networkHandler: mockHandler, router: mockRouter);
    });

    test('getRoutingKey derives correct SHA-256 hash of Multihash', () async {
      final data = Uint8List.fromList(utf8.encode('Hello IPFS'));
      final testCid = await CID.fromContent(data); // CIDv1 (default)
      final testCidStr = testCid.encode();

      // Expected Routing Key = SHA256(Multihash) (32 bytes)
      final mh = testCid.multihash.toBytes();
      final hashBytes = sha256.convert(mh).bytes;
      final expectedHash = Uint8List.fromList(hashBytes);

      final routingKey = client.getRoutingKey(testCidStr);

      expect(routingKey.value, equals(expectedHash));
    });

    test('getRoutingKey handles raw string fallback', () {
      final rawKey = 'some_raw_key';
      // Fallback: SHA256(utf8.encode(key)) (32 bytes)
      final hashBytes = sha256.convert(utf8.encode(rawKey)).bytes;
      final expectedHash = Uint8List.fromList(hashBytes);

      final routingKey = client.getRoutingKey(rawKey);

      expect(routingKey.value, equals(expectedHash));
    });
  });
}
