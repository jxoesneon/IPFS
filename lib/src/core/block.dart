import 'dart:typed_data';
import 'package:dart_ipfs/src/core/interfaces/block_cloneable.dart';
import 'package:dart_ipfs/src/core/interfaces/block_data.dart';
import 'package:dart_ipfs/src/core/cid.dart';

/// An immutable, content-addressed block of data in IPFS.
///
/// A block is the fundamental unit of data storage in IPFS. Each block
/// contains raw binary data and is uniquely identified by its [CID]
/// (Content Identifier), which is derived from a cryptographic hash
/// of the block's contents.
///
/// Blocks are immutable by design - the same content will always produce
/// the same CID, enabling content-addressable storage and deduplication.
///
/// Example:
/// ```dart
/// final data = Uint8List.fromList(utf8.encode('Hello IPFS'));
/// final cid = await CID.fromContent(data);
/// final block = Block(data: data, cid: cid);
///
/// print('Block CID: ${block.cid}');
/// print('Block size: ${block.size} bytes');
/// ```
///
/// See also:
/// - [CID] for content identifier operations
/// - [BlockStore] for persisting blocks
/// - [BlockData] for the interface contract
class Block with BlockCloneable<Block> implements BlockData {
  /// The raw binary content of this block.
  ///
  /// This data is immutable and its hash determines the block's [cid].
  @override
  final Uint8List data;

  /// The content identifier uniquely identifying this block.
  ///
  /// The CID is derived from a cryptographic hash of [data] and includes
  /// version, codec, and multihash information.
  @override
  CID get cid => _cid;

  final CID _cid;

  /// Creates a new block with the given [data] and [cid].
  ///
  /// The caller is responsible for ensuring the [cid] correctly
  /// corresponds to the hash of [data].
  const Block({
    required this.data,
    required CID cid,
  }) : _cid = cid;

  /// Creates a deep copy of this block.
  ///
  /// The returned block has its own copy of the data buffer,
  /// so modifications to the original will not affect the clone.
  @override
  Block clone() => Block(
        data: Uint8List.fromList(data),
        cid: cid,
      );

  /// Creates a copy of this block and applies [updates] to it.
  ///
  /// Note: Since blocks are content-addressed, modifying data would
  /// require recomputing the CID to maintain consistency.
  @override
  Block copyWith(void Function(Block) updates) {
    final clone = Block(
      data: data,
      cid: cid,
    );
    updates(clone);
    return clone;
  }

  /// Returns the raw bytes of this block.
  ///
  /// This is equivalent to accessing [data] directly.
  @override
  Uint8List toBytes() => data;

  /// The size of this block in bytes.
  @override
  int get size => data.length;
}
