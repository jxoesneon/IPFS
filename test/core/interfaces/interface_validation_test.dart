import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:test/test.dart';

void main() {
  group('Interface validation', () {
    test('IBlockStore interface is defined', () {
      expect(IBlockStore, isNotNull);
    });
  });
}
