@Tags(['p0'])
library;

import 'package:test/test.dart';

void main() {
  group('P0 Bitswap fetch with Kubo', () {
    test(
      'dart_ipfs can fetch a block from Kubo via Bitswap',
      () {
        // TODO: Implement once Bitswap can retrieve blocks from Kubo.
      },
      skip: 'TODO: implement Bitswap fetch scenario',
    );

    test(
      'Kubo can fetch a block from dart_ipfs via Bitswap',
      () {
        // TODO: Implement the reverse Bitswap direction.
      },
      skip: 'TODO: implement reverse Bitswap fetch scenario',
    );
  });
}
