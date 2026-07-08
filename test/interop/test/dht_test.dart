@Tags(['p1'])
library;

import 'package:test/test.dart';

void main() {
  group('P1 DHT provide/find with Kubo', () {
    test(
      'dart_ipfs provides a CID and Kubo finds it as a provider',
      () {
        // TODO: Implement once the DHT client supports iterative queries and
        // provider records.
      },
      skip: 'DHT client is single-hop; scenario deferred per Council decision',
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Kubo provides a CID and dart_ipfs finds it as a provider',
      () {
        // TODO: Implement reverse DHT provide/find scenario.
      },
      skip: 'DHT client is single-hop; scenario deferred per Council decision',
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
