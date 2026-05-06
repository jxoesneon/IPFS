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
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/core/ipld/path/ipld_path_handler.dart';
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
        Kind.BYTES,
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
      // It seems to be deserialized as BYTES in this specific test environment
      expect(retrieved.kind, Kind.BYTES);
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
  });
}
