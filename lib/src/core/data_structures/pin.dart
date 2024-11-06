import 'dart:collection';
import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import '../../proto/generated/core/pin.pb.dart';
import '../../core/data_structures/blockstore.dart';
import 'cid.dart'; // Import CID class for handling CIDs
import '../../core/data_structures/merkle_dag_node.dart';
import 'package:cbor/simple.dart'; // Use simple CBOR API
import '../../proto/generated/core/cid.pb.dart'; // Import the generated Protobuf file
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

class PinManager {
  final Map<String, PinTypeProto> _pins = {};
  final Map<String, Set<String>> _references = {}; // Track block references
  final Map<String, DateTime> _accessTimes = {}; // Track access times
  final BlockStore _blockStore; // Add BlockStore reference

  PinManager(this._blockStore); // Add constructor

  Future<bool> pinBlock(CIDProto cid, PinTypeProto type) async {
    if (type == PinTypeProto.PIN_TYPE_RECURSIVE) {
      return await _pinRecursive(cid);
    } else if (type == PinTypeProto.PIN_TYPE_DIRECT) {
      _pins[cid.toString()] = type;
      return true;
    }
    return false;
  }

  /// Recursively pins a block and all its references
  Future<bool> _pinRecursive(CIDProto cid) async {
    final Set<String> visited = {};
    final Queue<String> queue = Queue();
    final String cidStr = cid.toString();

    // Pin the root block
    _pins[cidStr] = PinTypeProto.PIN_TYPE_RECURSIVE;
    queue.add(cidStr);

    while (queue.isNotEmpty) {
      final currentCid = queue.removeFirst();
      if (visited.contains(currentCid)) continue;

      visited.add(currentCid);

      // Get references from the current block
      final references = await _getBlockReferences(currentCid);
      if (references != null) {
        _references[currentCid] = references;

        // Add all references to the queue and mark them as indirectly pinned
        for (final refCid in references) {
          if (!visited.contains(refCid)) {
            queue.add(refCid);
            // Only set pin if not already directly pinned
            if (!_pins.containsKey(refCid)) {
              _pins[refCid] = PinTypeProto.PIN_TYPE_RECURSIVE;
            }
          }
        }
      }
    }

    return true;
  }

  /// Helper method to get block references
  Future<Set<String>?> _getBlockReferences(String cidStr) async {
    try {
      // Get the block data from the block store
      final cidProto = CIDProto()..multihash = cidStr.codeUnits;
      final block = await _blockStore.getBlock(cidProto);
      if (!block.found) return null;

      // Parse the block data to extract references based on your data format
      final references = Set<String>();

      // Get format from block instead of CID
      final format = block.block.format;

      switch (format) {
        case 'dag-pb':
          // Parse Protocol Buffers format
          final dagNode =
              MerkleDAGNode.fromBytes(Uint8List.fromList(block.block.data));
          for (final link in dagNode.links) {
            references.add(link.cid.toString());
          }
          break;

        case 'dag-cbor':
          // Parse CBOR format using cbor package
          final decoded =
              await _decodeCbor(Uint8List.fromList(block.block.data));
          references.addAll(_extractCborReferences(decoded));
          break;

        case 'raw':
          // Raw format has no references
          break;

        default:
          throw UnsupportedError('Unsupported block format: $format');
      }

      return references;
    } catch (e) {
      print('Error getting block references: $e');
      return null;
    }
  }

  /// Helper method to decode CBOR data
  Future<dynamic> _decodeCbor(Uint8List data) async {
    try {
      // Use the simple CBOR API for decoding
      return CborSimpleDecoder().convert(data);
    } catch (e) {
      throw FormatException('Failed to decode CBOR data: $e');
    }
  }

  /// Helper method to extract references from CBOR data
  Set<String> _extractCborReferences(dynamic decoded) {
    final references = Set<String>();

    if (decoded is Map) {
      for (final value in decoded.values) {
        if (value is Map && value.containsKey('/')) {
          // CID link in CBOR
          references.add(value['/']);
        } else {
          references.addAll(_extractCborReferences(value));
        }
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        references.addAll(_extractCborReferences(item));
      }
    }

    return references;
  }

  bool isBlockPinned(CIDProto cid) {
    final cidStr = cid.toString();
    return _pins.containsKey(cidStr) || _isIndirectlyPinned(cidStr);
  }

  bool _isIndirectlyPinned(String cidStr) {
    // Check if this block is referenced by any recursively pinned blocks
    return _references.entries
        .where((entry) => _pins[entry.key] == PinTypeProto.PIN_TYPE_RECURSIVE)
        .any((entry) => entry.value.contains(cidStr));
  }

  /// Unpins a block by its CID.
  Future<bool> unpinBlock(CIDProto cid) async {
    final cidStr = cid.toString();
    if (!_pins.containsKey(cidStr)) {
      return false;
    }

    // If it's recursively pinned, we need to remove all indirect pins
    if (_pins[cidStr] == PinTypeProto.PIN_TYPE_RECURSIVE) {
      final referencedBlocks = _references[cidStr] ?? <String>{};
      for (final refCid in referencedBlocks) {
        // Only remove if not directly pinned elsewhere
        if (!_pins.containsKey(refCid) ||
            _pins[refCid] != PinTypeProto.PIN_TYPE_DIRECT) {
          _pins.remove(refCid);
        }
      }
      _references.remove(cidStr);
    }

    _pins.remove(cidStr);
    return true;
  }

  /// Gets the last access time for a block
  DateTime? getBlockAccessTime(String cidStr) {
    return _accessTimes[cidStr];
  }

  /// Removes the access time tracking for a block
  void removeBlockAccessTime(String cidStr) {
    _accessTimes.remove(cidStr);
  }

  /// Gets all pinned blocks CIDs.
  List<CIDProto> getPinnedBlocks() {
    final pinnedBlocks = <CIDProto>[];

    for (final entry in _pins.entries) {
      if (entry.value == PinTypeProto.PIN_TYPE_DIRECT ||
          entry.value == PinTypeProto.PIN_TYPE_RECURSIVE) {
        try {
          pinnedBlocks.add(_stringToCIDProto(entry.key));
        } catch (e) {
          print('Warning: Skipping invalid CID: ${entry.key}');
          continue;
        }
      }
    }

    // Add indirectly pinned blocks
    for (final entry in _references.entries) {
      if (_pins[entry.key] == PinTypeProto.PIN_TYPE_RECURSIVE) {
        for (final refCid in entry.value) {
          if (!_pins.containsKey(refCid)) {
            final cid = CID.fromBytes(Uint8List.fromList(refCid.codeUnits),
                'raw', // Default codec, adjust if needed
                version: CIDVersion.CID_VERSION_1);
            pinnedBlocks.add(cid.toProto());
          }
        }
      }
    }

    return pinnedBlocks;
  }

  void setBlockAccessTime(String cidStr, DateTime time) {
    _accessTimes[cidStr] = time;
  }

  CIDProto _stringToCIDProto(String cidStr) {
    try {
      final cid = CID.fromBytes(Uint8List.fromList(cidStr.codeUnits), 'raw',
          version: CIDVersion.CID_VERSION_1);
      return cid.toProto();
    } catch (e) {
      throw FormatException('Invalid CID string format: $cidStr');
    }
  }
}
