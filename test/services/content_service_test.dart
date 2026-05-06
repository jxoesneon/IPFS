import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/services/content_service.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/cid.dart';

import 'content_service_test.mocks.dart';

@GenerateNiceMocks([MockSpec<Datastore>()])
void main() {
  late ContentService service;
  late MockDatastore mockDatastore;

  setUp(() {
    mockDatastore = MockDatastore();
    service = ContentService(mockDatastore);
  });

  group('ContentService', () {
    test('store and get content', () async {
      final data = [1, 2, 3];
      final cid = await service.storeContent(data);
      verify(mockDatastore.put(any, any)).called(1);

      when(
        mockDatastore.get(any),
      ).thenAnswer((_) async => Uint8List.fromList(data));
      final retrieved = await service.getContent(cid);
      expect(retrieved, equals(data));
    });

    test('pin and unpin', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1]));

      // Pin fail if not exists
      when(mockDatastore.has(any)).thenAnswer((_) async => false);
      expect(await service.pinContent(cid), isFalse);

      // Pin success if exists
      when(
        mockDatastore.has(
          argThat(predicate((Key k) => k.string.contains('blocks'))),
        ),
      ).thenAnswer((_) async => true);
      expect(await service.pinContent(cid), isTrue);

      // List pins
      when(mockDatastore.query(any)).thenAnswer(
        (_) => Stream.fromIterable([
          QueryEntry(Key('/pins/${cid.encode()}'), null),
        ]),
      );
      final pins = await service.listPinnedContent();
      expect(pins, contains(cid.encode()));

      // Unpin
      expect(await service.unpinContent(cid), isTrue);
      verify(mockDatastore.delete(any)).called(1);
    });

    test('remove content blocked by pin', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1]));
      when(
        mockDatastore.has(
          argThat(predicate((Key k) => k.string.contains('pins'))),
        ),
      ).thenAnswer((_) async => true);

      expect(await service.removeContent(cid), isFalse);
    });

    test('getContentSize', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1]));
      when(mockDatastore.get(any)).thenAnswer((_) async => Uint8List(5));
      expect(await service.getContentSize(cid), equals(5));
    });

    test('hasContent', () async {
      final cid = await CID.fromContent(Uint8List.fromList([1]));
      when(mockDatastore.has(any)).thenAnswer((_) async => true);
      expect(await service.hasContent(cid), isTrue);
    });
  });
}
