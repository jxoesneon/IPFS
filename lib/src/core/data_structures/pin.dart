import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/cid.dart'; // Import CID class for handling CIDs
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
// lib/src/core/data_structures/pin.dart

/// Represents a pin in the IPFS network.
class Pin {
  final CID cid; // The CID of the content to be pinned
  final PinTypeProto type; // The type of pin (direct, recursive, etc.)
  final DateTime timestamp; // The timestamp when the pin was created
  final BlockStore blockStore;
  final PinManager _pinManager; // Add PinManager instance

  Pin({
    required this.cid,
    required this.type,
    DateTime? timestamp,
    required this.blockStore,
  })  : timestamp = timestamp ?? DateTime.now(),
        _pinManager =
            PinManager(blockStore); // Initialize PinManager with BlockStore

  /// Creates a [Pin] from its Protobuf representation.
  factory Pin.fromProto(PinProto pbPin, BlockStore blockStore) {
    return Pin(
      cid: CID.fromProto(pbPin.cid),
      type: pbPin.type,
      timestamp: DateTime.fromMillisecondsSinceEpoch(pbPin.timestamp.toInt()),
      blockStore: blockStore,
    );
  }

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
    return await _pinManager.pinBlock(cid.toProto(), type);
  }

  /// Unpins this block
  Future<bool> unpin() async {
    return await _pinManager.unpinBlock(cid.toProto());
  }

  /// Checks if this block is pinned
  bool isPinned() {
    return _pinManager.isBlockPinned(cid.toProto());
  }
}
