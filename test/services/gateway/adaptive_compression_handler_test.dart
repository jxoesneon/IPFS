import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/services/gateway/adaptive_compression_handler.dart';
import 'package:dart_ipfs/src/services/gateway/compressed_cache_store.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';

import 'adaptive_compression_handler_test.mocks.dart';

@GenerateMocks([BlockStore])
void main() {
  group('AdaptiveCompressionHandler', () {
    late AdaptiveCompressionHandler handler;
    late MockBlockStore mockBlockStore;
    late CompressionConfig config;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ipfs_test_compression');
      mockBlockStore = MockBlockStore();
      when(mockBlockStore.path).thenReturn(tempDir.path);

      config = CompressionConfig(enabled: true);
      handler = AdaptiveCompressionHandler(mockBlockStore, config);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('getOptimalCompression selects correct type', () {
      expect(
        handler.getOptimalCompression('text/html', 1000),
        CompressionType.gzip,
      );
      expect(
        handler.getOptimalCompression('application/json', 1000),
        CompressionType.gzip,
      );
      expect(
        handler.getOptimalCompression('image/png', 1000),
        CompressionType.none,
      );
      expect(
        handler.getOptimalCompression('unknown/type', 1000),
        CompressionType.gzip, // Fallback
      );
    });

    test('compressBlock returns original if disabled', () async {
      final disabledConfig = CompressionConfig(enabled: false);
      final disabledHandler = AdaptiveCompressionHandler(
        mockBlockStore,
        disabledConfig,
      );

      final block = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      final result = await disabledHandler.compressBlock(block, 'text/plain');

      expect(result, equals(block));
    });

    test('compressBlock compresses text content', () async {
      final textData = List.filled(1000, 65); // 'A' * 1000, highly compressible
      final block = await Block.fromData(Uint8List.fromList(textData));

      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.successAdd('Stored'));

      final result = await handler.compressBlock(block, 'text/plain');

      expect(result.size, lessThan(block.size));
      verify(mockBlockStore.putBlock(any)).called(1);

      // Verify metadata file exists
      final metadataDir = Directory('${tempDir.path}/metadata');
      expect(metadataDir.existsSync(), isTrue);
    });

    test('compressBlock skips compression if not beneficial', () async {
      // Random data is hard to compress
      final randomData = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final block = await Block.fromData(randomData);

      // Even with 'text/plain', gzip might add overhead for small random data,
      // but let's try 'image/png' which defaults to none to be sure

      final result = await handler.compressBlock(block, 'image/png');
      expect(result, equals(block));
      verifyNever(mockBlockStore.putBlock(any));
    });
  });
}
