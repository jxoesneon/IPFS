import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart' as blockstore_pb;
import 'package:dart_ipfs/src/services/gateway/cached_preview_generator.dart';
import 'package:dart_ipfs/src/services/gateway/file_preview_handler.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:dart_ipfs/src/services/gateway/persistent_preview_cache.dart';
import 'package:dart_ipfs/src/services/gateway/preview_cache_manager.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';

// Mocks
class MockBlockStore implements BlockStore {
  final Map<String, Block> _storage = {};

  @override
  String get path => '/tmp/mock_blockstore';

  @override
  late final PinManager pinManager = PinManager(this);

  @override
  Future<blockstore_pb.AddBlockResponse> putBlock(Block block) async {
    _storage[block.cid.encode()] = block;
    return blockstore_pb.AddBlockResponse();
  }

  @override
  Future<blockstore_pb.GetBlockResponse> getBlock(String cid) async {
    if (_storage.containsKey(cid)) {
      return blockstore_pb.GetBlockResponse()
        ..found = true
        ..block = _storage[cid]!.toProto();
    }
    return blockstore_pb.GetBlockResponse()..found = false;
  }

  @override
  Future<void> deleteBlock(String cid) async {
    _storage.remove(cid);
  }

  @override
  Stream<String> get keys => Stream.fromIterable(_storage.keys);

  @override
  Future<bool> hasBlock(String cid) async {
    return _storage.containsKey(cid);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<List<Block>> getAllBlocks() async {
    return _storage.values.toList();
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'total_blocks': _storage.length,
      'total_size': _storage.values.fold(0, (sum, b) => sum + b.size),
      'pinned_blocks': 0,
    };
  }

  @override
  Future<blockstore_pb.RemoveBlockResponse> removeBlock(String cid) async {
    if (_storage.containsKey(cid)) {
      _storage.remove(cid);
      return blockstore_pb.RemoveBlockResponse()..success = true;
    }
    return blockstore_pb.RemoveBlockResponse()..success = false;
  }
}

class MockFilePreviewHandler implements FilePreviewHandler {
  @override
  String? generatePreview(Block block, String contentType, {int? maxSize}) {
    if (contentType.startsWith('text/')) {
      return utf8.decode(block.data).substring(0, 10) + '...';
    }
    return null;
  }

  @override
  bool isSupportedType(String contentType) {
    return contentType.startsWith('text/');
  }
}

class MockPreviewCacheManager implements PreviewCacheManager {
  final Map<String, Uint8List> _cache = {};

  @override
  Future<Uint8List?> getPreview(CID cid, String contentType) async {
    return _cache['${cid.encode()}_$contentType'];
  }

  @override
  Future<void> cachePreview(CID cid, String contentType, Uint8List preview) async {
    _cache['${cid.encode()}_$contentType'] = preview;
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  Map<String, int> getCacheStats() {
    return {'size': _cache.length};
  }
}

void main() {
  group('GatewayHandler', () {
    late MockBlockStore mockBlockStore;
    late GatewayHandler gatewayHandler;

    setUp(() {
      mockBlockStore = MockBlockStore();
      gatewayHandler = GatewayHandler(mockBlockStore);
    });

    test('should serve text file', () async {
      final content = utf8.encode('Hello IPFS World');
      final block = await Block.fromData(
        Uint8List.fromList(content),
        format: 'raw',
      ); // Test raw first
      await mockBlockStore.putBlock(block);

      final request = Request('GET', Uri.parse('http://localhost:8080/ipfs/${block.cid.encode()}'));
      final response = await gatewayHandler.handlePath(request);

      expect(response.statusCode, equals(200));
      expect(await response.readAsString(), equals('Hello IPFS World'));
      expect(response.headers['X-IPFS-Path'], equals('/ipfs/${block.cid.encode()}'));
    });

    test('should return 404 for missing block', () async {
      final request = Request('GET', Uri.parse('http://localhost:8080/ipfs/QmMissing'));
      final response = await gatewayHandler.handlePath(request);

      expect(response.statusCode, equals(404));
    });

    // ... class definitions ...

    test('should handle range request', () async {
      final content = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      // Create UnixFS block
      final unixFsData = Data()
        ..type = Data_DataType.File
        ..data = content
        ..filesize = Int64(content.length);

      final pbNode = PBNode()..data = unixFsData.writeToBuffer();

      final block = await Block.fromData(pbNode.writeToBuffer(), format: 'dag-pb');

      await mockBlockStore.putBlock(block);

      final request = Request(
        'GET',
        Uri.parse('http://localhost:8080/ipfs/${block.cid.encode()}'),
        headers: {'range': 'bytes=2-5'},
      );
      final response = await gatewayHandler.handlePath(request);

      expect(response.statusCode, equals(206));
      final bytes = await response.read().reduce((a, b) => [...a, ...b]);
      expect(bytes, equals([2, 3, 4, 5]));
      expect(response.headers['Content-Range'], equals('bytes 2-5/10'));
    });
  });

  group('PersistentPreviewCache', () {
    late Directory tempDir;
    late PersistentPreviewCache cache;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ipfs_preview_cache_test');
      cache = PersistentPreviewCache(cachePath: tempDir.path, maxCacheSize: 1024); // Small size
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('should cache and retrieve preview', () async {
      final cid = CID.computeForDataSync(Uint8List.fromList([1, 2, 3]));
      final previewData = Uint8List.fromList(utf8.encode('preview data'));

      await cache.cachePreview(cid, 'text/plain', previewData);

      final cached = await cache.getPreview(cid, 'text/plain');
      expect(cached, isNotNull);
      expect(cached, equals(previewData));
    });

    test('should evict old entries when cache is full', () async {
      final cid1 = CID.computeForDataSync(Uint8List.fromList([1]));
      final cid2 = CID.computeForDataSync(Uint8List.fromList([2]));

      final data1 = Uint8List(600); // > 50% of 1024
      final data2 = Uint8List(600); // Will require eviction

      await cache.cachePreview(cid1, 'type', data1);

      // Wait a bit to ensure timestamp difference (fs resolution might be low)
      await Future.delayed(Duration(milliseconds: 100));

      await cache.cachePreview(cid2, 'type', data2);

      final cached1 = await cache.getPreview(cid1, 'type');
      final cached2 = await cache.getPreview(cid2, 'type');

      expect(cached1, isNull, reason: 'First entry should be evicted');
      expect(cached2, isNotNull, reason: 'Second entry should survive');
    });
  });

  group('CachedPreviewGenerator', () {
    late MockPreviewCacheManager mockCache;
    late MockFilePreviewHandler mockPreviewHandler;
    late CachedPreviewGenerator generator;

    setUp(() {
      mockCache = MockPreviewCacheManager();
      mockPreviewHandler = MockFilePreviewHandler();
      generator = CachedPreviewGenerator(mockCache, mockPreviewHandler);
    });

    test('should generate and cache new preview', () async {
      final content = utf8.encode('Long text content that needs preview');
      final block = await Block.fromData(Uint8List.fromList(content), format: 'raw');

      final preview = await generator.generatePreview(block, 'text/plain');

      expect(preview, isNotNull);
      expect(utf8.decode(preview!), equals('Long text ...'));

      // Check cache
      final cached = await mockCache.getPreview(block.cid, 'text/plain');
      expect(cached, isNotNull);
    });

    test('should return cached preview if available', () async {
      final content = utf8.encode('content');
      final block = await Block.fromData(Uint8List.fromList(content), format: 'raw');
      final cachedData = Uint8List.fromList(utf8.encode('cached preview'));

      await mockCache.cachePreview(block.cid, 'text/plain', cachedData);

      final preview = await generator.generatePreview(block, 'text/plain');

      expect(preview, equals(cachedData));
    });
  });
}
