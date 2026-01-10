import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

/// A pin that prevents content from being garbage collected.
///
/// Pins mark content as important in IPFS, ensuring it remains available
/// locally and is not removed during garbage collection. There are several
/// pin types for different use cases.
///
/// **Pin Types:**
/// - Direct: Pins only the specified block
/// - Recursive: Pins the block and all linked content
/// - Indirect: Automatically pinned as part of a recursive pin
///
/// Example:
/// ```dart
/// final pin = Pin(
///   cid: contentCid,
///   type: PinTypeProto.PIN_TYPE_RECURSIVE,
///   blockStore: store,
/// );
///
/// await pin.pin();
/// // print('Content is pinned: ${pin.isPinned()}');
/// ```
///
/// See also:
/// - [PinManager] for bulk pin operations
/// - [BlockStore] for storage that respects pins
class Pin {
  /// Creates a new pin for the given [cid] with the specified [type].
  Pin({required this.cid, required this.type, DateTime? timestamp, required this.blockStore})
    : timestamp = timestamp ?? DateTime.now();

  /// Creates a [Pin] from its Protobuf representation.
  factory Pin.fromProto(PinProto pbPin, BlockStore blockStore) {
    return Pin(
      cid: CID.fromProto(pbPin.cid),
      type: pbPin.type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(pbPin.timestamp.toInt()),
      blockStore: blockStore,
    );
  }

  /// The content identifier being pinned.
  final CID cid;

  /// The type of pin (direct, recursive, indirect).
  final PinTypeProto type;

  /// When this pin was created.
  final DateTime timestamp;

  /// The block store for storage operations.
  final BlockStore blockStore;

  /// Converts the [Pin] to its Protobuf representation.
  PinProto toProto() {
    return PinProto()
      ..cid = cid.toProto()
      ..type = type
      ..timestamp = fixnum.Int64(timestamp.millisecondsSinceEpoch);
  }

  @override
  String toString() {
    return 'Pin(cid: $cid, type: $type, timestamp: $timestamp)';
  }

  /// Pins this block according to its type
  Future<bool> pin() async {
    return await blockStore.pinManager.pinBlock(cid.toProto(), type);
  }

  /// Unpins this block
  Future<bool> unpin() async {
    return await blockStore.pinManager.unpinBlock(cid.toProto());
  }

  /// Checks if this block is pinned
  bool isPinned() {
    return blockStore.pinManager.isBlockPinned(cid.toProto());
  }
}
