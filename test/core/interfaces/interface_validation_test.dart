// Simplified validation tests for interfaces
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/interfaces/block_store_operations.dart';
import 'package:dart_ipfs/src/core/interfaces/block_data.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';

void main() {
  group('Interface Validation', () {
    test('BlockStoreOperations interface is defined', () {
      expect(BlockStoreOperations, isNotNull);
    });

    test('BlockData abstract class is defined', () {
      expect(BlockData, isNotNull);
    });

    test('IBlockStore interface is defined', () {
      expect(IBlockStore, isNotNull);
    });

    test('All interfaces are accessible', () {
      final interfaces = [BlockStoreOperations, BlockData, IBlockStore];

      // All types are non-nullable, so just verify list is not empty
      expect(interfaces, isNotEmpty);
      expect(interfaces.length, equals(3));
    });
  });
}
