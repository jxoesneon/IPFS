import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/services/content_service.dart';
import 'package:test/test.dart';

import '../mocks/in_memory_datastore.dart';

void main() {
  group('ContentService', () {
    late InMemoryDatastore datastore;
    late ContentService contentService;

    setUp(() async {
      datastore = InMemoryDatastore();
      await datastore.init();
      contentService = ContentService(datastore);
    });

    tearDown(() async {
      await datastore.close();
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

      // Verify data is in datastore via key
      final key = Key('/blocks/${cid.encode()}');
      final hasIt = await datastore.has(key);
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
      final key = Key('/blocks/${cid.encode()}');
      expect(await datastore.has(key), isTrue);
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

      // Verify pin key exists
      final pinKey = Key('/pins/${cid.encode()}');
      expect(await datastore.has(pinKey), isTrue);

      // Try to remove pinned content (should fail)
      final removed = await contentService.removeContent(cid);
      expect(removed, isFalse);

      // Unpin
      final unpinned = await contentService.unpinContent(cid);
      expect(unpinned, isTrue);
      expect(await datastore.has(pinKey), isFalse);

      // Now remove should succeed
      expect(await contentService.removeContent(cid), isTrue);
    });

    test('listPinnedContent returns pinned CIDs', () async {
      final input1 = Uint8List.fromList([1]);
      final input2 = Uint8List.fromList([2]);
      final cid1 = await contentService.storeContent(input1);
      final cid2 = await contentService.storeContent(input2);

      await contentService.pinContent(cid1);
      await contentService.pinContent(cid2);

      final pinned = await contentService.listPinnedContent();
      expect(pinned.length, equals(2));
      expect(pinned.contains(cid1.encode()), isTrue);
      expect(pinned.contains(cid2.encode()), isTrue);
    });
  });
}
