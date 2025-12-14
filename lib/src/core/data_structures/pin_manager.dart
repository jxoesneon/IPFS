// src/core/data_structures/pin_manager.dart
import 'dart:collection';
import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';

/// Manages pinning operations to prevent content from garbage collection.
///
/// Supports direct pins (single block) and recursive pins (block + all refs).
/// Tracks access times for cache eviction policies.
///
/// Example:
/// ```dart
/// final manager = PinManager(blockStore);
/// await manager.pinBlock(cidProto, PinTypeProto.PIN_TYPE_RECURSIVE);
/// ```
class PinManager {
  final Map<String, PinTypeProto> _pins = {};
  final Map<String, Set<String>> _references = {};
  final Map<String, DateTime> _accessTimes = {};
  final BlockStore _blockStore;

  /// Creates a pin manager backed by [_blockStore].
  PinManager(this._blockStore);

  Future<bool> pinBlock(IPFSCIDProto cidProto, PinTypeProto type) async {
    if (type == PinTypeProto.PIN_TYPE_RECURSIVE) {
      return await _pinRecursive(cidProto);
    } else if (type == PinTypeProto.PIN_TYPE_DIRECT) {
      _pins[cidProto.toString()] = type;
      return true;
    }
    return false;
  }

  Future<bool> _pinRecursive(IPFSCIDProto cid) async {
    final Set<String> visited = {};
    final Queue<String> queue = Queue();
    final String cidStr = cid.toString();

    _pins[cidStr] = PinTypeProto.PIN_TYPE_RECURSIVE;
    queue.add(cidStr);

    while (queue.isNotEmpty) {
      final currentCid = queue.removeFirst();
      if (visited.contains(currentCid)) continue;

      visited.add(currentCid);

      final references = await _getBlockReferences(currentCid);
      if (references != null) {
        _references[currentCid] = references;

        for (final refCid in references) {
          if (!visited.contains(refCid)) {
            queue.add(refCid);
            if (!_pins.containsKey(refCid)) {
              _pins[refCid] = PinTypeProto.PIN_TYPE_RECURSIVE;
            }
          }
        }
      }
    }

    return true;
  }

  Future<Set<String>?> _getBlockReferences(String cidStr) async {
    try {
      final cidProto = IPFSCIDProto()
        ..codec = 'raw'
        ..multihash = Uint8List.fromList(cidStr.codeUnits)
        ..version = IPFSCIDVersion.IPFS_CID_VERSION_1;

      final blockResult = await _blockStore.getBlock(cidProto.toString());

      // Early return if block not found or doesn't have a block
      if (!blockResult.found || !blockResult.hasBlock()) {
        return null;
      }

      final references = Set<String>();
      final format = blockResult.block.format;

      switch (format) {
        case 'dag-pb':
          final dagNode = MerkleDAGNode.fromBytes(
              Uint8List.fromList(blockResult.block.data));
          for (final link in dagNode.links) {
            references.add(link.cid.toString());
          }
          break;

        case 'dag-cbor':
          final decoded =
              await _decodeCbor(Uint8List.fromList(blockResult.block.data));
          references.addAll(_extractCborReferences(decoded));
          break;

        case 'raw':
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

  Future<dynamic> _decodeCbor(Uint8List data) async {
    try {
      return CborSimpleDecoder().convert(data);
    } catch (e) {
      throw FormatException('Failed to decode CBOR data: $e');
    }
  }

  Set<String> _extractCborReferences(dynamic decoded) {
    final references = Set<String>();

    if (decoded is Map) {
      for (final value in decoded.values) {
        if (value is Map && value.containsKey('/')) {
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

  bool isBlockPinned(IPFSCIDProto cid) {
    final cidStr = cid.toString();
    return _pins.containsKey(cidStr) || _isIndirectlyPinned(cidStr);
  }

  bool _isIndirectlyPinned(String cidStr) {
    return _references.entries
        .where((entry) => _pins[entry.key] == PinTypeProto.PIN_TYPE_RECURSIVE)
        .any((entry) => entry.value.contains(cidStr));
  }

  Future<bool> unpinBlock(IPFSCIDProto cid) async {
    final cidStr = cid.toString();
    if (!_pins.containsKey(cidStr)) {
      return false;
    }

    if (_pins[cidStr] == PinTypeProto.PIN_TYPE_RECURSIVE) {
      final referencedBlocks = _references[cidStr] ?? <String>{};
      for (final refCid in referencedBlocks) {
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

  List<IPFSCIDProto> getPinnedBlocks() {
    final pinnedBlocks = <IPFSCIDProto>[];

    for (final entry in _pins.entries) {
      if (entry.value == PinTypeProto.PIN_TYPE_DIRECT ||
          entry.value == PinTypeProto.PIN_TYPE_RECURSIVE) {
        try {
          pinnedBlocks.add(_stringToIPFSCIDProto(entry.key));
        } catch (e) {
          print('Warning: Skipping invalid CID: ${entry.key}');
          continue;
        }
      }
    }

    return pinnedBlocks;
  }

  IPFSCIDProto _stringToIPFSCIDProto(String cidStr) {
    try {
      final cid = CID.decode(cidStr);
      return cid.toProto();
    } catch (e) {
      throw FormatException('Invalid CID string format: $cidStr');
    }
  }

  DateTime? getBlockAccessTime(String cidStr) {
    return _accessTimes[cidStr];
  }

  void setBlockAccessTime(String cidStr, DateTime time) {
    _accessTimes[cidStr] = time;
  }

  void removeBlockAccessTime(String cidStr) {
    _accessTimes.remove(cidStr);
  }

  /// Returns the total number of pinned blocks
  int get pinnedBlockCount {
    final directPins = _pins.values
        .where((type) =>
            type == PinTypeProto.PIN_TYPE_DIRECT ||
            type == PinTypeProto.PIN_TYPE_RECURSIVE)
        .length;

    // Count indirectly pinned blocks from recursive pins
    final indirectPins = _references.entries
        .where((entry) => _pins[entry.key] == PinTypeProto.PIN_TYPE_RECURSIVE)
        .fold<Set<String>>({}, (acc, entry) => acc..addAll(entry.value)).length;

    return directPins + indirectPins;
  }
}
