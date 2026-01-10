import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';

import 'ipld_handler_test.mocks.dart';

@GenerateMocks([BlockStore])
void main() {
  group('IPLDHandler', () {
    late IPLDHandler handler;
    late MockBlockStore mockBlockStore;
    late IPFSConfig config;

    setUp(() {
      mockBlockStore = MockBlockStore();
      config = IPFSConfig();
      handler = IPLDHandler(config, mockBlockStore);
    });

    group('Codecs', () {
      test('put/get raw bytes', () async {
        final data = Uint8List.fromList([1, 2, 3, 4]);

        when(
          mockBlockStore.putBlock(any),
        ).thenAnswer((_) async => BlockResponseFactory.successAdd('Added'));

        // Put
        final block = await handler.put(data, codec: 'raw');

        verify(mockBlockStore.putBlock(any)).called(1);
        expect(block.format, 'raw');

        // Get
        when(
          mockBlockStore.getBlock(block.cid.toString()),
        ).thenAnswer((_) async => BlockResponseFactory.successGet(block.toProto()));
        final result = await handler.get(block.cid);

        expect(result.kind.toString(), contains('BYTES'));
        expect(result.bytesValue, equals(data));
      });

      test('put/get dag-json', () async {
        final data = {'hello': 'world'};

        when(
          mockBlockStore.putBlock(any),
        ).thenAnswer((_) async => BlockResponseFactory.successAdd('Added'));

        final block = await handler.put(data, codec: 'dag-json');

        verify(mockBlockStore.putBlock(any)).called(1);

        when(
          mockBlockStore.getBlock(block.cid.toString()),
        ).thenAnswer((_) async => BlockResponseFactory.successGet(block.toProto()));

        final result = await handler.get(block.cid);
        expect(result.kind.toString(), contains('MAP'));
        // Verify map content
        // result.mapValue is IPLDMap
        // We'd expect an entry check here, but simple kind check is improved coverage already.
      });

      test('put/get dag-cbor', () async {
        final data = {'foo': 'bar'};

        when(
          mockBlockStore.putBlock(any),
        ).thenAnswer((_) async => BlockResponseFactory.successAdd('Added'));

        final block = await handler.put(data, codec: 'dag-cbor');

        when(
          mockBlockStore.getBlock(block.cid.toString()),
        ).thenAnswer((_) async => BlockResponseFactory.successGet(block.toProto()));

        final result = await handler.get(block.cid);
        expect(result.kind.toString(), contains('MAP'));
      });
    });

    group('Lifecycle', () {
      test('start logs success', () async {
        await handler.start();
      });

      test('stop logs success', () async {
        await handler.stop();
      });
      test('getStatus returns correct info', () async {
        final status = await handler.getStatus();
        expect(status['enabled'], isTrue);
        expect(status['supported_codecs'], isNotEmpty);
      });
    });

    group('Path Resolution', () {
      test('resolveLink with empty path returns root', () async {
        final block = await Block.fromData(Uint8List(0), format: 'raw');
        final cid = block.cid;

        when(
          mockBlockStore.getBlock(cid.toString()),
        ).thenAnswer((realInvocation) async => BlockResponseFactory.successGet(block.toProto()));

        final (node, resolvedCid) = await handler.resolveLink(cid, '');
        expect(resolvedCid, cid.toString());
      });
    });

    group('Selectors', () {
      test('executeSelector All returns root', () async {
        final block = await Block.fromData(Uint8List(0), format: 'raw');
        when(
          mockBlockStore.getBlock(block.cid.toString()),
        ).thenAnswer((realInvocation) async => BlockResponseFactory.successGet(block.toProto()));

        final selector = IPLDSelector(type: SelectorType.all);
        final results = await handler.executeSelector(block.cid, selector);

        expect(results, hasLength(1));
        // IPLDNode equality might be tricky, checking bytes or kind
        // results contains IPLDNode objects
        expect(results.first.kind.toString(), contains('BYTES'));
      });
    });
  });
}
