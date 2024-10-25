// lib/src/core/data_structures/link.dart
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum;
import '/../src/proto/dht/link.pb.dart' as proto; // Correct path for Protobuf
import 'package:convert/convert.dart'; // Example package for conversions

class Base58 {
  static String base58Encode(Uint8List input) {
    // Implement actual Base58 encoding logic here
    return hex.encode(input); // Placeholder
  }

  static Uint8List base58Decode(String input) {
    // Implement actual Base58 decoding logic here
    return Uint8List.fromList(hex.decode(input)); // Placeholder
  }
}

/// Represents a link to another node in the IPFS Merkle DAG.
class Link {
  final String name;
  final Uint8List cid;
  final int size;
  final Map<String, String>? metadata;
  final int timestamp;
  final bool isDirectory;

  Link({
    required this.name,
    required this.cid,
    required this.size,
    this.metadata,
    int? timestamp,
    this.isDirectory = false,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch {
    _validateCid(cid);
    _validateSize(size);
  }

  void _validateCid(Uint8List cid) {
    if (cid.isEmpty) {
      throw ArgumentError('CID cannot be empty');
    }
  }

  void _validateSize(int size) {
    if (size < 0) {
      throw ArgumentError('Size must be a non-negative integer');
    }
  }

  /// Creates a [Link] from its Protobuf representation.
  static Link fromProto(proto.PBLink pbLink) {
    final metadata = pbLink.metadata.isNotEmpty ? Map<String, String>.from(pbLink.metadata) : null;

    return Link(
      name: pbLink.name,
      cid: Uint8List.fromList(pbLink.cid),
      size: pbLink.size.toInt(),
      metadata: metadata,
      timestamp: pbLink.timestamp.toInt(),
      isDirectory: pbLink.isDirectory,
    );
  }

  /// Converts the [Link] to its Protobuf representation.
  proto.PBLink toProto() {
    final pbLink = proto.PBLink()
      ..name = name
      ..cid = cid
      ..size = fixnum.Int64(size)
      ..metadata.addAll(metadata ?? {})
      ..timestamp = fixnum.Int64(timestamp)
      ..isDirectory = isDirectory;

    return pbLink;
  }

  @override
  String toString() {
    return 'Link(name: $name, cid: $cid, size: $size, timestamp: $timestamp, isDirectory: $isDirectory, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Link &&
          runtimeType == other.runtimeType &&
          cid == other.cid &&
          name == other.name &&
          size == other.size;

  @override
  int get hashCode => cid.hashCode ^ name.hashCode ^ size.hashCode;
}
