import 'dart:typed_data';
import 'package:fixnum/fixnum.dart' as fixnum; // For handling 64-bit integers
import '/../src/proto/unixfs/unixfs.pb.dart' as unixfs;
import '/../src/proto/dht/link.pb.dart' as unixfs;
import '/../src/utils/base58.dart';

/// Represents a link to another node in the IPFS Merkle DAG.
class Link {
  /// The name of the linked node (can be empty for unnamed links).
  final String name;

  /// The CID (Content Identifier) of the linked node.
  final String cid;

  /// The size of the linked content in bytes.
  final int size;

  /// Additional metadata for the link.
  final Map<String, String>? metadata;

  /// Timestamp for when the link was created, defaults to current time.
  final int timestamp;

  /// Whether the link points to a directory.
  final bool isDirectory;

  /// Creates a new [Link].
  Link({
    required this.name,
    required this.cid,
    required this.size,
    this.metadata,
    int? timestamp,
    this.isDirectory = false,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch {
    // Validation for CID
    if (cid.isEmpty) {
      throw ArgumentError('CID cannot be empty');
    }
    // Validation for size
    if (size < 0) {
      throw ArgumentError('Size must be a non-negative integer');
    }
  }

  /// Creates a [Link] from its byte representation.
  static Link fromBytes(Uint8List bytes) {
    try {
      // 1. Deserialize the PBLink using Protobuf
      final pbLink = unixfs.PBLink.fromBuffer(bytes);

      // 2. Extract metadata if present
      final metadata = pbLink.hasField(3) ? Map<String, String>.from(pbLink.metadata) : null;

      // 3. Create a Link object with the extracted values
      return Link(
        name: pbLink.hasField(1) ? pbLink.name : '',
        cid: base58Encode(pbLink.hash),
        size: pbLink.hasField(2) ? pbLink.tsize.toInt() : 0,
        metadata: metadata,
        timestamp: pbLink.hasField(4) ? pbLink.timestamp.toInt() : DateTime.now().millisecondsSinceEpoch,
        isDirectory: pbLink.hasField(5) ? pbLink.isDirectory : false,
      );
    } catch (e) {
      throw FormatException('Failed to parse Link from bytes: $e');
    }
  }

  /// Converts the [Link] to its byte representation.
  Uint8List toBytes() {
    // 1. Create a PBLink (Protobuf object)
    final pbLink = unixfs.PBLink()
      ..name = name
      ..tsize = fixnum.Int64(size) // Convert int to 64-bit integer
      ..hash = base58Decode(cid);

    // 2. Add metadata if present
    if (metadata != null && metadata!.isNotEmpty) {
      pbLink.metadata.addAll(metadata!);
    }

    // 3. Add timestamp and directory flag
    pbLink.timestamp = fixnum.Int64(timestamp);
    pbLink.isDirectory = isDirectory;

    // 4. Serialize to buffer
    return pbLink.writeToBuffer();
  }

  /// Provides a readable representation of the link.
  @override
  String toString() {
    return 'Link(name: $name, cid: $cid, size: $size, timestamp: $timestamp, isDirectory: $isDirectory, metadata: $metadata)';
  }

  /// Equality check based on CID, name, and size.
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
