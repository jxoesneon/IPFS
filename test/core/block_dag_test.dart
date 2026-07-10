import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_proto;
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('Block', () {
    test('fromData computes CID and stores data', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final block = await Block.fromData(data, format: 'raw');

      expect(block.data, equals(data));
      expect(block.format, equals('raw'));
      expect(block.size, equals(3));
      expect(block.cid.codec, equals('raw'));
    });

    test('validate returns true for correct data', () async {
      final data = Uint8List.fromList([4, 5, 6]);
      final block = await Block.fromData(data);
      expect(await block.validate(), isTrue);
    });

    test('validate returns false for corrupted data', () async {
      final data = Uint8List.fromList([7, 8, 9]);
      final block = await Block.fromData(data);

      // Create a "corrupted" block with same CID but different data
      final corruptedBlock = Block(
        cid: block.cid,
        data: Uint8List.fromList([7, 8, 10]),
        format: block.format,
      );

      expect(await corruptedBlock.validate(), isFalse);
    });

    test('validateSync performs structural checks', () async {
      final block = await Block.fromData(Uint8List(3));
      expect(block.validateSync(), isTrue);

      final emptyBlock = Block(cid: block.cid, data: Uint8List(0));
      expect(emptyBlock.validateSync(), isFalse);
    });

    test('operator == and hashCode deep dive', () async {
      final b1 = await Block.fromData(Uint8List(1));
      expect(b1 == b1, isTrue); // identical
      expect(b1 == Object(), isFalse); // different type

      final b2 = await Block.fromData(Uint8List(1));
      expect(b1 == b2, isTrue); // same content

      final b3 = await Block.fromData(Uint8List(2));
      expect(b1 == b3, isFalse); // different content

      expect(b1.hashCode, equals(b2.hashCode));
    });

    test('proto roundtrip', () async {
      final block = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      final proto = block.toProto();
      final fromProto = Block.fromProto(proto);

      expect(fromProto.cid, equals(block.cid));
      expect(fromProto.data, equals(block.data));
      expect(fromProto.format, equals(block.format));
    });

    test('Bitswap and raw bytes conversion', () async {
      final data = Uint8List.fromList([10, 20, 30]);
      final block = await Block.fromData(data);

      final bitswapProto = block.toBitswapProto();
      expect(bitswapProto.data, equals(data));

      final fromBitswap = await Block.fromBitswapProto(bitswapProto);
      expect(fromBitswap.data, equals(data));

      expect(block.toBytes(), equals(data));
    });
  });

  group('MerkleDAGNode', () {
    test('create and toBytes/fromBytes', () {
      final unixData = unixfs_proto.Data()
        ..type = unixfs_proto.Data_DataType.Directory
        ..mtime = Int64(123456789);
      final data = Uint8List.fromList(unixData.writeToBuffer());

      final linkCid = CID.computeForDataSync(Uint8List(10));
      final links = [Link(name: 'child1', size: 10, cid: linkCid)];

      final node = MerkleDAGNode(
        links: links,
        data: data,
        isDirectory: true,
        mtime: 123456789,
      );

      final bytes = node.toBytes();
      final fromBytes = MerkleDAGNode.fromBytes(bytes);

      expect(fromBytes.data, equals(data));
      expect(fromBytes.links.length, equals(1));
      expect(fromBytes.links[0].name, equals('child1'));
      expect(fromBytes.links[0].cid, equals(linkCid));
      expect(fromBytes.isDirectory, isTrue);
      expect(fromBytes.mtime, equals(123456789));
    });

    test('cid property computation', () {
      final node = MerkleDAGNode(links: [], data: Uint8List(5));
      expect(node.cid.codec, equals('dag-pb'));
    });

    test('toString and HAMTShard coverage', () {
      final node = MerkleDAGNode(
        links: [],
        data: Uint8List(0),
        isDirectory: false,
      );
      expect(node.toString(), contains('MerkleDAGNode'));

      final hamtData = unixfs_proto.Data()
        ..type = unixfs_proto.Data_DataType.HAMTShard;
      final pbNode = MerkleDAGNode(
        links: [],
        data: Uint8List.fromList(hamtData.writeToBuffer()),
      );
      final decoded = MerkleDAGNode.fromBytes(pbNode.toBytes());
      expect(decoded.isDirectory, isTrue);
    });
  });
}
