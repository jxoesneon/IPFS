import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/protocols/dht/delegate_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DelegateDHTHandler', () {
    late DelegateDHTHandler handler;
    late MockClient mockClient;
    const delegateUrl = 'https://delegate.ipfs.io';

    test('findProviders returns peers on success', () async {
      final cid = await CID.fromContent(
        Uint8List.fromList(utf8.encode('test')),
      );

      mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v0/dht/findprovs')) {
          final response = {
            'Type': 4,
            'Responses': [
              {
                'ID': 'QmPeerID',
                'Addrs': ['/ip4/127.0.0.1/tcp/4001'],
              },
            ],
          };
          return http.Response(jsonEncode(response) + '\n', 200);
        }
        return http.Response('Not Found', 404);
      });

      handler = DelegateDHTHandler(delegateUrl, client: mockClient);

      final providers = await handler.findProviders(cid);
      expect(providers, isA<List>());
    });

    test('getValue returns value on success', () async {
      final key = Key.fromString('/pk/test');
      final valueData = 'Hello World';

      mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v0/dht/get')) {
          final response = {'Type': 5, 'Extra': valueData};
          return http.Response(jsonEncode(response) + '\n', 200);
        }
        return http.Response('Not Found', 404);
      });

      handler = DelegateDHTHandler(delegateUrl, client: mockClient);

      final value = await handler.getValue(key);
      expect(value.toString(), equals(valueData));
    });

    test('putValue sends correct request', () async {
      final key = Key.fromString('/pk/test');
      final value = Value.fromString('data');
      var requestSent = false;

      mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v0/dht/put')) {
          requestSent = true;
          return http.Response('{}', 200);
        }
        return http.Response('Error', 500);
      });

      handler = DelegateDHTHandler(delegateUrl, client: mockClient);
      await handler.putValue(key, value);
      expect(requestSent, isTrue);
    });
  });
}
