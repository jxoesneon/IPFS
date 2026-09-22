import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:protobuf/protobuf.dart' as pb;

/// Serializes [node] in the go-merkledag wire layout.
///
/// Kubo's go-merkledag marshals [dag_pb.PBNode] with gogoproto, which emits
/// fields in proto declaration order: `Links` (tag 2) first, then `Data`
/// (tag 1). Dart's protobuf runtime emits canonical tag order (Data first).
/// Both encodings decode to the same node, but only the go-merkledag layout
/// produces block hashes — and therefore CIDs — identical to Kubo's.
///
/// [dag_pb.PBLink] needs no special handling: its declaration order matches
/// its tag order, so `writeToBuffer()` output is already identical.
Uint8List marshalDagPBNode(dag_pb.PBNode node) {
  final builder = BytesBuilder();
  for (final link in node.links) {
    final linkBytes = link.writeToBuffer();
    builder.addByte(0x12); // field 2 (Links), wire type 2
    builder.add(_encodeVarint(linkBytes.length));
    builder.add(linkBytes);
  }
  if (node.data.isNotEmpty) {
    builder.addByte(0x0A); // field 1 (Data), wire type 2
    builder.add(_encodeVarint(node.data.length));
    builder.add(node.data);
  }
  // Preserve unknown fields carried over when the node was parsed from the
  // wire: protobuf emits unknown fields after all known fields, which matches
  // the go-merkledag/gogo marshaling order. Dropping them would change the
  // block bytes — and therefore the CID — on a parse/remarshal round-trip.
  if (node.unknownFields.isNotEmpty) {
    final writer = pb.CodedBufferWriter();
    node.unknownFields.writeToCodedBufferWriter(writer);
    builder.add(writer.toBuffer());
  }
  return builder.toBytes();
}

List<int> _encodeVarint(int value) {
  final out = <int>[];
  var v = value;
  while (v > 0x7f) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return out;
}
