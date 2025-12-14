import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/services/content_service.dart';
import 'package:dart_ipfs/src/storage/datastore.dart';

void main() {
  group('ContentService', () {
    late Directory tempDir;
    late Datastore datastore;
    late ContentService contentService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ipfs_content_test');
      datastore = Datastore(tempDir.path);
      await datastore.init();
      contentService = ContentService(datastore);
    });

    tearDown(() async {
      await datastore.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('computeHash returns correct SHA-256 multihash', () async {
      final input = Uint8List.fromList([1, 2, 3]);
      final hash = await contentService.computeHash(input);

      // Check prefix (0x12 for SHA-256, 32 for length)
      expect(hash[0], 0x12);
      expect(hash[1], 32);
      expect(hash.length, 34); // 2 prefix + 32 digest
    });

    test('storeContent stores data and returns valid CID', () async {
      final input = Uint8List.fromList([10, 20, 30, 40]);
      final cid = await contentService.storeContent(input);

      // Verify CID structure
      expect(cid.version, 1);
      expect(cid.codec, 'raw'); // Default

      // Verify data is in datastore
      final hasIt = await datastore.has(cid.encode());
      expect(hasIt, isTrue);

      // Retrieve via service
      final retrieved = await contentService.getContent(cid);
      expect(retrieved, equals(input));
    });

    test('storeContent supports custom codec', () async {
      final input = Uint8List.fromList([5, 5, 5]);
      final cid = await contentService.storeContent(input, codec: 'dag-pb');

      expect(cid.codec, 'dag-pb');

      // Verify it's stored
      expect(await datastore.has(cid.encode()), isTrue);
    });

    test('removeContent removes data', () async {
      final input = Uint8List.fromList([1, 1, 1]);
      final cid = await contentService.storeContent(input);

      expect(await contentService.hasContent(cid), isTrue);

      final removed = await contentService.removeContent(cid);
      expect(removed, isTrue);
      expect(await contentService.hasContent(cid), isFalse);
    });

    test('pinContent/unpinContent works', () async {
      final input = Uint8List.fromList([2, 2, 2]);
      final cid = await contentService.storeContent(input);

      // Pin
      final pinned = await contentService.pinContent(cid);
      expect(pinned, isTrue);
      expect(await datastore.isPinned(cid.encode()), isTrue);

      // Try to remove pinned content (should fail)
      final removed = await contentService.removeContent(cid);
      expect(removed, isFalse);

      // Unpin
      final unpinned = await contentService.unpinContent(cid);
      expect(unpinned, isTrue);
      expect(await datastore.isPinned(cid.encode()), isFalse);

      // Now remove should succeed
      expect(await contentService.removeContent(cid), isTrue);
    });
  });
}
