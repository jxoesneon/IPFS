// test/proto/dag_marshal_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/dag_marshal.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('marshalDagPBNode', () {
    test('emits links (tag 2) before data (tag 1) in go-merkledag order', () {
      final node = PBNode()
        ..data = Uint8List.fromList([0x08, 0x01])
        ..links.add(
          PBLink()
            ..name = 'child'
            ..hash = Uint8List.fromList([0x01, 0x02, 0x03])
            ..size = Int64(3),
        );

      final bytes = marshalDagPBNode(node);

      // First byte must be the Links field tag (field 2, wire type 2 = 0x12),
      // and the Data field tag (0x0A) must appear after the link payload.
      expect(bytes[0], equals(0x12));
      expect(bytes.last, equals(0x01));
      expect(bytes[bytes.length - 4], equals(0x0A));
    });

    test('produces identical bytes on a parse/remarshal round-trip', () {
      final node = PBNode()
        ..data = Uint8List.fromList([0x08, 0x01])
        ..links.add(
          PBLink()
            ..name = 'child'
            ..hash = Uint8List.fromList([0xAA, 0xBB])
            ..size = Int64(7),
        );

      final bytes = marshalDagPBNode(node);
      final reparsed = PBNode.fromBuffer(bytes);
      final remarshalled = marshalDagPBNode(reparsed);

      expect(remarshalled, equals(bytes));
    });

    test('preserves unknown fields added to the node', () {
      final node = PBNode()..data = Uint8List.fromList([0x08, 0x01]);
      // Unknown field: tag 15 (varint) — PBNode only defines fields 1 and 2.
      node.unknownFields.mergeVarintField(15, Int64(0xC0DE));
      // Unknown field: tag 20 (length-delimited).
      node.unknownFields.mergeLengthDelimitedField(20, [0xDE, 0xAD]);

      final bytes = marshalDagPBNode(node);
      final reparsed = PBNode.fromBuffer(bytes);

      expect(reparsed.unknownFields.hasField(15), isTrue);
      expect(reparsed.unknownFields.hasField(20), isTrue);
    });

    test('preserves unknown fields parsed from the wire byte-for-byte', () {
      // Hand-encode a PBNode containing Data (tag 1), a Link (tag 2), and an
      // unknown field (tag 15, varint) appended after the known fields, as
      // protobuf/gogoproto emit them.
      final link = PBLink()
        ..name = 'x'
        ..hash = Uint8List.fromList([0x01])
        ..size = Int64(1);
      final linkBytes = link.writeToBuffer();
      final data = Uint8List.fromList([0x08, 0x02]);

      final wire = BytesBuilder()
        ..addByte(0x12) // Links, field 2, wire type 2
        ..addByte(linkBytes.length)
        ..add(linkBytes)
        ..addByte(0x0A) // Data, field 1, wire type 2
        ..addByte(data.length)
        ..add(data)
        ..addByte(0x78) // unknown field 15, wire type 0 (varint)
        ..addByte(0x2A);

      final parsed = PBNode.fromBuffer(wire.toBytes());
      expect(parsed.unknownFields.isNotEmpty, isTrue);

      // Re-marshaling must reproduce the exact wire bytes — otherwise the
      // block hash (CID) would change on re-store.
      expect(marshalDagPBNode(parsed), equals(wire.toBytes()));
    });

    test('unknown fields survive a full marshal/parse/remarshal cycle', () {
      final node = PBNode()
        ..data = Uint8List.fromList([0x08, 0x01])
        ..links.add(
          PBLink()
            ..name = 'leaf'
            ..hash = Uint8List.fromList([0x09])
            ..size = Int64(4),
        );
      node.unknownFields.mergeVarintField(100, Int64(42));

      final first = marshalDagPBNode(node);
      final second = marshalDagPBNode(PBNode.fromBuffer(first));

      expect(second, equals(first));
      // The unknown field bytes (tag 100 = varint 0xA0 0x06, value 0x2A)
      // must appear at the tail of the buffer.
      expect(first.sublist(first.length - 3), equals([0xA0, 0x06, 0x2A]));
    });
  });
}
