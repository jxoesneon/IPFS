@TestOn('vm')
library;

import 'package:dart_ipfs/src/network/mdns_client_web.dart';
import 'package:test/test.dart';

void main() {
  group('createMDnsClient (web)', () {
    test('throws a descriptive UnsupportedError', () {
      expect(
        createMDnsClient,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('web platform'), contains('UDP multicast')),
          ),
        ),
      );
    });
  });
}
