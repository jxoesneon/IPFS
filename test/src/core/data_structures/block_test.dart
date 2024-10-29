import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/data_structures/block.dart'; // Adjust the import path as necessary
import 'package:dart_ipfs/src/core/data_structures/cid.dart'; // Adjust the import path as necessary
import 'package:dart_ipfs/src/proto/generated/core/block.pb.dart'; // Adjust the import path as necessary

void main() {
  group('Block', () {
    test('Constructor initializes correctly', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final cidProto = CIDProto()
        ..version = CIDVersion.CID_VERSION_1
        ..multihash = [0x12, 0x20] // Example multihash
        ..codec = 'dag-pb'
        ..multibasePrefix = 'base58btc';
      final cid = CID.fromProto(cidProto);

      final block = Block(data, cid);

      expect(block.data, data);
      expect(block.cid.toProto(), cidProto);
    });

    test('fromData factory creates Block correctly', () {
      final data = Uint8List.fromList([5, 6, 7, 8]);
      final cidProto = CIDProto()
        ..version = CIDVersion.CID_VERSION_1
        ..multihash = [0x12, 0x20]
        ..codec = 'dag-pb'
        ..multibasePrefix = 'base58btc';
      final cid = CID.fromProto(cidProto);

      final block = Block.fromData(data, cid);

      expect(block.data, data);
      expect(block.cid.toProto(), cidProto);
    });

    test('toProto serializes Block correctly', () {
      final data = Uint8List.fromList([9, 10, 11]);
      final cidProto = CIDProto()
        ..version = CIDVersion.CID_VERSION_1
        ..multihash = [0x12, 0x20]
        ..codec = 'dag-pb'
        ..multibasePrefix = 'base58btc';
      final cid = CID.fromProto(cidProto);
      final block = Block(data, cid);

      final proto = block.toProto();

      expect(proto.data, data);
      expect(proto.cid.version, cidProto.version);
      expect(proto.cid.multihash, cidProto.multihash);
    });

    test('fromProto deserializes Block correctly', () {
      // Create a CID proto object
      final protoCid = CIDProto()
        ..version = CIDVersion.CID_VERSION_1
        ..multihash.addAll([0x12, 0x20])
        ..codec = 'dag-pb'
        ..multibasePrefix = 'base58btc';

      // Create a Block proto object with data and CID
      final protoBlock = BlockProto()
        ..data.addAll([12, 13]) // Ensure this matches expected input
        ..cid = protoCid;

      // Deserialize from proto to Block
      final block = Block.fromProto(protoBlock);

      // Verify that the block's data matches expected values
      expect(block.data.length, equals(2)); // Check length first
      expect(block.data, equals(Uint8List.fromList([12, 13]))); // Check content

      // Verify that the block's CID matches expected values
      expect(block.cid.toProto().version, protoCid.version);
    });
    test('size returns correct size of data', () {
      final data = Uint8List.fromList([14, 15]);
      final cidProto = CIDProto()
        ..version = CIDVersion.CID_VERSION_1
        ..multihash.addAll([0x12, 0x20])
        ..codec = 'dag-pb'
        ..multibasePrefix = 'base58btc';

      final cid = CID.fromProto(cidProto);

      final block = Block(data, cid);

      expect(block.size(), equals(2));
    });

    test('fromBytes throws exception on invalid input', () {
      final invalidBytes =
          Uint8List.fromList([16]); // Invalid bytes for testing

      expect(() => Block.fromBytes(invalidBytes), throwsException);
    });
  });
}
