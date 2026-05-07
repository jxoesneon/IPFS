// src/core/data_structures/pin_manager.dart
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/cid.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:path/path.dart' as p;

/// Manages pinning operations to prevent content from garbage collection.
class PinManager {
  /// Creates a pin manager backed by [_blockStore].
  PinManager(this._blockStore) : _logger = Logger('PinManager');
  final Map<String, PinTypeProto> _pins = {};
  final Map<String, Set<String>> _references = {};
  final BlockStore _blockStore;
  final Logger _logger;

  /// Loads the pin state from a file.
  Future<void> load(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final Map<String, dynamic> data =
          json.decode(content) as Map<String, dynamic>;

      if (data.containsKey('pins')) {
        final pinsData = data['pins'] as Map<String, dynamic>;
        pinsData.forEach((cid, typeIndex) {
          _pins[cid] =
              PinTypeProto.valueOf(typeIndex as int) ??
              PinTypeProto.PIN_TYPE_RECURSIVE;
        });
      }

      if (data.containsKey('references')) {
        final refsData = data['references'] as Map<String, dynamic>;
        refsData.forEach((cid, refs) {
          _references[cid] = Set<String>.from(refs as Iterable);
        });
      }

      _logger.info('Loaded ${_pins.length} pins from $path');
    } catch (e) {
      _logger.error('Failed to load pins from $path', e);
    }
  }

  /// Saves the pin state to a file.
  Future<void> save(String path) async {
    try {
      final data = {
        'pins': _pins.map((k, v) => MapEntry(k, v.value)),
        'references': _references.map((k, v) => MapEntry(k, v.toList())),
      };

      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(json.encode(data));
      _logger.debug('Saved ${_pins.length} pins to $path');
    } catch (e) {
      _logger.error('Failed to save pins to $path', e);
    }
  }

  /// Pins a block with the specified type (direct or recursive).
  Future<bool> pinBlock(IPFSCIDProto cidProto, PinTypeProto type) async {
    final cidStr = CID.fromProto(cidProto).encode();
    bool success = false;

    if (type == PinTypeProto.PIN_TYPE_RECURSIVE) {
      success = await _pinRecursive(cidProto);
    } else if (type == PinTypeProto.PIN_TYPE_DIRECT) {
      _pins[cidStr] = type;
      success = true;
    }

    if (success) {
      // Auto-save pin state
      await save(p.join(_blockStore.path, 'pins.json'));
    }
    return success;
  }

  Future<bool> _pinRecursive(IPFSCIDProto cid) async {
    final Set<String> visited = {};
    final Queue<String> queue = Queue();
    final String cidStr = CID.fromProto(cid).encode();

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
      final blockResult = await _blockStore.getBlock(cidStr);

      if (!blockResult.found || blockResult.block.data.isEmpty) {
        return null;
      }

      final references = <String>{};
      final format = blockResult.block.format;

      switch (format) {
        case 'dag-pb':
          final dagNode = MerkleDAGNode.fromBytes(
            Uint8List.fromList(blockResult.block.data),
          );
          for (final link in dagNode.links) {
            references.add(link.cid.toString());
          }
          break;

        case 'dag-cbor':
          final decoded = await _decodeCbor(
            Uint8List.fromList(blockResult.block.data),
          );
          references.addAll(_extractCborReferences(decoded));
          break;

        case 'raw':
          break;

        default:
          throw UnsupportedError('Unsupported block format: $format');
      }

      return references;
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> _decodeCbor(Uint8List data) async {
    try {
      return const CborSimpleDecoder().convert(data);
    } catch (e) {
      throw FormatException('Failed to decode CBOR data: $e');
    }
  }

  Set<String> _extractCborReferences(dynamic decoded) {
    final references = <String>{};

    if (decoded is Map) {
      if (decoded.containsKey('/')) {
        final linkValue = decoded['/'];
        if (linkValue is String) {
          references.add(linkValue);
        }
        return references;
      }
      for (final value in decoded.values) {
        references.addAll(_extractCborReferences(value));
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        references.addAll(_extractCborReferences(item));
      }
    }

    return references;
  }

  /// Returns whether the block is pinned (directly or indirectly).
  bool isBlockPinned(IPFSCIDProto cid) {
    final cidStr = CID.fromProto(cid).encode();
    return _pins.containsKey(cidStr) || _isIndirectlyPinned(cidStr);
  }

  bool _isIndirectlyPinned(String cidStr) {
    return _references.entries
        .where((entry) => _pins[entry.key] == PinTypeProto.PIN_TYPE_RECURSIVE)
        .any((entry) => entry.value.contains(cidStr));
  }

  /// Unpins a block and its recursively pinned references.
  Future<bool> unpinBlock(IPFSCIDProto cid) async {
    final cidStr = CID.fromProto(cid).encode();
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

    // Auto-save pin state
    await save(p.join(_blockStore.path, 'pins.json'));

    return true;
  }

  /// Returns a list of all directly and recursively pinned blocks.
  List<IPFSCIDProto> getPinnedBlocks() {
    final pinnedBlocks = <IPFSCIDProto>[];

    for (final entry in _pins.entries) {
      if (entry.value == PinTypeProto.PIN_TYPE_DIRECT ||
          entry.value == PinTypeProto.PIN_TYPE_RECURSIVE) {
        try {
          pinnedBlocks.add(_stringToIPFSCIDProto(entry.key));
        } catch (e) {
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

  /// Returns the total number of pinned blocks
  int get pinnedBlockCount {
    final directPins = _pins.values
        .where(
          (type) =>
              type == PinTypeProto.PIN_TYPE_DIRECT ||
              type == PinTypeProto.PIN_TYPE_RECURSIVE,
        )
        .length;

    final indirectPins = _references.entries
        .where((entry) => _pins[entry.key] == PinTypeProto.PIN_TYPE_RECURSIVE)
        .fold<Set<String>>({}, (acc, entry) => acc..addAll(entry.value))
        .where((ref) => !_pins.containsKey(ref))
        .length;

    return directPins + indirectPins;
  }
}
