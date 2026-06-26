// lib/src/block/block.dart
import 'dart:typed_data';

import '../cid/cid.dart';

/// Interface for content-addressed data blocks.
///
/// A block is the fundamental unit of data in IPFS, identified by its CID.
abstract class IBlock {
  /// The raw binary data of this block.
  Uint8List get data;

  /// The content identifier for this block.
  CID get cid;

  /// The size of this block in bytes.
  int get size;

  /// Serializes the block to bytes.
  Uint8List toBytes();

  /// Validates the block's content hash matches its CID.
  ///
  /// Returns `true` if the hash matches, `false` otherwise.
  Future<bool> validate();
}

/// Represents an IPFS block.
class Block implements IBlock {
  /// Creates a new [Block] with the given [cid], [data], and [format].
  Block({required this.cid, required this.data, this.format = 'raw'});

  /// Creates a block from raw data, automatically computing the CID.
  static Future<Block> fromData(Uint8List data, {String format = 'raw'}) async {
    final cid = await CID.fromContent(data, codec: format);
    return Block(cid: cid, data: data, format: format);
  }

  @override
  final CID cid;

  @override
  final Uint8List data;

  /// The codec format used by this block (e.g., 'raw', 'dag-pb').
  final String format;

  @override
  int get size => data.length;

  @override
  Future<bool> validate() async {
    try {
      final computedCid = await CID.fromContent(data, codec: format);
      final computedMh = computedCid.multihash.toBytes();
      final expectedMh = cid.multihash.toBytes();
      if (computedMh.length != expectedMh.length) return false;
      for (var i = 0; i < computedMh.length; i++) {
        if (computedMh[i] != expectedMh[i]) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Synchronous structural validation.
  ///
  /// This checks only that the block is non-empty and has a valid CID
  /// encoding. Use [validate] for cryptographic verification.
  bool validateSync() {
    if (data.isEmpty) return false;
    if (cid.encode().isEmpty) return false;
    return true;
  }

  @override
  Uint8List toBytes() => data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block &&
          runtimeType == other.runtimeType &&
          cid == other.cid &&
          _bytesEqual(data, other.data);

  @override
  int get hashCode => cid.hashCode ^ data.length.hashCode;

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
