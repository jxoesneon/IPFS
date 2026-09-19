@TestOn('vm')
library;

import 'package:dart_ipfs/src/platform/http_server_adapter_stub.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('HttpServerAdapterStub', () {
    final adapter = HttpServerAdapterStub();
    Response handler(Request request) => Response.ok('ok');

    test('serve throws a descriptive UnsupportedError', () {
      expect(
        () => adapter.serve(handler, '127.0.0.1', 8080),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('HTTP server binding'), contains('platform')),
          ),
        ),
      );
    });

    test('serveSecure throws a descriptive UnsupportedError', () {
      expect(
        () => adapter.serveSecure(handler, '127.0.0.1', 8443, Object()),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('HTTPS server binding'), contains('platform')),
          ),
        ),
      );
    });

    test('createHttpServerAdapter returns the stub adapter', () {
      expect(createHttpServerAdapter(), isA<HttpServerAdapterStub>());
    });
  });
}
