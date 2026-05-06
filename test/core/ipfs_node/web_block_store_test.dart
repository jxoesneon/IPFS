import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/web_block_store.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';

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
  });
}
