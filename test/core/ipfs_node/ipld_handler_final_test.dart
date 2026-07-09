import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart' as unixfs_proto;
import 'package:fixnum/fixnum.dart';
import 'package:dart_multihash/dart_multihash.dart';

import 'ipld_handler_expanded_test.mocks.dart';

void main() {
  late IPLDHandler handler;
  late MockBlockStore mockBlockStore;
  late IPFSConfig config;

  setUp(() {
    mockBlockStore = MockBlockStore();
    config = IPFSConfig();
    handler = IPLDHandler(config, mockBlockStore);
  });

  group('IPLDHandler Final Coverage', () {
    test('put/get with dag-json', () async {
      final data = {'hello': 'world', 'num': 42};
      final block = await handler.put(data, codec: 'dag-json');
      expect(block.cid.codec, equals('dag-json'));

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final retrieved = await handler.get(block.cid);
      expect(retrieved, isA<IPLDNode>());
      final node = retrieved as IPLDNode;
      expect(node.kind, equals(Kind.MAP));
    });

    test('BigInt negative values encoding/decoding', () async {
      final negBigInt = BigInt.from(-123456789);
      final block = await handler.put(negBigInt);

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final retrieved = await handler.get(block.cid) as IPLDNode;
      // It might be encoded as BYTES or BIG_INT depending on codec
      expect(retrieved.hasKind(), isTrue);
    });

    test('executeSelector with SelectorType.union', () async {
      final leaf1 = {'id': 1};
      final block1 = await handler.put(leaf1);
      final leaf2 = {'id': 2};
      final block2 = await handler.put(leaf2);

      final data = {'a': block1.cid, 'b': block2.cid};
      final block = await handler.put(data);

      when(mockBlockStore.getBlock(block.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );
      when(mockBlockStore.getBlock(block1.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block1.toProto()),
      );
      when(mockBlockStore.getBlock(block2.cid.toString())).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block2.toProto()),
      );

      final selector = IPLDSelector(
        type: SelectorType.union,
        subSelectors: [
          IPLDSelector(
            type: SelectorType.explore,
            fieldPath: 'a',
            subSelectors: [
              IPLDSelector(type: SelectorType.matcher, criteria: {'id': 1}),
            ],
          ),
          IPLDSelector(
            type: SelectorType.explore,
            fieldPath: 'b',
            subSelectors: [
              IPLDSelector(type: SelectorType.matcher, criteria: {'id': 2}),
            ],
          ),
        ],
      );

      final results = await handler.executeSelector(block.cid, selector);
      expect(results, isNotEmpty);
    });

    test('executeSelector with SelectorType.intersection', () async {
      final data = {'a': 1, 'b': 2};
      final block = await handler.put(data);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final selector = IPLDSelector(
        type: SelectorType.intersection,
        subSelectors: [
          IPLDSelector(type: SelectorType.matcher, criteria: {'a': 1}),
          IPLDSelector(type: SelectorType.matcher, criteria: {'b': 2}),
        ],
      );

      final results = await handler.executeSelector(block.cid, selector);
      expect(results, hasLength(1));
    });

    test('matchesValue with \$mod and \$elemMatch', () async {
      final data = {
        'items': [
          {'val': 10},
          {'val': 20},
        ],
        'score': 15,
      };
      final block = await handler.put(data);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final criteria = {
        'score': {
          r'$mod': [5, 0],
        },
        'items': {
          r'$elemMatch': {'val': 10},
        },
      };

      final selector = IPLDSelector(
        type: SelectorType.matcher,
        criteria: criteria,
      );
      final results = await handler.executeSelector(block.cid, selector);
      expect(results, hasLength(1));
    });

    test('matchesValue \$type exhaustive', () async {
      final data = {
        's': 'str',
        'n': 1,
        'b': true,
        'l': [1],
        'm': {'x': 1},
        'u': null,
        'c': CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
      };
      final block = await handler.put(data);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final typesMap = {
        's': 'string',
        'n': 'number',
        'b': 'boolean',
        'l': 'list',
        'm': 'map',
        'u': 'null',
        'c': 'link',
      };

      for (final entry in typesMap.entries) {
        final selector = IPLDSelector(
          type: SelectorType.matcher,
          criteria: {
            entry.key: {r'$type': entry.value},
          },
        );
        final results = await handler.executeSelector(block.cid, selector);
        expect(results, hasLength(1), reason: 'Failed for type ${entry.value}');
      }
    });

    test('resolvePath with ipld namespace', () async {
      final data = {
        'a': {
          'b': {'c': 3},
        },
      };
      final block = await handler.put(data);
      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final result = await handler.resolvePath('/ipld/${block.cid}/a/b/c');
      expect(result, isNotNull);
    });

    test('getMetadata with UnixFS mode and mtime', () async {
      final mtime = DateTime.now();
      final unixfsData = unixfs_proto.Data()
        ..type = unixfs_proto.Data_DataType.File
        ..mode = int.parse('755', radix: 8)
        ..mtime = Int64(mtime.millisecondsSinceEpoch ~/ 1000)
        ..mtimeNsecs = (mtime.millisecondsSinceEpoch % 1000) * 1000000
        ..filesize = Int64(100);

      final node = MerkleDAGNode(data: unixfsData.writeToBuffer(), links: []);
      final block = await Block.fromData(node.toBytes(), format: 'dag-pb');

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final meta = await handler.getMetadata(block.cid);
      expect(meta.properties['mode'], equals('493'));
      expect(meta.size, equals(100));
    });

    test('_tryGetCidFromMap with Bytes multihash', () async {
      final hash = Multihash.encode('sha2-256', Uint8List.fromList([1, 2, 3]));
      final data = {'/': hash.toBytes()};
      final block = await handler.put(data);

      when(mockBlockStore.getBlock(any)).thenAnswer(
        (_) async => BlockResponseFactory.successGet(block.toProto()),
      );

      final (res, cidStr) = await handler.resolveLink(block.cid, '');
      expect(cidStr, equals(block.cid.toString()));
    });
  });
}
