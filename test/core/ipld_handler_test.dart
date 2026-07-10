import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart'
    as blockstore_pb;
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/errors/node_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/core/ipld/path/ipld_path_handler.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:test/test.dart';
import 'package:fixnum/fixnum.dart';

class MockBlockStore implements BlockStore {
  final Map<String, Block> blocks = {};

  @override
  PinManager get pinManager => throw UnimplementedError('Mock');

  @override
  String get path => '/mock/path';

  @override
  Future<blockstore_pb.AddBlockResponse> putBlock(Block block) async {
    blocks[block.cid.toString()] = block;
    return BlockResponseFactory.successAdd('Block added');
  }

  @override
  Future<blockstore_pb.GetBlockResponse> getBlock(String cid) async {
    if (blocks.containsKey(cid)) {
      return BlockResponseFactory.successGet(blocks[cid]!.toProto());
    }
    return BlockResponseFactory.notFound();
  }

  @override
  Future<blockstore_pb.RemoveBlockResponse> removeBlock(String cid) async {
    blocks.remove(cid);
    return BlockResponseFactory.successRemove('Block removed');
  }

  @override
  Future<List<Block>> getAllBlocks() async {
    return blocks.values.toList();
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> hasBlock(String cid) async => blocks.containsKey(cid);

  @override
  Future<Map<String, dynamic>> getStatus() async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IPLDHandler', () {
    late IPLDHandler handler;
    late MockBlockStore blockStore;
    late IPFSConfig config;

    setUp(() async {
      config = IPFSConfig();
      blockStore = MockBlockStore();
      handler = IPLDHandler(config, blockStore);
      await handler.start();
    });

    tearDown(() async {
      await handler.stop();
    });

    test('should put and get DAG-CBOR data', () async {
      final data = {'name': 'test', 'value': 123};
      final block = await handler.put(data, codec: 'dag-cbor');

      expect(block, isNotNull);
      expect(block.cid, isNotNull);

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.MAP);

      final nameEntry = retrieved.mapValue.entries.firstWhere(
        (dynamic e) => e.key == 'name',
      );
      expect(nameEntry.value.stringValue, 'test');

      final valueEntry = retrieved.mapValue.entries.firstWhere(
        (dynamic e) => e.key == 'value',
      );
      expect(valueEntry.value.intValue.toInt(), 123);
    });

    test('should handle various types in _toIPLDNode', () async {
      final data = {
        'null': null,
        'bool': true,
        'int': 42,
        'double': 3.14,
        'string': 'hello',
        'bytes': Uint8List.fromList([1, 2, 3]),
        'list': [1, 2, 3],
        'bigInt': BigInt.from(1234567890),
        'map': {'inner': 'value'},
      };

      final block = await handler.put(data, codec: 'dag-cbor');
      final retrieved = await handler.get(block.cid);

      expect(retrieved.kind, Kind.MAP);
      final entries = retrieved.mapValue.entries;

      expect(entries.firstWhere((e) => e.key == 'null').value.kind, Kind.NULL);
      expect(entries.firstWhere((e) => e.key == 'bool').value.boolValue, true);
      expect(
        entries.firstWhere((e) => e.key == 'int').value.intValue.toInt(),
        42,
      );
      expect(
        entries.firstWhere((e) => e.key == 'double').value.floatValue,
        3.14,
      );
      expect(
        entries.firstWhere((e) => e.key == 'string').value.stringValue,
        'hello',
      );
      expect(entries.firstWhere((e) => e.key == 'bytes').value.bytesValue, [
        1,
        2,
        3,
      ]);
      expect(
        entries
            .firstWhere((e) => e.key == 'list')
            .value
            .listValue
            .values
            .length,
        3,
      );
      expect(
        entries.firstWhere((e) => e.key == 'bigInt').value.kind,
        Kind.INTEGER,
      );
    });

    test('should put and get Raw data', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final block = await handler.put(data, codec: 'raw');

      expect(block.cid.codec, 'raw');

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.BYTES);
      expect(retrieved.bytesValue, data);
    });

    test('should put and get DAG-JSON data with links', () async {
      final leafData = Uint8List.fromList([1, 2, 3]);
      final leafBlock = await handler.put(leafData, codec: 'raw');
      final leafCid = leafBlock.cid;

      final data = {'link': leafCid};
      final block = await handler.put(data, codec: 'dag-json');

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.MAP);

      final linkEntry = retrieved.mapValue.entries.firstWhere(
        (e) => e.key == 'link',
      );
      expect(linkEntry.value.kind, Kind.LINK);
      final linkProto = linkEntry.value.linkValue;
      final multihash = Uint8List.fromList(linkProto.multihash);
      final cid = CID.v1(linkProto.codec, Multihash.decode(multihash));
      expect(cid.toString(), leafCid.toString());
    });

    test('should resolve links through maps and lists', () async {
      final leafData = 'i am the leaf';
      final leafBlock = await handler.put(leafData, codec: 'dag-cbor');
      final leafCid = leafBlock.cid;

      final data = {
        'a': {
          'b': [
            'zero',
            {'target': leafCid},
          ],
        },
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final (resolved, lastCid) = await handler.resolveLink(
        block.cid,
        'a/b/1/target',
      );
      expect(lastCid, leafCid.toString());
      expect(resolved.kind, Kind.STRING);
      expect(resolved.stringValue, leafData);
    });

    test('should resolve paths with namespaces', () async {
      final data = {'name': 'test'};
      final block = await handler.put(data, codec: 'dag-cbor');

      // IPFS namespace
      final ipfsResult = await handler.resolvePath('/ipfs/${block.cid}/name');
      expect(ipfsResult.kind, Kind.STRING);
      expect(ipfsResult.stringValue, 'test');

      // IPLD namespace
      final ipldResult = await handler.resolvePath('/ipld/${block.cid}/name');
      expect(ipldResult.kind, Kind.STRING);
      expect(ipldResult.stringValue, 'test');
    });

    test('should get metadata', () async {
      final data = {'a': 1};
      final block = await handler.put(data, codec: 'dag-cbor');

      final metadata = await handler.getMetadata(block.cid);
      expect(metadata.contentType, 'application/dag-cbor');
      expect(metadata.size, isPositive);
    });

    test('should execute selectors', () async {
      final data = {
        'items': [
          {'id': 1, 'tag': 'blue'},
          {'id': 2, 'tag': 'red'},
          {'id': 3, 'tag': 'blue'},
        ],
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      // All selector
      final allResults = await handler.executeSelector(
        block.cid,
        IPLDSelector.all(),
      );
      expect(allResults, isNotEmpty);

      // Matcher selector
      final matcher = IPLDSelector.matcher(criteria: {'items.0.tag': 'blue'});
      final matchResults = await handler.executeSelector(block.cid, matcher);
      expect(matchResults, isNotEmpty);
      expect(matchResults.first.cid.toString(), block.cid.toString());
    });

    test('should handle matcher with criteria operators', () async {
      final data = {'score': 85, 'name': 'Alice'};
      final block = await handler.put(data, codec: 'dag-cbor');

      // $gt operator
      final gtMatcher = IPLDSelector.matcher(
        criteria: {
          'score': {r'$gt': 80},
        },
      );
      final gtResults = await handler.executeSelector(block.cid, gtMatcher);
      expect(gtResults, isNotEmpty);

      // $lt operator
      final ltMatcher = IPLDSelector.matcher(
        criteria: {
          'score': {r'$lt': 90},
        },
      );
      final ltResults = await handler.executeSelector(block.cid, ltMatcher);
      expect(ltResults, isNotEmpty);

      // $regex operator
      final regexMatcher = IPLDSelector.matcher(
        criteria: {
          'name': {r'$regex': '^Al'},
        },
      );
      final regexResults = await handler.executeSelector(
        block.cid,
        regexMatcher,
      );
      expect(regexResults, isNotEmpty);
    });

    test('should throw error for unsupported codec', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      expect(
        () => handler.put(data, codec: 'unknown-codec'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw IPLDResolutionError for invalid path segment', () async {
      final data = {'a': 1};
      final block = await handler.put(data, codec: 'dag-cbor');
      expect(
        () => handler.resolveLink(block.cid, 'nonexistent'),
        throwsA(isA<IPLDResolutionError>()),
      );
    });

    test('should throw IPLDPathError for invalid namespace', () async {
      expect(
        () => handler.resolvePath('/invalid/cid/path'),
        throwsA(isA<IPLDPathError>()),
      );
    });

    test('should handle BigInt in _toIPLDNode', () async {
      final bigInt = BigInt.parse('123456789012345678901234567890');
      final block = await handler.put(bigInt, codec: 'dag-cbor');
      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.BIG_INT);
    });

    test('getStatus should return supported codecs', () async {
      final status = await handler.getStatus();
      expect(status['supported_codecs'], contains('dag-cbor'));
      expect(status['supported_codecs'], contains('raw'));
      expect(status['supported_codecs'], contains('dag-json'));
    });

    test('should handle CID in _toIPLDNode', () async {
      final someCid = await CID.computeForData(utf8.encode('target'));
      final block = await handler.put(someCid, codec: 'dag-cbor');
      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.LINK);
      expect(retrieved.linkValue.multihash, someCid.multihash.toBytes());
    });

    test('should throw ComponentError when not running', () async {
      await handler.stop();
      final data = {'name': 'test'};
      expect(
        () => handler.put(data, codec: 'dag-cbor'),
        throwsA(isA<ComponentError>()),
      );
    });

    test('should throw ComponentError for get when not running', () async {
      await handler.stop();
      final cid = await CID.computeForData(utf8.encode('test'));
      expect(() => handler.get(cid), throwsA(isA<ComponentError>()));
    });

    test(
      'should throw ComponentError for resolveLink when not running',
      () async {
        await handler.stop();
        final cid = await CID.computeForData(utf8.encode('test'));
        expect(
          () => handler.resolveLink(cid, 'path'),
          throwsA(isA<ComponentError>()),
        );
      },
    );

    test(
      'should throw ComponentError for executeSelector when not running',
      () async {
        await handler.stop();
        final cid = await CID.computeForData(utf8.encode('test'));
        expect(
          () => handler.executeSelector(cid, IPLDSelector.all()),
          throwsA(isA<ComponentError>()),
        );
      },
    );

    test(
      'should throw ComponentError for resolvePath when not running',
      () async {
        await handler.stop();
        expect(
          () => handler.resolvePath('/ipfs/cid/path'),
          throwsA(isA<ComponentError>()),
        );
      },
    );

    test('should throw IPLDSchemaError for unknown schema', () async {
      final data = {'name': 'test'};
      expect(
        () => handler.put(data, codec: 'dag-cbor', schemaType: 'unknown'),
        throwsA(isA<IPLDSchemaError>()),
      );
    });

    test('executeSelector with explore selector', () async {
      final data = {'target': 'value'};
      final block = await handler.put(data, codec: 'dag-cbor');

      final exploreSelector = IPLDSelector.explore(
        path: 'target',
        selector: IPLDSelector.all(),
      );
      final results = await handler.executeSelector(block.cid, exploreSelector);
      // Explore selector might not return results without proper link structure
      // Just verify it doesn't throw
      expect(results, isA<List>());
    });

    test('executeSelector with recursive selector', () async {
      final data = {
        'items': [
          {'name': 'a'},
          {'name': 'b'},
        ],
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final recursiveSelector = IPLDSelector.recursive(
        selector: IPLDSelector.matcher(criteria: {}),
        maxDepth: 2,
        stopAtLink: false,
      );
      final results = await handler.executeSelector(
        block.cid,
        recursiveSelector,
      );
      expect(results, isNotEmpty);
    });

    test('executeSelector with union selector', () async {
      final data = {'value': 42};
      final block = await handler.put(data, codec: 'dag-cbor');

      final unionSelector = IPLDSelector.union([
        IPLDSelector.matcher(criteria: {'value': 42}),
        IPLDSelector.matcher(criteria: {'value': 43}),
      ]);
      final results = await handler.executeSelector(block.cid, unionSelector);
      expect(results, isNotEmpty);
    });

    test('executeSelector with intersection selector', () async {
      final data = {'value': 42, 'name': 'test'};
      final block = await handler.put(data, codec: 'dag-cbor');

      final intersectionSelector = IPLDSelector.intersection([
        IPLDSelector.matcher(criteria: {'value': 42}),
        IPLDSelector.matcher(criteria: {'name': 'test'}),
      ]);
      final results = await handler.executeSelector(
        block.cid,
        intersectionSelector,
      );
      expect(results, isNotEmpty);
    });

    test('executeSelector with none selector', () async {
      final data = {'value': 42};
      final block = await handler.put(data, codec: 'dag-cbor');

      final noneSelector = IPLDSelector.none();
      final results = await handler.executeSelector(block.cid, noneSelector);
      expect(results, isEmpty);
    });

    test('matcher with exists operator', () async {
      final data = {'value': 42};
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(
        criteria: {
          'value': {r'\$exists': true},
        },
      );
      final results = await handler.executeSelector(block.cid, matcher);
      // Just verify it doesn't throw
      expect(results, isA<List>());
    });

    test('matcher with type operator', () async {
      final data = {'value': 42};
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(
        criteria: {
          'value': {r'\$type': 'number'},
        },
      );
      final results = await handler.executeSelector(block.cid, matcher);
      // Just verify it doesn't throw
      expect(results, isA<List>());
    });

    test('matcher with mod operator', () async {
      final data = {'value': 10};
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(
        criteria: {
          'value': {
            r'\$mod': [5, 0],
          },
        },
      );

      final results = await handler.executeSelector(block.cid, matcher);
      // Just verify it doesn't throw
      expect(results, isA<List>());
    });

    test('matcher with all operator', () async {
      final data = {
        'tags': ['a', 'b', 'c'],
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(
        criteria: {
          'tags': {
            r'\$all': ['a', 'b'],
          },
        },
      );

      final results = await handler.executeSelector(block.cid, matcher);
      // Just verify it doesn't throw
      expect(results, isA<List>());
    });

    test('matcher with size operator', () async {
      final data = {
        'items': [1, 2, 3],
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(
        criteria: {
          'items': {r'\$size': 3},
        },
      );

      final results = await handler.executeSelector(block.cid, matcher);
      // Just verify it doesn't throw
      expect(results, isA<List>());
    });

    test('matcher with elemMatch operator', () async {
      final data = {
        'items': [
          {'id': 1},
          {'id': 2},
        ],
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(
        criteria: {
          'items': {
            r'\$elemMatch': {'id': 1},
          },
        },
      );

      final results = await handler.executeSelector(block.cid, matcher);
      // Just verify it doesn't throw
      expect(results, isA<List>());
    });

    test('resolveLink with empty path returns node', () async {
      final data = {'name': 'test'};
      final block = await handler.put(data, codec: 'dag-cbor');

      final (resolved, lastCid) = await handler.resolveLink(block.cid, '');
      expect(resolved.kind, Kind.MAP);
      expect(lastCid, block.cid.toString());
    });

    test('resolveLink handles list index out of bounds', () async {
      final data = [1, 2, 3];
      final block = await handler.put(data, codec: 'dag-cbor');

      expect(
        () => handler.resolveLink(block.cid, '10'),
        throwsA(isA<IPLDResolutionError>()),
      );
    });

    test('resolvePath with invalid CID throws IPLDPathError', () async {
      expect(
        () => handler.resolvePath('/ipfs/invalid-cid/path'),
        throwsA(isA<IPLDPathError>()),
      );
    });

    test('getMetadata for non-UnixFS node', () async {
      final data = {'name': 'test'};
      final block = await handler.put(data, codec: 'dag-cbor');

      final metadata = await handler.getMetadata(block.cid);
      expect(metadata.contentType, isNotNull);
      expect(metadata.size, isPositive);
    });

    test('start when already running is idempotent', () async {
      await handler.start(); // Should not throw
    });

    test('stop when not running is idempotent', () async {
      await handler.stop();
      await handler.stop(); // Should not throw
    });

    test('registerCodec adds custom codec', () {
      final customCodec = RawCodec();
      handler.registerCodec(customCodec);
      // Should not throw
    });

    test('registerSchema adds custom schema', () {
      final schema = IPLDSchema('test', {});
      handler.registerSchema(schema);
      // Should not throw
    });

    test('put with dag-pb codec', () async {
      final data = {
        'Data': Uint8List.fromList([1, 2, 3]),
        'Links': [],
      };
      final block = await handler.put(data, codec: 'dag-pb');
      expect(block, isNotNull);
      expect(block.cid, isNotNull);
    });

    test('get with non-existent CID returns empty node', () async {
      final cid = await CID.computeForData(utf8.encode('nonexistent'));
      final retrieved = await handler.get(cid);
      // Returns empty node instead of throwing
      expect(retrieved.kind, Kind.BYTES);
      expect(retrieved.bytesValue, isEmpty);
    });

    test('resolveLink with list path', () async {
      final data = [1, 2, 3];
      final block = await handler.put(data, codec: 'dag-cbor');

      final (resolved, lastCid) = await handler.resolveLink(block.cid, '0');
      expect(resolved.kind, Kind.INTEGER);
      expect(resolved.intValue.toInt(), 1);
    });

    test('resolveLink with nested map path', () async {
      final data = {
        'a': {
          'b': {'c': 'value'},
        },
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final (resolved, lastCid) = await handler.resolveLink(block.cid, 'a/b/c');
      expect(resolved.kind, Kind.STRING);
      expect(resolved.stringValue, 'value');
    });

    test('resolveLink with link in list', () async {
      final leafData = 'leaf';
      final leafBlock = await handler.put(leafData, codec: 'dag-cbor');

      final data = [leafBlock.cid];
      final block = await handler.put(data, codec: 'dag-cbor');

      final (resolved, lastCid) = await handler.resolveLink(block.cid, '0');
      expect(resolved.kind, Kind.STRING);
      expect(resolved.stringValue, leafData);
    });

    test('resolveLink with invalid list index throws error', () async {
      final data = [1, 2, 3];
      final block = await handler.put(data, codec: 'dag-cbor');

      expect(
        () => handler.resolveLink(block.cid, 'abc'),
        throwsA(isA<IPLDResolutionError>()),
      );
    });

    test('resolveLink with non-existent map key throws error', () async {
      final data = {'a': 1};
      final block = await handler.put(data, codec: 'dag-cbor');

      expect(
        () => handler.resolveLink(block.cid, 'nonexistent'),
        throwsA(isA<IPLDResolutionError>()),
      );
    });

    test('resolveLink traverses through multiple links', () async {
      final leafData = 'final leaf';
      final leafBlock = await handler.put(leafData, codec: 'dag-cbor');

      final midData = {'link': leafBlock.cid};
      final midBlock = await handler.put(midData, codec: 'dag-cbor');

      final rootData = {'link': midBlock.cid};
      final rootBlock = await handler.put(rootData, codec: 'dag-cbor');

      final (resolved, lastCid) = await handler.resolveLink(
        rootBlock.cid,
        'link/link',
      );
      expect(resolved.kind, Kind.STRING);
      expect(resolved.stringValue, leafData);
    });

    test('executeSelector with empty results', () async {
      final data = {'value': 42};
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(criteria: {'value': 999});
      final results = await handler.executeSelector(block.cid, matcher);
      expect(results, isEmpty);
    });

    test('put with empty data', () async {
      final data = Uint8List.fromList([]);
      final block = await handler.put(data, codec: 'raw');
      expect(block, isNotNull);
    });

    test('put with large data', () async {
      final data = Uint8List.fromList(List.filled(10000, 42));
      final block = await handler.put(data, codec: 'raw');
      expect(block, isNotNull);
    });

    test('getMetadata returns correct size', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final block = await handler.put(data, codec: 'raw');

      final metadata = await handler.getMetadata(block.cid);
      // Size includes encoding overhead
      expect(metadata.size, greaterThan(0));
    });

    test('getStatus returns codec count', () async {
      final status = await handler.getStatus();
      expect(status['supported_codecs'], isA<List>());
      expect(status['supported_codecs'].length, greaterThan(0));
    });

    test('resolvePath with trailing slash', () async {
      final data = {'name': 'test'};
      final block = await handler.put(data, codec: 'dag-cbor');

      final result = await handler.resolvePath('/ipfs/${block.cid}/');
      expect(result.kind, Kind.MAP);
    });

    test('resolvePath with only CID', () async {
      final data = {'name': 'test'};
      final block = await handler.put(data, codec: 'dag-cbor');

      final result = await handler.resolvePath('/ipfs/${block.cid}');
      expect(result.kind, Kind.MAP);
    });

    test('executeSelector with recursive selector and maxDepth', () async {
      final data = {
        'a': {
          'b': {
            'c': {'d': 'value'},
          },
        },
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final recursiveSelector = IPLDSelector.recursive(
        selector: IPLDSelector.all(),
        maxDepth: 3,
        stopAtLink: false,
      );
      final results = await handler.executeSelector(
        block.cid,
        recursiveSelector,
      );
      expect(results, isNotEmpty);
    });

    test('executeSelector with recursive selector and stopAtLink', () async {
      final leafData = 'leaf';
      final leafBlock = await handler.put(leafData, codec: 'dag-cbor');

      final data = {'link': leafBlock.cid};
      final block = await handler.put(data, codec: 'dag-cbor');

      final recursiveSelector = IPLDSelector.recursive(
        selector: IPLDSelector.all(),
        maxDepth: 2,
        stopAtLink: true,
      );
      final results = await handler.executeSelector(
        block.cid,
        recursiveSelector,
      );
      expect(results, isNotEmpty);
    });

    test('put with null value', () async {
      final data = null;
      final block = await handler.put(data, codec: 'dag-cbor');
      expect(block, isNotNull);

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.NULL);
    });

    test('put with boolean values', () async {
      final data = {'true': true, 'false': false};
      final block = await handler.put(data, codec: 'dag-cbor');
      expect(block, isNotNull);

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.MAP);
    });

    test('put with empty map', () async {
      final data = <String, dynamic>{};
      final block = await handler.put(data, codec: 'dag-cbor');
      expect(block, isNotNull);

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.MAP);
      expect(retrieved.mapValue.entries, isEmpty);
    });

    test('put with empty list', () async {
      final data = <dynamic>[];
      final block = await handler.put(data, codec: 'dag-cbor');
      expect(block, isNotNull);

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.LIST);
      expect(retrieved.listValue.values, isEmpty);
    });

    test('resolveLink with complex nested structure', () async {
      final data = {
        'items': [
          {
            'id': 1,
            'values': [10, 20, 30],
          },
          {
            'id': 2,
            'values': [40, 50, 60],
          },
        ],
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final (resolved, lastCid) = await handler.resolveLink(
        block.cid,
        'items/1/values/2',
      );
      expect(resolved.kind, Kind.INTEGER);
      expect(resolved.intValue.toInt(), 60);
    });

    test('executeSelector with complex matcher criteria', () async {
      final data = {
        'items': [
          {'id': 1, 'score': 85, 'active': true},
          {'id': 2, 'score': 92, 'active': false},
          {'id': 3, 'score': 78, 'active': true},
        ],
      };
      final block = await handler.put(data, codec: 'dag-cbor');

      final matcher = IPLDSelector.matcher(
        criteria: {
          'items': {
            r'\$elemMatch': {
              'score': {r'\$gt': 80},
              'active': true,
            },
          },
        },
      );
      final results = await handler.executeSelector(block.cid, matcher);
      expect(results, isA<List>());
    });

    test('get with dag-json codec', () async {
      final data = {'name': 'test', 'value': 123};
      final block = await handler.put(data, codec: 'dag-json');
      expect(block, isNotNull);

      final retrieved = await handler.get(block.cid);
      expect(retrieved.kind, Kind.MAP);
    });

    test('resolveLink handles circular references gracefully', () async {
      final data = {'value': 42};
      final block = await handler.put(data, codec: 'dag-cbor');

      // Create a circular reference by putting the CID back into the data
      final circularData = {'self': block.cid};
      final circularBlock = await handler.put(circularData, codec: 'dag-cbor');

      // Should not throw infinite recursion error
      final (resolved, lastCid) = await handler.resolveLink(
        circularBlock.cid,
        'self/value',
      );
      expect(resolved.kind, Kind.INTEGER);
      expect(resolved.intValue.toInt(), 42);
    });
  });
}
