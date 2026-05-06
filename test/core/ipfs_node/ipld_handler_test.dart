import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

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

      when(
        mockBlockStore.putBlock(any),
      ).thenAnswer((_) async => BlockResponseFactory.successAdd('Added'));
    });

    group('Basic Operations', () {
      test('put and get dag-cbor', () async {
        final data = {'name': 'test', 'value': 123};
        final block = await handler.put(data, codec: 'dag-cbor');

        expect(block.format, equals('dag-cbor'));

        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final retrieved = await handler.get(block.cid);
        expect(retrieved, isA<IPLDNode>());
        final node = retrieved as IPLDNode;
        expect(node.kind, equals(Kind.MAP));
      });

      test('put and get raw', () async {
        final data = Uint8List.fromList([1, 2, 3]);
        final block = await handler.put(data, codec: 'raw');

        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final retrieved = await handler.get(block.cid);
        expect(retrieved, isA<IPLDNode>());
        expect((retrieved as IPLDNode).bytesValue, equals(data));
      });

      test('put and get dag-json', () async {
        final data = {'name': 'test'};
        final block = await handler.put(data, codec: 'dag-json');

        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final retrieved = await handler.get(block.cid);
        expect(retrieved, isA<IPLDNode>());
      });
    });

    group('Path Resolution', () {
      test('resolveLink through nested maps', () async {
        final leaf = {'leaf': true};
        final leafBlock = await handler.put(leaf);

        final middle = {'child': leafBlock.cid};
        final middleBlock = await handler.put(middle);

        final root = {'nested': middleBlock.cid};
        final rootBlock = await handler.put(root);

        when(mockBlockStore.getBlock(rootBlock.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(rootBlock.toProto()),
        );
        when(mockBlockStore.getBlock(middleBlock.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(middleBlock.toProto()),
        );
        when(mockBlockStore.getBlock(leafBlock.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(leafBlock.toProto()),
        );

        final (result, lastCid) = await handler.resolveLink(
          rootBlock.cid,
          'nested/child',
        );
        expect(result, isA<IPLDNode>());
        expect((result as IPLDNode).kind, equals(Kind.MAP));
        expect(lastCid, equals(leafBlock.cid.toString()));
      });

      test('resolvePath with ipfs namespace', () async {
        final data = {'hello': 'world'};
        final block = await handler.put(data);

        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final result = await handler.resolvePath('/ipfs/${block.cid}/hello');
        expect(result, isA<IPLDNode>());
        expect((result as IPLDNode).stringValue, equals('world'));
      });
    });

    group('Selectors', () {
      test('executeSelector with \$gt operator', () async {
        final data = {'age': 30};
        final block = await handler.put(data);
        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final selector = IPLDSelector(
          type: SelectorType.matcher,
          criteria: {
            'age': {'\$gt': 25},
          },
        );

        final results = await handler.executeSelector(block.cid, selector);
        expect(results, hasLength(1));
      });

      test('executeSelector with \$lt operator', () async {
        final data = {'age': 20};
        final block = await handler.put(data);
        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final selector = IPLDSelector(
          type: SelectorType.matcher,
          criteria: {
            'age': {'\$lt': 25},
          },
        );

        final results = await handler.executeSelector(block.cid, selector);
        expect(results, hasLength(1));
      });

      test('executeSelector with \$regex operator', () async {
        final data = {'name': 'alice'};
        final block = await handler.put(data);
        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final selector = IPLDSelector(
          type: SelectorType.matcher,
          criteria: {
            'name': {'\$regex': '^ali'},
          },
        );

        final results = await handler.executeSelector(block.cid, selector);
        expect(results, hasLength(1));
      });
    });

    group('Error Handling', () {
      test('get non-existent block throws', () async {
        final cid = await CID.computeForData(Uint8List(0));
        when(
          mockBlockStore.getBlock(cid.toString()),
        ).thenThrow(Exception('Not found'));

        expect(() => handler.get(cid), throwsException);
      });

      test('put with unsupported codec throws', () async {
        expect(
          () => handler.put({'a': 1}, codec: 'invalid'),
          throwsUnsupportedError,
        );
      });

      test('resolveLink with invalid path segment throws', () async {
        final data = {'a': 1};
        final block = await handler.put(data);
        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        expect(
          () => handler.resolveLink(block.cid, 'nonexistent'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Link Traversal', () {
      test('_tryGetCidFromMap handles string CID link', () async {
        final linkedData = Uint8List.fromList([1, 2, 3]);
        final linkedBlock = await Block.fromData(linkedData, format: 'raw');
        final cidString = linkedBlock.cid.toString();

        final data = {
          'link': {'/': cidString},
        };
        final block = await handler.put(data);

        when(mockBlockStore.getBlock(any)).thenAnswer(
          (_) async => BlockResponseFactory.successGet(linkedBlock.toProto()),
        );
        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final (result, lastCid) = await handler.resolveLink(block.cid, 'link');
        expect(lastCid, isNotNull);
        expect(lastCid, equals(cidString));
      });

      test('_tryGetCidFromMap handles bytes CID link', () async {
        final cid = await CID.computeForData(Uint8List.fromList([1, 2, 3]));
        final data = {
          'link': {'/': cid.toBytes()},
        };
        final block = await handler.put(data);

        final linkedData = Uint8List.fromList([1, 2, 3]);
        final linkedBlock = await Block.fromData(linkedData, format: 'raw');

        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );
        when(mockBlockStore.getBlock(cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(linkedBlock.toProto()),
        );

        final (result, lastCid) = await handler.resolveLink(block.cid, 'link');
        expect(lastCid, equals(cid.toString()));
      });

      test('resolveLink through nested lists and maps', () async {
        final cid1 = await CID.computeForData(Uint8List.fromList([1]));
        final data = {
          'list': [
            {'child': cid1},
          ],
        };
        final block = await handler.put(data);

        final linkedData = Uint8List.fromList([1]);
        final linkedBlock = await Block.fromData(linkedData, format: 'raw');

        when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );
        when(mockBlockStore.getBlock(cid1.toString())).thenAnswer(
          (_) async => BlockResponseFactory.successGet(linkedBlock.toProto()),
        );

        final (result, lastCid) = await handler.resolveLink(
          block.cid,
          'list/0/child',
        );
        expect(lastCid, equals(cid1.toString()));
      });
    });

    group('Selectors Expanded', () {
      test('executeSelector with \$exists operator', () async {
        final data = {'name': 'bob', 'age': 30};
        final block = await handler.put(data);
        when(mockBlockStore.getBlock(any)).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final selector = IPLDSelector(
          type: SelectorType.matcher,
          criteria: {
            'name': {'\$exists': true},
            'missing': {'\$exists': false},
          },
        );

        final results = await handler.executeSelector(block.cid, selector);
        expect(results, isNotEmpty);
      });

      test('executeSelector with nested path criteria', () async {
        final data = {
          'user': {
            'profile': {'active': true},
          },
        };
        final block = await handler.put(data);
        when(mockBlockStore.getBlock(any)).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );

        final selector = IPLDSelector(
          type: SelectorType.matcher,
          criteria: {'user.profile.active': true},
        );

        final results = await handler.executeSelector(block.cid, selector);
        expect(results, isNotEmpty);
      });
    });
  });
}
