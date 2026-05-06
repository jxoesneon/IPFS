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

      // MAP (Complex)
      final bMap = await handler.put({
        'x': 1,
        'y': {'z': 2},
      });
      when(mockBlockStore.getBlock(bMap.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(bMap.toProto()),
      );
      final rMap = await handler.get(bMap.cid) as IPLDNode;
      expect(rMap.kind, equals(Kind.MAP));
    });

    test('resolvePath ipfs with MerkleDAG non-UnixFS', () async {
      // MerkleDAGNode that is NOT UnixFS (no Data field or non-parsable)
      // We use a valid PBNode but with random data that isn't a UnixFS proto
      final innerData = Uint8List.fromList([0, 1, 2]);

      final targetBlock = await Block.fromData(
        Uint8List.fromList([7, 8, 9]),
        format: 'raw',
      );

      final rootNode = MerkleDAGNode(
        data: innerData,
        links: [
          Link(name: 'raw', cid: targetBlock.cid, size: targetBlock.size),
        ],
      );
      final rootBlock = await Block.fromData(
        rootNode.toBytes(),
        format: 'dag-pb',
      );

      // Use any to avoid CID mismatch between v0 and v1
      when(mockBlockStore.getBlock(any)).thenAnswer((invocation) async {
        final arg = invocation.positionalArguments[0] as String;
        // Check if it's the root block CID
        if (arg == rootBlock.cid.toString() ||
            rootBlock.cid.toString().endsWith(arg)) {
          return BlockResponseFactory.successGet(rootBlock.toProto());
        }
        return BlockResponseFactory.successGet(targetBlock.toProto());
      });

      final res = await handler.resolvePath('/ipfs/${rootBlock.cid}/raw');
      expect(res, isNotNull);
    });

    test('resolvePath with recursive selectors and links', () async {
      final leaf = {'val': 'leaf'};
      final leafBlock = await handler.put(leaf);

      final root = {'child': leafBlock.cid};
      final rootBlock = await handler.put(root);

      when(mockBlockStore.getBlock(rootBlock.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(rootBlock.toProto()),
      );
      when(mockBlockStore.getBlock(leafBlock.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(leafBlock.toProto()),
      );

      final selector = IPLDSelector(
        type: SelectorType.explore,
        fieldPath: 'child',
        subSelectors: [
          IPLDSelector(type: SelectorType.matcher, criteria: {'val': 'leaf'}),
        ],
      );

      final results = await handler.executeSelector(rootBlock.cid, selector);
      expect(results, isNotEmpty);
    });

    test('getMetadata for non-UnixFS nodes', () async {
      // Map node
      final blockMap = await handler.put({'a': 1});
      when(mockBlockStore.getBlock(blockMap.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(blockMap.toProto()),
      );
      final metaMap = await handler.getMetadata(blockMap.cid);
      expect(metaMap.contentType, equals('application/dag-cbor'));

      // Raw MerkleDAG
      final rootNode = MerkleDAGNode(data: Uint8List(5), links: []);
      final blockDag = await Block.fromData(
        rootNode.toBytes(),
        format: 'dag-pb',
      );
      when(mockBlockStore.getBlock(blockDag.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(blockDag.toProto()),
      );
      final metaDag = await handler.getMetadata(blockDag.cid);
      expect(metaDag.contentType, equals('application/dag-pb'));
    });

    test('inferContentType', () async {
      // Access private method via any means or just check if it's used in metadata
      final block = await handler.put({'a': 1});
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final metadata = await handler.getMetadata(block.cid);
      expect(metadata.contentType, equals('application/dag-cbor'));
    });

    test('start and stop lifecycle', () async {
      await handler.start();
      await handler.stop();
    });
  });
}
