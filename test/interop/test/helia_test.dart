@Tags(['helia'])
library;

import 'package:test/test.dart';

void main() {
  group('Helia Bitswap/CAR interop', () {
    test(
      'dart_ipfs can fetch a block from Helia via Bitswap',
      () {
        // TODO: Implement once the Helia harness and Bitswap interop are stable.
      },
      skip: 'Helia interop is nightly-only scaffolding',
    );

    test(
      'dart_ipfs can exchange a CAR with Helia',
      () {
        // TODO: Implement Helia CAR exchange scenario.
      },
      skip: 'Helia interop is nightly-only scaffolding',
    );
  });
}
