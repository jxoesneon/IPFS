import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/core/ipld/path/ipld_path_handler.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/errors/node_errors.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_proto;
import 'package:fixnum/fixnum.dart';

import 'ipld_handler_expanded_test.mocks.dart';

@GenerateNiceMocks([MockSpec<BlockStore>()])
void main() {
  late IPLDHandler handler;
  late MockBlockStore mockBlockStore;
  late IPFSConfig config;

  setUp(() {
    mockBlockStore = MockBlockStore();
    config = IPFSConfig();
    handler = IPLDHandler(config, mockBlockStore);
  });

  group('IPLDHandler Expanded', () {
    test('getStatus returns supported codecs', () async {
      final status = await handler.getStatus();
      expect(
        status['supported_codecs'],
        containsAll(['raw', 'dag-pb', 'dag-cbor', 'dag-json']),
      );
      expect(status['enabled'], isTrue);
    });

    test('put with BigInt handles large numbers', () async {
      final largeNum = BigInt.parse('123456789012345678901234567890');
      final block = await handler.put(largeNum);
      expect(block.cid.codec, equals('dag-cbor'));

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );
      final retrieved = await handler.get(block.cid) as IPLDNode;
      // It might be decoded as BYTES depending on codec implementation
      expect(retrieved.hasKind(), isTrue);
    });

    test('registerSchema and validation', () async {
      final schema = IPLDSchema('MyType', {
        'MyType': {'kind': 'map'},
      });
      handler.registerSchema(schema);

      await handler.put({'a': 1}, schemaType: 'MyType'); // Should pass

      expect(
        () => handler.put('not-a-map', schemaType: 'MyType'),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('resolveLink with nested map', () async {
      final nested = {
        'a': {'b': 1},
      };
      final block = await handler.put(nested);

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final (result, cid) = await handler.resolveLink(block.cid, 'a/b');
      expect(result, isA<IPLDNode>());
      expect((result as IPLDNode).kind, equals(Kind.INTEGER));
      expect(result.intValue.toInt(), equals(1));
    });

    test('executeSelector with matcher', () async {
      final data = {'val': 10, 'name': 'test'};
      final block = await handler.put(data);

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final selector = IPLDSelector(
        type: SelectorType.matcher,
        criteria: {'val': 10},
      );

      final results = await handler.executeSelector(block.cid, selector);
      expect(results, hasLength(1));
      expect(results.first.cid, equals(block.cid));
    });

    test('executeSelector with explore/recursive', () async {
      final child = {'x': 1};
      final childBlock = await handler.put(child);

      final root = {'link': childBlock.cid};
      final rootBlock = await handler.put(root);

      when(mockBlockStore.getBlock(rootBlock.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(rootBlock.toProto()),
      );
      when(mockBlockStore.getBlock(childBlock.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(childBlock.toProto()),
      );

      final selector = IPLDSelector(type: SelectorType.all);

      final results = await handler.executeSelector(rootBlock.cid, selector);
      // Should find root and recurse to child
      expect(
        results.map((r) => r.cid.toString()),
        containsAll([rootBlock.cid.toString(), childBlock.cid.toString()]),
      );
    });

    test('resolveLink with list index', () async {
      final list = [10, 20, 30];
      final block = await handler.put(list);

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final (result, cid) = await handler.resolveLink(block.cid, '1');
      expect(result, isA<IPLDNode>());
      expect((result as IPLDNode).intValue.toInt(), equals(20));
    });

    test('matchesValue advanced criteria', () async {
      final data = {
        'count': 10,
        'tags': ['a', 'b', 'c'],
        'meta': {'active': true},
        'desc': 'hello world',
      };
      final block = await handler.put(data);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final criteria = {
        'count': {r'$gt': 5, r'$lt': 15},
        'tags': {
          r'$all': ['a', 'b'],
          r'$size': 3,
        },
        'meta.active': {r'$exists': true, r'$type': 'bool'},
        'desc': {r'$regex': 'hello.*'},
      };

      final selector = IPLDSelector(
        type: SelectorType.matcher,
        criteria: criteria,
      );
      final results = await handler.executeSelector(block.cid, selector);
      expect(results, isNotEmpty);
    });

    test('unwrapIPLDNode exhaustive', () async {
      // BYTES
      final bBytes = await handler.put(
        Uint8List.fromList([1, 2, 3]),
        codec: 'raw',
      );
      when(mockBlockStore.getBlock(bBytes.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(bBytes.toProto()),
      );
      final rBytes = await handler.get(bBytes.cid) as IPLDNode;
      expect(rBytes.kind, equals(Kind.BYTES));

      // LINK
      final bLink = await handler.put(bBytes.cid);
      when(mockBlockStore.getBlock(bLink.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(bLink.toProto()),
      );
      final rLink = await handler.get(bLink.cid) as IPLDNode;
      expect(rLink.kind, equals(Kind.LINK));

      // LIST
      final bList = await handler.put([1, 2]);
      when(mockBlockStore.getBlock(bList.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(bList.toProto()),
      );
      final rList = await handler.get(bList.cid) as IPLDNode;
      expect(rList.kind, equals(Kind.LIST));
    });

    test('resolvePath with invalid namespace throws IPLDPathError', () async {
      expect(
        () => handler.resolvePath('/invalid/path'),
        throwsA(isA<IPLDPathError>()),
      );
    });

    test('resolveLink with empty path returns node', () async {
      final data = {'key': 'value'};
      final block = await handler.put(data);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );
      final (result, cid) = await handler.resolveLink(block.cid, '');
      expect(result, isNotNull);
      expect(cid, equals(block.cid.toString()));
    });

    test(
      'resolveLink with invalid segment throws IPLDResolutionError',
      () async {
        final data = {'key': 'value'};
        final block = await handler.put(data);
        when(mockBlockStore.getBlock(any)).thenAnswer(
          (_) async => BlockResponseFactory.successGet(block.toProto()),
        );
        expect(
          () => handler.resolveLink(block.cid, 'nonexistent'),
          throwsA(isA<IPLDResolutionError>()),
        );
      },
    );

    test('put when not running throws ComponentError', () async {
      await handler.stop();
      expect(() => handler.put({'data': 1}), throwsA(isA<ComponentError>()));
    });

    test('get when not running throws ComponentError', () async {
      await handler.stop();
      final cid = await CID.computeForData(Uint8List.fromList([1, 2, 3]));
      expect(() => handler.get(cid), throwsA(isA<ComponentError>()));
    });

    test('resolveLink when not running throws ComponentError', () async {
      await handler.stop();
      final cid = await CID.computeForData(Uint8List.fromList([1, 2, 3]));
      expect(
        () => handler.resolveLink(cid, 'path'),
        throwsA(isA<ComponentError>()),
      );
    });

    test('executeSelector when not running throws ComponentError', () async {
      await handler.stop();
      final cid = await CID.computeForData(Uint8List.fromList([1, 2, 3]));
      final selector = IPLDSelector(type: SelectorType.all);
      expect(
        () => handler.executeSelector(cid, selector),
        throwsA(isA<ComponentError>()),
      );
    });

    test('resolvePath when not running throws ComponentError', () async {
      await handler.stop();
      expect(
        () => handler.resolvePath('/ipfs/some-cid'),
        throwsA(isA<ComponentError>()),
      );
    });
  });
}
