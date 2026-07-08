@Tags(['p1'])
library;

import 'package:test/test.dart';

void main() {
  group('P1 IPNS resolution with Kubo', () {
    test(
      'dart_ipfs publishes a signed IPNS record and Kubo resolves it',
      () {
        // TODO: Implement once IPNS publishing and PeerId base36 primitives are
        // available.
      },
      skip:
          'IPNS publishing is stubbed; scenario deferred per Council decision',
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Kubo publishes a signed IPNS record and dart_ipfs resolves it',
      () {
        // TODO: Implement reverse IPNS resolution scenario.
      },
      skip:
          'IPNS resolution is stubbed; scenario deferred per Council decision',
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
