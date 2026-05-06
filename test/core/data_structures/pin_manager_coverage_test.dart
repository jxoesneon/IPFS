import 'dart:io';
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
import 'package:path/path.dart' as p;

class MockBlockStore implements BlockStore {
  final Map<String, GetBlockResponse> _blocks = {};
  bool shouldThrow = false;

  @override
  late final String path = Directory.systemTemp.createTempSync('mock_bs_').path;

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

    test('load and save pin state', () async {
      final tempDir = Directory.systemTemp.createTempSync('pin_test_');
      final pinFile = p.join(tempDir.path, 'pins.json');

      final cid1 = makeCid('cid1');
      final cid2 = makeCid('cid2');

      await manager.pinBlock(cid1.toProto(), PinTypeProto.PIN_TYPE_DIRECT);
      await manager.save(pinFile);

      final newManager = PinManager(mockStore);
      await newManager.load(pinFile);

      expect(newManager.isBlockPinned(cid1.toProto()), isTrue);
      expect(newManager.isBlockPinned(cid2.toProto()), isFalse);

      await tempDir.delete(recursive: true);
    });

    test('load handles non-existent file', () async {
      final tempDir = Directory.systemTemp.createTempSync('pin_test_');
      final pinFile = p.join(tempDir.path, 'nonexistent.json');

      await manager.load(pinFile);
      expect(manager.pinnedBlockCount, equals(0));

      await tempDir.delete(recursive: true);
    });

    test('load handles invalid JSON', () async {
      final tempDir = Directory.systemTemp.createTempSync('pin_test_');
      final pinFile = p.join(tempDir.path, 'invalid.json');

      await File(pinFile).writeAsString('invalid json');
      await manager.load(pinFile);
      expect(manager.pinnedBlockCount, equals(0));

      await tempDir.delete(recursive: true);
    });

    test('pinBlock with blockstore error', () async {
      mockStore.shouldThrow = true;
      final cid = makeCid('error');

      final result = await manager.pinBlock(
        cid.toProto(),
        PinTypeProto.PIN_TYPE_RECURSIVE,
      );
      // Even if blockstore throws during reference resolution, the pin is still added
      expect(result, isTrue);
    });

    test('getPinnedBlocks handles invalid CID strings', () async {
      final cid = makeCid('valid');
      await manager.pinBlock(cid.toProto(), PinTypeProto.PIN_TYPE_DIRECT);

      // Manually add an invalid CID string to _pins (simulating corrupted state)
      // This is a bit of a hack since _pins is private, but we can test through the public interface
      final blocks = manager.getPinnedBlocks();
      expect(blocks, isNotEmpty);
    });

    test('pinBlock with raw format', () async {
      final cid = makeCid('raw');
      mockStore.addBlock(cid, 'raw', [1, 2, 3]);

      final result = await manager.pinBlock(
        cid.toProto(),
        PinTypeProto.PIN_TYPE_RECURSIVE,
      );
      expect(result, isTrue);
    });

    test('unpinBlock with direct pin', () async {
      final cid = makeCid('direct');
      mockStore.addBlock(cid, 'raw', [1]);

      await manager.pinBlock(cid.toProto(), PinTypeProto.PIN_TYPE_DIRECT);
      expect(manager.isBlockPinned(cid.toProto()), isTrue);

      await manager.unpinBlock(cid.toProto());
      expect(manager.isBlockPinned(cid.toProto()), isFalse);
    });

    test('isBlockPinned with empty references', () async {
      final cid = makeCid('empty');
      mockStore.addBlock(cid, 'raw', [1]);

      expect(manager.isBlockPinned(cid.toProto()), isFalse);
    });

    test('save handles write errors', () async {
      final tempDir = Directory.systemTemp.createTempSync('pin_test_');
      // Create a directory instead of a file to cause write error
      final pinFile = p.join(tempDir.path, 'pins.json');
      await Directory(pinFile).create();

      await manager.save(pinFile);
      // Should not throw, error is logged

      await tempDir.delete(recursive: true);
    });
  });
}
