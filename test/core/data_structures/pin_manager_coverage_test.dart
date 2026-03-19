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
  group('PinManager Coverage Completion', () {
    late MockBlockStore mockStore;
    late PinManager manager;

    setUp(() {
      mockStore = MockBlockStore();
      manager = PinManager(mockStore);
    });

    CID makeCid(String name) {
      return CID.computeForDataSync(Uint8List.fromList(name.codeUnits));
    }

    test('isBlockPinned indirect via _isIndirectlyPinned many', () async {
      final child = makeCid('indirect');
      final parent = makeCid('parent');
      final data = MerkleDAGNode(
        data: Uint8List(0),
        links: [Link(name: 'c', size: 1, cid: child)],
      ).toBytes();

      mockStore.addBlock(parent, 'dag-pb', data);
      mockStore.addBlock(child, 'raw', [0]);

      await manager.pinBlock(parent.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
      // isBlockPinned(child) should hit _isIndirectlyPinned loop
      expect(manager.isBlockPinned(child.toProto()), isTrue);
    });

    test('unpinBlock recursive cleanup - complex removal', () async {
      final c1 = makeCid('c1');
      final c2 = makeCid('c2');
      final parent = makeCid('p');
      final data = MerkleDAGNode(
        data: Uint8List(0),
        links: [
          Link(name: '1', size: 1, cid: c1),
          Link(name: '2', size: 1, cid: c2),
        ],
      ).toBytes();

      mockStore.addBlock(parent, 'dag-pb', data);
      mockStore.addBlock(c1, 'raw', [1]);
      mockStore.addBlock(c2, 'raw', [2]);

      await manager.pinBlock(parent.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
      await manager.pinBlock(c1.toProto(), PinTypeProto.PIN_TYPE_DIRECT);

      await manager.unpinBlock(parent.toProto());
      // c2 should be removed from _pins, c1 should stay
      expect(manager.isBlockPinned(c2.toProto()), isFalse);
      expect(manager.isBlockPinned(c1.toProto()), isTrue);
    });

    test('_extractCborReferences: non-string link value', () async {
      final pcid = makeCid('bad_link_val');
      final data = {'/': 123}; // Trigger else path in link check
      final encoded = const CborSimpleEncoder().convert(data);
      mockStore.addBlock(pcid, 'dag-cbor', encoded);
      await manager.pinBlock(pcid.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
    });

    test('pinnedBlockCount path - empty references', () {
      expect(manager.pinnedBlockCount, equals(0));
    });

    test('unpin non-existent', () async {
      final success = await manager.unpinBlock(makeCid('none').toProto());
      expect(success, isFalse);
    });

    test('getBlockReferences: unknown format throw path', () async {
      final cid = makeCid('unknown');
      mockStore.addBlock(cid, 'unknown', [1]);
      await manager.pinBlock(cid.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
    });
  });
}
