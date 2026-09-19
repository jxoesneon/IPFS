import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/web_block_store.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;

import 'web_block_store_test.mocks.dart';

@GenerateNiceMocks([MockSpec<IpfsPlatform>()])
void main() {
  late WebBlockStore store;
  late MockIpfsPlatform mockPlatform;
  final cidStr = 'QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn';
  final data = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    mockPlatform = MockIpfsPlatform();
    store = WebBlockStore(mockPlatform);
  });

  group('WebBlockStore', () {
    test('start and stop', () async {
      await store.start();
      await store.stop();
    });

    test('putBlock success', () async {
      final cid = CID.decode(cidStr);
      final block = Block(cid: cid, data: data);

      final result = await store.putBlock(block);
      expect(result.success, isTrue);
      verify(mockPlatform.writeBytes('blocks/$cidStr', data)).called(1);
    });

    test('getBlock success', () async {
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => data);

      final result = await store.getBlock(cidStr);
      expect(result.found, isTrue);
      expect(result.block.data, equals(data));
    });

    test('getBlock not found', () async {
      when(mockPlatform.readBytes(any)).thenAnswer((_) async => null);

      final result = await store.getBlock('unknown');
      expect(result.found, isFalse);
    });

    test('removeBlock', () async {
      final result = await store.removeBlock(cidStr);
      expect(result.success, isTrue);
      verify(mockPlatform.delete('blocks/$cidStr')).called(1);
    });

    test('hasBlock', () async {
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => data);
      expect(await store.hasBlock(cidStr), isTrue);

      when(
        mockPlatform.readBytes('blocks/missing'),
      ).thenAnswer((_) async => null);
      expect(await store.hasBlock('missing'), isFalse);
    });

    test('getAllBlocks', () async {
      when(
        mockPlatform.listDirectory('blocks'),
      ).thenAnswer((_) async => ['blocks/$cidStr']);
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => data);

      final blocks = await store.getAllBlocks();
      expect(blocks.length, equals(1));
      expect(blocks.first.cid.encode(), equals(cidStr));
    });

    test('getStatus returns block count and size', () async {
      when(
        mockPlatform.listDirectory('blocks'),
      ).thenAnswer((_) async => ['blocks/$cidStr']);
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => data);

      final status = await store.getStatus();
      expect(status['total_blocks'], equals(1));
      expect(status['total_size'], equals(3));
    });

    test('getStatus reports pinned block count', () async {
      when(
        mockPlatform.listDirectory('blocks'),
      ).thenAnswer((_) async => ['blocks/$cidStr']);
      when(
        mockPlatform.listDirectory('pins'),
      ).thenAnswer((_) async => ['pins/$cidStr']);
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => data);

      final status = await store.getStatus();
      expect(status['total_blocks'], equals(1));
      expect(status['pinned_blocks'], equals(1));
    });

    test('getStatus returns empty when error occurs', () async {
      when(mockPlatform.listDirectory(any)).thenThrow(Exception('Error'));

      final status = await store.getStatus();
      expect(status['total_blocks'], equals(0));
      expect(status['total_size'], equals(0));
    });

    test('gc removes unpinned blocks and keeps pinned ones', () async {
      final orphanCid = (await CID.fromContent(
        Uint8List.fromList([9, 9, 9]),
      )).encode();

      when(
        mockPlatform.listDirectory('pins'),
      ).thenAnswer((_) async => ['pins/$cidStr']);
      when(
        mockPlatform.listDirectory('blocks'),
      ).thenAnswer((_) async => ['blocks/$cidStr', 'blocks/$orphanCid']);
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => data);

      final removed = await store.gc();

      expect(removed, equals(1));
      verify(mockPlatform.delete('blocks/$orphanCid')).called(1);
      verifyNever(mockPlatform.delete('blocks/$cidStr'));
    });

    test('gc retains dag-pb children of pinned roots', () async {
      final childCid = await CID.fromContent(Uint8List.fromList([7, 7]));
      final childCidStr = childCid.encode();
      final orphanCid = (await CID.fromContent(
        Uint8List.fromList([8, 8]),
      )).encode();

      final pbNode = dag_pb.PBNode()
        ..links.add(
          dag_pb.PBLink(
            hash: childCid.toBytes(),
            name: 'child',
            size: Int64(2),
          ),
        );

      when(
        mockPlatform.listDirectory('pins'),
      ).thenAnswer((_) async => ['pins/$cidStr']);
      when(mockPlatform.listDirectory('blocks')).thenAnswer(
        (_) async => [
          'blocks/$cidStr',
          'blocks/$childCidStr',
          'blocks/$orphanCid',
        ],
      );
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => pbNode.writeToBuffer());
      when(
        mockPlatform.readBytes('blocks/$childCidStr'),
      ).thenAnswer((_) async => Uint8List.fromList([7, 7]));

      final removed = await store.gc();

      expect(removed, equals(1));
      verifyNever(mockPlatform.delete('blocks/$cidStr'));
      verifyNever(mockPlatform.delete('blocks/$childCidStr'));
      verify(mockPlatform.delete('blocks/$orphanCid')).called(1);
    });

    test('gc removes everything when no pins exist', () async {
      when(
        mockPlatform.listDirectory('pins'),
      ).thenAnswer((_) async => <String>[]);
      when(
        mockPlatform.listDirectory('blocks'),
      ).thenAnswer((_) async => ['blocks/$cidStr']);

      final removed = await store.gc();

      expect(removed, equals(1));
      verify(mockPlatform.delete('blocks/$cidStr')).called(1);
    });

    test('putBlock handles errors', () async {
      when(
        mockPlatform.writeBytes(any, any),
      ).thenThrow(Exception('Write failed'));

      final cid = CID.decode(cidStr);
      final block = Block(cid: cid, data: data);

      final result = await store.putBlock(block);
      expect(result.success, isFalse);
    });

    test('removeBlock handles errors', () async {
      when(mockPlatform.delete(any)).thenThrow(Exception('Delete failed'));

      final result = await store.removeBlock(cidStr);
      expect(result.success, isFalse);
    });

    test('getAllBlocks handles errors', () async {
      when(mockPlatform.listDirectory(any)).thenThrow(Exception('List failed'));

      final blocks = await store.getAllBlocks();
      expect(blocks, isEmpty);
    });

    test('getAllBlocks skips invalid CIDs', () async {
      when(
        mockPlatform.listDirectory('blocks'),
      ).thenAnswer((_) async => ['blocks/invalid-cid', 'blocks/$cidStr']);
      when(
        mockPlatform.readBytes('blocks/invalid-cid'),
      ).thenAnswer((_) async => data);
      when(
        mockPlatform.readBytes('blocks/$cidStr'),
      ).thenAnswer((_) async => data);

      final blocks = await store.getAllBlocks();
      expect(blocks.length, equals(1));
      expect(blocks.first.cid.encode(), equals(cidStr));
    });
  });
}
