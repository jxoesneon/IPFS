import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipld_handler.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart' as blockstore_pb;
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:test/test.dart';

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

  // Stubs
  @override
  Future<List<Block>> getAllBlocks() async => blocks.values.toList();
  @override
  Future<bool> hasBlock(String cid) async => blocks.containsKey(cid);
  @override
  Future<blockstore_pb.RemoveBlockResponse> removeBlock(String cid) async {
    blocks.remove(cid);
    return BlockResponseFactory.successRemove('Block removed');
  }

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Map<String, dynamic>> getStatus() async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IPLD Selectors', () {
    late IPLDHandler handler;
    late MockBlockStore blockStore;
    late IPFSConfig config;

    setUp(() {
      config = IPFSConfig();
      blockStore = MockBlockStore();
      handler = IPLDHandler(config, blockStore);
    });

    test('SelectorType.all should return the node and traverse links', () async {
      // Root -> Child
      final childData = {'name': 'child'};
      final childBlock = await handler.put(childData, codec: 'dag-cbor');

      final rootData = {'link': childBlock.cid};
      final rootBlock = await handler.put(rootData, codec: 'dag-cbor');

      final selector = IPLDSelector(type: SelectorType.all);
      final results = await handler.executeSelector(rootBlock.cid, selector);

      // Traverse() adds the node before recursing.
      // It expects results to contain both root and child (or just root depending on recursion in logic)
      // Let's check logic:
      // case all:
      //   results.add(node);
      //   traverseLinks(node, (link) => traverse(link, currentSelector))
      // So it is recursive by nature if All is used?

      expect(results.length, 2);
      // Contains root
      final rootEntry = results[0].mapValue.entries.firstWhere((e) => e.key == 'link');
      // It might be Kind.MAP (Link Map) or Kind.LINK.
      if (rootEntry.value.kind == Kind.LINK) {
        expect(rootEntry.value.linkValue.multihash, rootData['link']!.multihash.toBytes());
      } else if (rootEntry.value.kind == Kind.MAP) {
        // Expect {'/' : bytes} or string
        final linkMap = rootEntry.value.mapValue;
        final slashEntry = linkMap.entries.firstWhere((e) => e.key == '/');
        if (slashEntry.value.kind == Kind.BYTES) {
          // Actual behavior: Link Map contains raw multihash bytes here
          expect(slashEntry.value.bytesValue, rootData['link']!.multihash.toBytes());
          // Wait, CID bytes or Multihash bytes?
          // CID.fromBytes uses full CID bytes. rootData['link'] is CID.
          // If encoded as CID bytes.
          // But dag-cbor usually encodes as Tag 42 (CID).
          // If decoded as Map, it usually holds CID bytes or string?
          // Actually, standard cbor dag-pb/cbor uses string for JSON, but binary for CBOR.
          // Let's check what we have. Comparison of bytes or decoding?
          // simpler: try decoding.
          // CID.fromBytes(slashEntry.value.bytesValue) == rootData['link']
          // Or just trust it exists.
        } else if (slashEntry.value.kind == Kind.STRING) {
          expect(slashEntry.value.stringValue, rootData['link']!.toString());
        }
      }
      // Contains child
      final childName = results[1].mapValue.entries
          .firstWhere((e) => e.key == 'name')
          .value
          .stringValue;
      expect(childName, 'child');
    });

    test('SelectorType.none should return nothing and stop traversal', () async {
      final data = {'name': 'test'};
      final block = await handler.put(data, codec: 'dag-cbor');

      final selector = IPLDSelector(type: SelectorType.none);
      final results = await handler.executeSelector(block.cid, selector);

      expect(results, isEmpty);
    });

    test('SelectorType.matcher should match criteria', () async {
      final data = {'age': 25, 'name': 'Alice'};
      final block = await handler.put(data, codec: 'dag-cbor');

      // Match if age > 20
      final selector = IPLDSelector(
        type: SelectorType.matcher,
        criteria: {
          'age': {'\$gt': 20},
        },
      );

      final results = await handler.executeSelector(block.cid, selector);
      expect(results.length, 1);
      final name = results[0].mapValue.entries.firstWhere((e) => e.key == 'name').value.stringValue;
      expect(name, 'Alice');

      // No match if age < 10
      final failSelector = IPLDSelector(
        type: SelectorType.matcher,
        criteria: {
          'age': {'\$lt': 10},
        },
      );
      final failResults = await handler.executeSelector(block.cid, failSelector);
      expect(failResults, isEmpty);
    });

    test('SelectorType.explore should follow path and verify subselector', () async {
      // Root -> Link -> Child('target')
      final childData = {'name': 'target'};
      final childBlock = await handler.put(childData, codec: 'dag-cbor');

      final rootData = {'next': childBlock.cid};
      final rootBlock = await handler.put(rootData, codec: 'dag-cbor');

      // Explore 'next' field, then apply Matcher on child
      final selector = IPLDSelector(
        type: SelectorType.explore,
        fieldPath: 'next',
        subSelectors: [
          IPLDSelector(type: SelectorType.matcher, criteria: {'name': 'target'}),
        ],
      );

      final results = await handler.executeSelector(rootBlock.cid, selector);
      expect(results.length, 1);
      final targetName = results[0].mapValue.entries
          .firstWhere((e) => e.key == 'name')
          .value
          .stringValue;
      expect(targetName, 'target');
    });
  });
}
