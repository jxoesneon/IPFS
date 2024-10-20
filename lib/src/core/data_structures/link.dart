// lib/src/core/data_structures/link.dart

import 'dart:typed_data';

import '/../src/proto/unixfs/unixfs.pb.dart' as unixfs;
import '/../src/utils/base58.dart';

/// Represents a link to another node in the IPFS Merkle DAG.
class Link {
  /// Creates a new [Link].
  Link({
    required this.name,
    required this.cid,
    required this.size,
  });

  /// The name of the linked node.
  final String name;

  /// The CID of the linked node.
  final String cid;

  /// The size of the linked content in bytes.
  final int size;

  /// Creates a [Link] from its byte representation.
  static Link fromBytes(Uint8List bytes) {
    // 1. Deserialize the PBLink using Protobuf
    final pbLink = unixfs.PBLink.fromBuffer(bytes);

    // 2. Create a Link object with the extracted values
    return Link(
      name: pbLink.name,
      cid: base58Encode(pbLink.hash),
      size: pbLink.tsize.toInt(), // Convert uint64 to int
    );
  }

  /// Converts the [Link] to its byte representation.
  Uint8List toBytes() {
    final pbLink = unixfs.PBLink()
      ..name = name
      ..tsize = size
      ..hash = base58Decode(cid);

    return pbLink.writeToBuffer();
  }
}
