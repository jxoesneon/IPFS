@Tags(['p0'])
library;

import 'package:test/test.dart';

void main() {
  group('P0 CAR exchange with Kubo', () {
    test(
      'dart_ipfs can export a CAR that Kubo can import',
      () {
        // TODO: Implement the full CAR exchange scenario once the RPC clients
        // support /api/v0/dag/export and /api/v0/dag/import.
      },
      skip: 'TODO: implement CAR exchange scenario',
    );

    test(
      'Kubo can export a CAR that dart_ipfs can import',
      () {
        // TODO: Implement the reverse CAR exchange scenario.
      },
      skip: 'TODO: implement CAR exchange scenario',
    );
  });
}
