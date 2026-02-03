import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/core/responses/block_response_factory.dart';
import 'package:test/test.dart';

class MockBlockStore implements BlockStore {
  final Map<String, GetBlockResponse> _blocks = {};
  bool shouldThrow = false;

  void addBlock(CID cid, String format, List<int> data) {
    final blockProto = BlockProto()
      ..cid = cid.toProto()
      ..format = format
      ..data = data;
    _blocks[cid.encode()] = BlockResponseFactory.successGet(blockProto);
  }

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    if (shouldThrow) throw Exception('Mock blockstore error');
    return _blocks[cid] ?? BlockResponseFactory.notFound();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PinManager', () {
    late MockBlockStore mockStore;
    late PinManager manager;

    setUp(() {
      mockStore = MockBlockStore();
      manager = PinManager(mockStore);
    });

    CID makeCid(String name) {
      return CID.computeForDataSync(Uint8List.fromList(name.codeUnits));
    }

    test('direct pinning', () async {
      final cid = makeCid('direct_cid');
      final success = await manager.pinBlock(
        cid.toProto(),
        PinTypeProto.PIN_TYPE_DIRECT,
      );
      expect(success, isTrue);
      expect(manager.isBlockPinned(cid.toProto()), isTrue);
    });

    test('recursive pinning - complex DAG', () async {
      final leaf = makeCid('leaf');
      final branch = makeCid('branch');
      final root = makeCid('root');

      final branchData = MerkleDAGNode(
        data: Uint8List(0),
        links: [Link(name: 'l', size: 1, cid: leaf)],
      ).toBytes();

      final rootData = MerkleDAGNode(
        data: Uint8List(0),
        links: [Link(name: 'b', size: 10, cid: branch)],
      ).toBytes();

      mockStore.addBlock(leaf, 'raw', [1, 2, 3]);
      mockStore.addBlock(branch, 'dag-pb', branchData);
      mockStore.addBlock(root, 'dag-pb', rootData);

      await manager.pinBlock(root.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);

      expect(manager.isBlockPinned(root.toProto()), isTrue);
      expect(manager.isBlockPinned(branch.toProto()), isTrue);
      expect(manager.isBlockPinned(leaf.toProto()), isTrue);
    });

    test('indirect pinning check via isBlockPinned', () async {
      final child = makeCid('child');
      final parent = makeCid('parent');

      final parentNodeData = MerkleDAGNode(
        data: Uint8List(0),
        links: [Link(name: 'c', size: 1, cid: child)],
      ).toBytes();

      mockStore.addBlock(parent, 'dag-pb', parentNodeData);
      mockStore.addBlock(child, 'raw', [0]);

      await manager.pinBlock(parent.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);

      // Indirectly pinned check
      expect(manager.isBlockPinned(child.toProto()), isTrue);
    });

    test('unpinning recursive cleanup logic', () async {
      final child = makeCid('child');
      final parent = makeCid('parent');

      final parentNodeData = MerkleDAGNode(
        data: Uint8List(0),
        links: [Link(name: 'c', size: 1, cid: child)],
      ).toBytes();

      mockStore.addBlock(parent, 'dag-pb', parentNodeData);
      mockStore.addBlock(child, 'raw', [0]);

      await manager.pinBlock(parent.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
      // Both parent and child in _pins now as RECURSIVE

      await manager.unpinBlock(parent.toProto());
      expect(manager.isBlockPinned(parent.toProto()), isFalse);
      expect(manager.isBlockPinned(child.toProto()), isFalse);
    });

    test(
      'unpinning recursive - child pinned twice (recursive + direct)',
      () async {
        final child = makeCid('child');
        final parent = makeCid('parent');
        final pnode = MerkleDAGNode(
          data: Uint8List(0),
          links: [Link(name: 'c', size: 1, cid: child)],
        ).toBytes();

        mockStore.addBlock(parent, 'dag-pb', pnode);
        mockStore.addBlock(child, 'raw', [0]);

        await manager.pinBlock(child.toProto(), PinTypeProto.PIN_TYPE_DIRECT);
        await manager.pinBlock(
          parent.toProto(),
          PinTypeProto.PIN_TYPE_RECURSIVE,
        );

        await manager.unpinBlock(parent.toProto());
        // child should remain because it was DIRECTLY pinned
        expect(manager.isBlockPinned(child.toProto()), isTrue);
      },
    );

    test('CBOR list extraction', () async {
      final c1 = makeCid('c1');
      final c2 = makeCid('c2');
      final data = [
        {'multihash': 'ignore', '/': c1.encode()},
        {'multihash': 'ignore', '/': c2.encode()},
      ];
      final encoded = const CborSimpleEncoder().convert(data);
      final pcid = makeCid('cbor_list');

      mockStore.addBlock(pcid, 'dag-cbor', encoded);
      mockStore.addBlock(c1, 'raw', [1]);
      mockStore.addBlock(c2, 'raw', [2]);

      await manager.pinBlock(pcid.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
      expect(manager.isBlockPinned(c1.toProto()), isTrue);
      expect(manager.isBlockPinned(c2.toProto()), isTrue);
    });

    test('errors - getBlockReferences failure', () async {
      mockStore.shouldThrow = true;
      final cid = makeCid('error_cid');
      final success = await manager.pinBlock(
        cid.toProto(),
        PinTypeProto.PIN_TYPE_RECURSIVE,
      );
      expect(success, isTrue); // Returns true despite internal error catch
    });

    test('errors - decodeCbor failure', () async {
      final cid = makeCid('bad_cbor');
      mockStore.addBlock(cid, 'dag-cbor', [0xFF, 0xFF]);
      await manager.pinBlock(cid.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
    });

    test('access logs', () {
      final cid = 'cid';
      final now = DateTime.now();
      manager.setBlockAccessTime(cid, now);
      expect(manager.getBlockAccessTime(cid), equals(now));
      manager.removeBlockAccessTime(cid);
    });

    test('CBOR nested map extraction', () async {
      final c1 = makeCid('c1');
      final data = {
        'a': {
          'b': {'/': c1.encode()},
        },
      };
      final encoded = const CborSimpleEncoder().convert(data);
      final pcid = makeCid('nested_cbor');

      mockStore.addBlock(pcid, 'dag-cbor', encoded);
      mockStore.addBlock(c1, 'raw', [1]);

      await manager.pinBlock(pcid.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
      expect(manager.isBlockPinned(c1.toProto()), isTrue);
    });

    test('recursive pinnedBlockCount includes indirect pins', () async {
      final child = makeCid('child');
      final parent = makeCid('parent');
      final pnode = MerkleDAGNode(
        data: Uint8List(0),
        links: [Link(name: 'c', size: 1, cid: child)],
      ).toBytes();

      mockStore.addBlock(parent, 'dag-pb', pnode);
      mockStore.addBlock(child, 'raw', [0]);

      await manager.pinBlock(parent.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);

      // parent is in _pins, child is NOT in _pins but is in _references
      // pinnedBlockCount should be 2
      expect(manager.pinnedBlockCount, equals(2));

      // If we unpin, count should be 0
      await manager.unpinBlock(parent.toProto());
      expect(manager.pinnedBlockCount, equals(0));
    });

    test('getPinnedBlocks handles recursive pins', () async {
      final c1 = makeCid('c1');
      await manager.pinBlock(c1.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
      final blocks = manager.getPinnedBlocks();
      expect(blocks.length, equals(1));
      expect(CID.fromProto(blocks.first).encode(), equals(c1.encode()));
    });
  });
}

