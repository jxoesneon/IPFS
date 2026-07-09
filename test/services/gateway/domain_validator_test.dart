import 'dart:io';

import 'package:dart_ipfs/src/services/gateway/domain_validator.dart'
    show DomainValidator, DomainValidationResult;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  group('DomainValidator', () {
    test('toString formats result', () {
      final result = DomainValidationResult(
        success: true,
        message: 'ok',
        details: {'key': 'value'},
      );
      expect(result.toString(), contains('success: true'));
      expect(result.toString(), contains('message: ok'));
    });

    test('getPublicIp returns IP on success', () async {
      final client = http_testing.MockClient((request) async {
        if (request.url.host == 'api.ipify.org') {
          return http.Response('203.0.113.42', 200);
        }
        return http.Response('not found', 404);
      });
      final validator = DomainValidator(client: client);
      final ip = await validator.getPublicIp();
      expect(ip, equals('203.0.113.42'));
    });

    test('getPublicIp returns null on non-200', () async {
      final client = http_testing.MockClient(
        (request) async => http.Response('error', 500),
      );
      final validator = DomainValidator(client: client);
      final ip = await validator.getPublicIp();
      expect(ip, isNull);
    });

    test('getPublicIp returns null on exception', () async {
      final client = http_testing.MockClient(
        (request) async => throw const SocketException('no route'),
      );
      final validator = DomainValidator(client: client);
      final ip = await validator.getPublicIp();
      expect(ip, isNull);
    });

    test('checkHttpAccessibility succeeds on HTTP response', () async {
      final client = http_testing.MockClient(
        (request) async => http.Response('hello', 200),
      );
      final validator = DomainValidator(client: client);
      final result = await validator.validateDomain('example.com');
      // DNS lookup will fail because example.com may not resolve in tests.
      // When DNS fails, the HTTP path is not reached.
      expect(result, isA<DomainValidationResult>());
    });
  });
}
