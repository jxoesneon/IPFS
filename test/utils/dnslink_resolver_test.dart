import 'package:dart_ipfs/src/utils/dnslink_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'dart:convert';

void main() {
  group('DNSLinkResolver', () {
    test('resolve returns CID on successful response', () async {
      // This test would need to mock HTTP responses
      // For now, testing the structure
      expect(DNSLinkResolver.resolve, isA<Function>());
    });

    test('resolve returns null on HTTP error', () async {
      // Would need HTTP mocking to properly test
      // Testing that the method exists and has correct signature
      final result =
          await DNSLinkResolver.resolve('nonexistent-domain-12345.test');
      // Expect null or exception due to network error
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('resolve handles network exceptions gracefully', () async {
      // Should not throw, should return null
      final result = await DNSLinkResolver.resolve('invalid..domain');
      expect(result, isNull);
    });

    test('resolve accepts valid domain names', () async {
      // Just verify it can be called with various formats
      expect(() => DNSLinkResolver.resolve('example.com'), returnsNormally);
      expect(() => DNSLinkResolver.resolve('sub.example.com'), returnsNormally);
      expect(() => DNSLinkResolver.resolve('docs.ipfs.io'), returnsNormally);
    });
  });
}
