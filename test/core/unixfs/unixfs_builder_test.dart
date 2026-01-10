import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:test/test.dart';

void main() {
  group('UnixFSBuilder', () {
    test('should chunk stream and produce blocks', () async {
      final builder = UnixFSBuilder();

      // Create a stream larger than defaultChunkSize (256KB)
      // Say 300KB
      final chunk1 = List<int>.filled(200 * 1024, 65); // 'A'
      final chunk2 = List<int>.filled(100 * 1024, 66); // 'B'

      final stream = Stream<List<int>>.fromIterable([chunk1, chunk2]);

      final blocks = <Block>[];
      await for (final block in builder.build(stream)) {
        blocks.add(block);
      }

      // Total 300KB
      // Default chunk size 256KB
      // Expected:
      // 1. Leaf (~256KB)
      // 2. Leaf (~44KB)
      // 3. Root (linking to 1 and 2)

      expect(blocks.length, greaterThanOrEqualTo(3));

      final rootBlock = blocks.last;
      expect(rootBlock.data, isNotEmpty);

      // Verify first leaf size
      final firstBlock = blocks[0];
      // 256 * 1024 = 262144 bytes + protobuf overhead?
      // UnixFSBuilder yields encoded blocks.
      // We assume simple wrapping.
      expect(
        firstBlock.data.length,
        greaterThan(256 * 1024),
      ); // Due to protobuf wrap
    });

    test('should handle small stream efficiently', () async {
      final builder = UnixFSBuilder();
      final data = [1, 2, 3, 4, 5];
      final stream = Stream<List<int>>.value(data);

      final blocks = await builder.build(stream).toList();

      // Should likely produce 2 blocks (Leaf + Root) OR 1 if optimized?
      // Our implementation produces Leaf then Root linking to it.
      expect(blocks.length, 2);

      final leaf = blocks[0];
      expect(leaf.data.length, greaterThan(5)); // Wrapped
    });
  });
}
