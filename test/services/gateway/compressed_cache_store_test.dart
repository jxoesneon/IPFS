import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/services/gateway/compressed_cache_store.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('CompressedCacheStore', () {
    late Directory tempDir;
    late CompressedCacheStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ipfs_cache_test_');
      store = CompressedCacheStore(cachePath: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    final dummyCid = CID.computeForDataSync(
      Uint8List.fromList(utf8.encode('dummy')),
    );

    test('storeCompressedData stores data and metadata', () async {
      final data = Uint8List.fromList(utf8.encode('test data'));
      await store.storeCompressedData(dummyCid, 'text/plain', data);

      final stats = store.getCompressionStats(tempDir.path);
      expect(stats.fileCount, 1);
      expect(stats.totalOriginalSize, data.length);
    });

    test('getCompressedData retrieves and decompresses data', () async {
      final data = Uint8List.fromList(
        utf8.encode('test data ' * 100),
      ); // Ensure compressible
      await store.storeCompressedData(dummyCid, 'text/plain', data);

      final result = await store.getCompressedData(dummyCid, 'text/plain');
      expect(result, isNotNull);
      expect(utf8.decode(result!), utf8.decode(data));
    });

    test('getCompressedData returns null for missing file', () async {
      final result = await store.getCompressedData(dummyCid, 'image/png');
      expect(result, isNull);
    });

    test('initialization creates directory if missing', () {
      final newDir = Directory(path.join(tempDir.path, 'new_cache'));
      expect(newDir.existsSync(), isFalse);

      CompressedCacheStore(cachePath: newDir.path);
      expect(newDir.existsSync(), isTrue);
    });
  });
}
