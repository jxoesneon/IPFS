import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

    test('CompressionStats calculates compression ratio', () {
      final stats = CompressionStats();
      expect(stats.compressionRatio, equals(0));

      stats.addEntry(100, 50);
      expect(stats.compressionRatio, equals(0.5));

      stats.addEntry(200, 100);
      expect(stats.compressionRatio, equals(0.5));
    });

    test('CompressionStats handles zero original size', () {
      final stats = CompressionStats();
      stats.addEntry(0, 0);
      expect(stats.compressionRatio, equals(0));
    });

    test('getCompressionStats returns empty stats for empty directory', () {
      final emptyDir = Directory(path.join(tempDir.path, 'empty'));
      emptyDir.createSync();

      final stats = store.getCompressionStats(emptyDir.path);
      expect(stats.fileCount, equals(0));
      expect(stats.totalOriginalSize, equals(0));
    });

    test('storeCompressedData with small data uses no compression', () async {
      final data = Uint8List.fromList(utf8.encode('small'));
      await store.storeCompressedData(dummyCid, 'text/plain', data);

      final result = await store.getCompressedData(dummyCid, 'text/plain');
      expect(result, isNotNull);
      expect(utf8.decode(result!), equals('small'));
    });

    test('storeCompressedData with different content types', () async {
      final data = Uint8List.fromList(utf8.encode('test data ' * 100));

      await store.storeCompressedData(dummyCid, 'application/json', data);
      final jsonResult = await store.getCompressedData(
        dummyCid,
        'application/json',
      );
      expect(jsonResult, isNotNull);
    });

    test('getCompressedData handles corrupted metadata', () async {
      final data = Uint8List.fromList(utf8.encode('test data'));
      await store.storeCompressedData(dummyCid, 'text/plain', data);

      // Corrupt the metadata file
      final hash = sha256
          .convert(utf8.encode('${dummyCid.encode()}_text/plain'))
          .toString();
      final cacheFile = File('${tempDir.path}/$hash.cache');
      final metadataFile = File('${cacheFile.path}.meta');
      await metadataFile.writeAsString('invalid json');

      final result = await store.getCompressedData(dummyCid, 'text/plain');
      // Returns data with default compression handling
      expect(result, isNotNull);
    });

    test('getCompressionStats handles corrupted metadata files', () {
      final cacheFile = File('${tempDir.path}/test.cache');
      cacheFile.writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

      final metadataFile = File('${cacheFile.path}.meta');
      metadataFile.writeAsStringSync('invalid json');

      final stats = store.getCompressionStats(tempDir.path);
      // Handles gracefully by treating as zero sizes
      expect(stats.fileCount, equals(1));
      expect(stats.totalOriginalSize, equals(0));
    });

    test('CompressionStats handles division by zero', () {
      final stats = CompressionStats();
      stats.addEntry(0, 0);
      expect(stats.compressionRatio, equals(0));
    });

    test('getCompressedData handles missing metadata', () async {
      final data = Uint8List.fromList(utf8.encode('test data'));
      await store.storeCompressedData(dummyCid, 'text/plain', data);

      // Delete the metadata file
      final hash = sha256
          .convert(utf8.encode('${dummyCid.encode()}_text/plain'))
          .toString();
      final cacheFile = File('${tempDir.path}/$hash.cache');
      final metadataFile = File('${cacheFile.path}.meta');
      metadataFile.deleteSync();

      final result = await store.getCompressedData(dummyCid, 'text/plain');
      // Should handle gracefully with default compression type
      expect(result, isNotNull);
    });

    test('multiple stores and retrieves', () async {
      final cid1 = CID.computeForDataSync(
        Uint8List.fromList(utf8.encode('data1')),
      );
      final cid2 = CID.computeForDataSync(
        Uint8List.fromList(utf8.encode('data2')),
      );

      final data1 = Uint8List.fromList(utf8.encode('test data 1' * 50));
      final data2 = Uint8List.fromList(utf8.encode('test data 2' * 50));

      await store.storeCompressedData(cid1, 'text/plain', data1);
      await store.storeCompressedData(cid2, 'text/plain', data2);

      final result1 = await store.getCompressedData(cid1, 'text/plain');
      final result2 = await store.getCompressedData(cid2, 'text/plain');

      expect(result1, isNotNull);
      expect(result2, isNotNull);
      expect(utf8.decode(result1!), utf8.decode(data1));
      expect(utf8.decode(result2!), utf8.decode(data2));
    });

    test('storeCompressedData with empty data', () async {
      final data = Uint8List.fromList([]);
      await store.storeCompressedData(dummyCid, 'text/plain', data);

      final result = await store.getCompressedData(dummyCid, 'text/plain');
      expect(result, isNotNull);
      expect(result!.length, equals(0));
    });

    test('storeCompressedData with binary data', () async {
      final data = Uint8List.fromList(List.filled(1000, 0xFF));
      await store.storeCompressedData(
        dummyCid,
        'application/octet-stream',
        data,
      );

      final result = await store.getCompressedData(
        dummyCid,
        'application/octet-stream',
      );
      expect(result, isNotNull);
      expect(result!.length, equals(1000));
    });

    test('CompressionStats with large values', () {
      final stats = CompressionStats();
      stats.addEntry(1000000, 500000);
      expect(stats.compressionRatio, equals(0.5));
    });

    test('storeCompressedData overwrites existing data', () async {
      final data1 = Uint8List.fromList(utf8.encode('data1'));
      final data2 = Uint8List.fromList(utf8.encode('data2'));

      await store.storeCompressedData(dummyCid, 'text/plain', data1);
      await store.storeCompressedData(dummyCid, 'text/plain', data2);

      final result = await store.getCompressedData(dummyCid, 'text/plain');
      expect(result, isNotNull);
      expect(utf8.decode(result!), equals('data2'));
    });

    test('getCompressedData with same CID different content type', () async {
      final data = Uint8List.fromList(utf8.encode('test data' * 100));

      await store.storeCompressedData(dummyCid, 'text/plain', data);
      await store.storeCompressedData(dummyCid, 'application/json', data);

      final textResult = await store.getCompressedData(dummyCid, 'text/plain');
      final jsonResult = await store.getCompressedData(
        dummyCid,
        'application/json',
      );

      expect(textResult, isNotNull);
      expect(jsonResult, isNotNull);
    });
  });
}
