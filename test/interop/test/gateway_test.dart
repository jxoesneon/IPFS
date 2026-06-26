@Tags(['p0'])
library;

import 'package:test/test.dart';

void main() {
  group('P0 Gateway retrieval with Kubo', () {
    test(
      'trustless gateway returns raw block with correct headers',
      () {
        // TODO: Implement ?format=raw gateway retrieval check.
      },
      skip: 'TODO: implement gateway raw block scenario',
    );

    test(
      'trustless gateway returns a CAR response',
      () {
        // TODO: Implement ?format=car gateway retrieval check.
      },
      skip: 'TODO: implement gateway CAR scenario',
    );

    test(
      'default gateway response returns the original content',
      () {
        // TODO: Implement default gateway retrieval check.
      },
      skip: 'TODO: implement default gateway scenario',
    );
  });
}
