import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/services/gateway/lazy_preview_handler.dart';
import 'package:dart_ipfs/src/services/gateway/cached_preview_generator.dart';
import 'package:dart_ipfs/src/services/gateway/preview_cache_manager.dart';
import 'package:dart_ipfs/src/services/gateway/file_preview_handler.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';

import 'gateway_handlers_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<PreviewCacheManager>(),
  MockSpec<FilePreviewHandler>(),
])
void main() {
  group('LazyPreviewHandler', () {
    late LazyPreviewHandler handler;

    setUp(() {
      handler = LazyPreviewHandler();
    });

    test('generateLazyPreview and getPreviewBlock', () async {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final block = await Block.fromData(data);
      final html = handler.generateLazyPreview(block, 'text/plain');

      expect(html, contains('lazy'));
      expect(html, contains('data-preview-id='));

      // Extract previewId from html
      final match = RegExp(r'data-preview-id="([^"]+)"').firstMatch(html);
      final previewId = match!.group(1)!;

      final retrieved = handler.getPreviewBlock(previewId);
      expect(retrieved, isNotNull);
      expect(retrieved!.cid, equals(block.cid));

      // Second retrieval should be null as it is removed from cache
      final retrieved2 = handler.getPreviewBlock(previewId);
      expect(retrieved2, isNull);
    });

    test('getPreviewBlock throws on empty ID', () {
      expect(() => handler.getPreviewBlock(''), throwsArgumentError);
    });

    test('getPreviewBlock returns null for missing ID', () {
      expect(handler.getPreviewBlock('missing'), isNull);
    });

    test('generateLazyLoadScript returns script', () {
      expect(handler.generateLazyLoadScript(), contains('<script>'));
    });

    test('generateLazyLoadStyles returns CSS', () {
      expect(
        handler.generateLazyLoadStyles(),
        contains('.preview-container.lazy'),
      );
    });

    test('validation: empty data block', () async {
      final block = Block(
        cid: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        data: Uint8List(0),
      );
      final html = handler.generateLazyPreview(block, 'text/plain');
      final match = RegExp(r'data-preview-id="([^"]+)"').firstMatch(html);
      final previewId = match!.group(1)!;

      final retrieved = handler.getPreviewBlock(previewId);
      expect(retrieved, isNull);
    });

    test('validation: CID mismatch', () async {
      final block = Block(
        cid: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        data: Uint8List.fromList([1, 2, 3]),
      );
      final html = handler.generateLazyPreview(block, 'text/plain');
      final match = RegExp(r'data-preview-id="([^"]+)"').firstMatch(html);
      final previewId = match!.group(1)!;

      final retrieved = handler.getPreviewBlock(previewId);
      expect(retrieved, isNull);
    });
  });

  group('CachedPreviewGenerator', () {
    late CachedPreviewGenerator generator;
    late MockPreviewCacheManager mockCache;
    late MockFilePreviewHandler mockPreview;

    setUp(() {
      mockCache = MockPreviewCacheManager();
      mockPreview = MockFilePreviewHandler();
      generator = CachedPreviewGenerator(mockCache, mockPreview);
    });

    test('generatePreview - cache hit', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      final cachedBytes = Uint8List.fromList([4, 5, 6]);
      when(
        mockCache.getPreview(block.cid, 'text/plain'),
      ).thenAnswer((_) async => cachedBytes);

      final result = await generator.generatePreview(block, 'text/plain');
      expect(result, equals(cachedBytes));
      verifyNever(mockPreview.generatePreview(any, any));
    });

    test('generatePreview - cache miss, generate success', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      when(
        mockCache.getPreview(block.cid, 'text/plain'),
      ).thenAnswer((_) async => null);
      when(
        mockPreview.generatePreview(block, 'text/plain'),
      ).thenReturn('<html>preview</html>');

      final result = await generator.generatePreview(block, 'text/plain');
      expect(result, isNotNull);
      expect(utf8.decode(result!), equals('<html>preview</html>'));
      verify(mockCache.cachePreview(block.cid, 'text/plain', any)).called(1);
    });

    test('generatePreview - cache miss, generate fail', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      when(
        mockCache.getPreview(block.cid, 'text/plain'),
      ).thenAnswer((_) async => null);
      when(mockPreview.generatePreview(block, 'text/plain')).thenReturn(null);

      final result = await generator.generatePreview(block, 'text/plain');
      expect(result, isNull);
    });

    test('preloadPreviews', () async {
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('hello.txt')),
      );
      // Assuming it detects as text/plain
      when(mockPreview.isSupportedType(any)).thenReturn(true);
      when(mockCache.getPreview(any, any)).thenAnswer((_) async => null);
      when(mockPreview.generatePreview(any, any)).thenReturn('preview');

      await generator.preloadPreviews([block]);
      verify(mockPreview.generatePreview(any, any)).called(1);
    });
  });
}
