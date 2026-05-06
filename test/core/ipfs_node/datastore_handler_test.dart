import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/datastore_handler.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_proto;
import 'package:dart_ipfs/src/core/data_structures/car.dart';
import 'package:dart_ipfs/src/utils/car_writer.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';

import 'datastore_handler_test.mocks.dart';

@GenerateNiceMocks([MockSpec<Datastore>()])
void main() {
  late DatastoreHandler handler;
  late MockDatastore mockDatastore;

  setUp(() {
    mockDatastore = MockDatastore();
    handler = DatastoreHandler(mockDatastore);
  });

  group('DatastoreHandler', () {
    test('start and stop lifecycle', () async {
      await handler.start();
      verify(mockDatastore.init()).called(1);

      await handler.stop();
      verify(mockDatastore.close()).called(1);
    });

    test('start rethrows error', () async {
      when(mockDatastore.init()).thenThrow(Exception('Init error'));
      expect(() => handler.start(), throwsStateError);
    });

    test('stop catches error', () async {
      when(mockDatastore.close()).thenThrow(Exception('Close error'));
      await handler.stop(); // Should not throw
    });

    test('putBlock and getBlock', () async {
      final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
      final cid = CID.decode(cidStr);
      final block = Block(cid: cid, data: Uint8List.fromList([1, 2, 3]));

      await handler.putBlock(block);
      verify(mockDatastore.put(any, any)).called(1);

      when(
        mockDatastore.get(any),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      final retrieved = await handler.getBlock(cidStr);
      expect(retrieved, isNotNull);
      expect(retrieved!.data, equals(block.data));
    });

    test('getBlock returns null when not found or error', () async {
      when(mockDatastore.get(any)).thenAnswer((_) async => null);
      expect(await handler.getBlock('invalid'), isNull);

      when(mockDatastore.get(any)).thenThrow(Exception('Get error'));
      expect(await handler.getBlock('invalid'), isNull);
    });

    test('hasBlock and errors', () async {
      when(mockDatastore.has(any)).thenAnswer((_) async => true);
      expect(await handler.hasBlock('cid'), isTrue);

      when(mockDatastore.has(any)).thenThrow(Exception('Has error'));
      expect(await handler.hasBlock('cid'), isFalse);
    });

    test('loadPinnedCIDs', () async {
      final entries = [
        QueryEntry(Key('/pins/cid1'), Uint8List(0)),
        QueryEntry(Key('/pins/cid2'), Uint8List(0)),
      ];
      when(
        mockDatastore.query(any),
      ).thenAnswer((_) => Stream.fromIterable(entries));

      final pins = await handler.loadPinnedCIDs();
      expect(pins, containsAll(['cid1', 'cid2']));
    });

    test('persistPinnedCIDs', () async {
      // Clear existing
      final entries = [QueryEntry(Key('/pins/old'), Uint8List(0))];
      when(
        mockDatastore.query(any),
      ).thenAnswer((_) => Stream.fromIterable(entries));

      await handler.persistPinnedCIDs({'new1', 'new2'});

      verify(mockDatastore.delete(any)).called(1);
      verify(mockDatastore.put(any, any)).called(2);
    });

    test('getStatus', () async {
      when(mockDatastore.query(any)).thenAnswer((_) => Stream.empty());
      final status = await handler.getStatus();
      expect(status['status'], equals('active'));
      expect(status['pinned_blocks'], equals(0));
    });

    test('exportCAR errors when root missing', () async {
      when(mockDatastore.get(any)).thenAnswer((_) async => null);
      final car = await handler.exportCAR('missing');
      expect(car, isEmpty);
    });

    test('exportCAR with links', () async {
      final rootCidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';

      final unixfsDir = unixfs_proto.Data()
        ..type = unixfs_proto.Data_DataType.Directory;
      final rootNode = MerkleDAGNode(
        data: unixfsDir.writeToBuffer(),
        links: [],
      );

      final rootBlockData = rootNode.toBytes();

      // Mock getBlock for root
      when(
        mockDatastore.get(Key('/blocks/$rootCidStr')),
      ).thenAnswer((_) async => rootBlockData);

      final carData = await handler.exportCAR(rootCidStr);
      expect(carData, isNotEmpty);
    });

    test('importCAR calls putBlock', () async {
      // We need a minimal CAR file. Since we don't have a builder here easily,
      // we can mock CarReader if we want, but importCAR calls CarReader.readCar(carFile).
      // CarReader.readCar is static.
      // Instead, we can use a real CarWriter to create a CAR.
      final block = Block(
        cid: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        data: Uint8List.fromList([1, 2, 3]),
      );
      final car = CAR(
        blocks: [block],
        header: CarHeader(version: 1, roots: [block.cid]),
      );
      final carData = await CarWriter.writeCar(car);

      await handler.importCAR(carData);
      verify(mockDatastore.put(any, any)).called(1);
    });
  });
}
