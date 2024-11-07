import 'pin.dart';
import 'dart:async';
import 'cid.dart'; // Add this import
import '../../proto/generated/core/pin.pb.dart'; // Add this import
import '../../proto/generated/core/cid.pb.dart'; // Import the generated CIDProto
import '../../proto/generated/core/block.pb.dart'; // Import the generated BlockProto
import '../../proto/generated/core/blockstore.pb.dart'; // Import the generated BlockStoreProto
// lib/src/core/data_structures/blockstore.dart

/// Represents a block store that manages blocks with IPFS datastore compliance.
class BlockStore {
  final List<BlockProto> _blocks = [];
  late final PinManager _pinManager;
  final Duration _gcThreshold;
  Timer? _gcTimer;

  BlockStore({Duration gcInterval = const Duration(hours: 1)})
      : _gcThreshold = gcInterval {
    _pinManager = PinManager(this);
    _startGarbageCollection();
  }

  /// Adds a block to the store with optional pinning.
  Future<AddBlockResponse> addBlock(BlockProto block,
      {PinTypeProto type = PinTypeProto.PIN_TYPE_DIRECT}) async {
    final cid = CID.fromProto(block.cid);
    final cidHash = cid.hashedValue();

    if (_blocks.any((b) => CID.fromProto(b.cid).hashedValue() == cidHash)) {
      return AddBlockResponse()
        ..success = false
        ..message = "Block already exists.";
    }

    _blocks.add(block);
    _pinManager.pinBlock(block.cid, type);

    return AddBlockResponse()
      ..success = true
      ..message = "Block added successfully.";
  }

  /// Pins a block by its CID with specified pin type.
  Future<bool> pinBlock(CIDProto cidProto,
      {PinTypeProto type = PinTypeProto.PIN_TYPE_RECURSIVE}) async {
    final cid = CID.fromProto(cidProto);
    final cidHash = cid.hashedValue();

    final block = _blocks.firstWhere(
      (b) => CID.fromProto(b.cid).hashedValue() == cidHash,
      orElse: () => BlockProto(),
    );

    if (_blocks.contains(block)) {
      _pinManager.pinBlock(cidProto, type);
      _pinManager.setBlockAccessTime(cidHash, DateTime.now());
      return true;
    }
    return false;
  }

  /// Unpins a block by its CID.
  Future<bool> unpinBlock(CIDProto cid) async {
    return _pinManager.unpinBlock(cid);
  }

  /// Gets all pinned blocks.
  List<BlockProto> getPinnedBlocks() {
    return _blocks.where((b) => _pinManager.isBlockPinned(b.cid)).toList();
  }

  /// Retrieves a block by its CID and updates access time.
  GetBlockResponse getBlock(CIDProto cidProto) {
    final cid = CID.fromProto(cidProto);
    final cidHash = cid.hashedValue();

    final block = _blocks.firstWhere(
      (b) => CID.fromProto(b.cid).hashedValue() == cidHash,
      orElse: () => BlockProto(),
    );

    if (_blocks.contains(block)) {
      _pinManager.setBlockAccessTime(cidHash, DateTime.now());
      _pinManager.pinBlock(cidProto, PinTypeProto.PIN_TYPE_DIRECT);
    }

    return GetBlockResponse()
      ..block = block
      ..found = _blocks.contains(block);
  }

  /// Starts the garbage collection timer.
  void _startGarbageCollection() {
    _gcTimer?.cancel();
    _gcTimer = Timer.periodic(_gcThreshold, (_) => _performGarbageCollection());
  }

  /// Performs garbage collection on unpinned and unused blocks.
  Future<void> _performGarbageCollection() async {
    final now = DateTime.now();
    final blocksToRemove = <BlockProto>[];

    for (final block in _blocks) {
      final cidStr = block.cid.toString();
      if (!_pinManager.isBlockPinned(block.cid)) {
        final lastAccess = _pinManager.getBlockAccessTime(cidStr);
        if (lastAccess != null && now.difference(lastAccess) > _gcThreshold) {
          blocksToRemove.add(block);
          _pinManager.removeBlockAccessTime(cidStr);
        }
      }
    }

    _blocks.removeWhere((b) => blocksToRemove.contains(b));
  }

  /// Forces immediate garbage collection.
  Future<void> forceGarbageCollection() async {
    await _performGarbageCollection();
  }

  /// Disposes of the BlockStore and stops garbage collection.
  void dispose() {
    _gcTimer?.cancel();
  }

  @override
  String toString() {
    return 'BlockStore(blocks: ${_blocks.length}, pinned: ${_pinManager.getPinnedBlocks().length})';
  }
}
