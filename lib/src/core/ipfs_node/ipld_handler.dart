// src/core/ipfs_node/ipld_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart'
    show MerkleDAGNode;
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:fixnum/fixnum.dart';

/// Handles IPLD (InterPlanetary Linked Data) operations for an IPFS node.
class IPLDHandler {
  final BlockStore _blockStore;
  final IPFSConfig _config;
  late final Logger _logger;

  // Supported IPLD codecs with their multicodec codes
  static const Map<String, int> CODECS = {
    'raw': 0x55,
    'dag-pb': 0x70,
    'dag-cbor': 0x71,
    'dag-json': 0x0129,
  };

  IPLDHandler(this._blockStore, this._config) {
    _logger = Logger('IPLDHandler');
    _logger.debug('Creating new IPLDHandler instance');
  }

  /// Creates a CID for the given data and codec
  Future<CID> _createCID(Uint8List data, String codec) async {
    return CID.computeForData(data, codec: codec);
  }

  /// Encodes data using the specified codec
  Future<(Uint8List, CID)> _encodeData(IPLDNode node, String codec) async {
    late Uint8List encoded;

    switch (codec) {
      case 'raw':
        if (node.kind != Kind.BYTES) {
          throw IPLDEncodingError('Raw codec requires bytes data');
        }
        encoded = Uint8List.fromList(node.bytesValue);
        break;

      case 'dag-pb':
        if (node.kind != Kind.MAP) {
          throw IPLDEncodingError('DAG-PB codec requires map data');
        }
        final dagNode = await _convertToMerkleDAGNode(node);
        encoded = dagNode.toBytes();
        break;

      case 'dag-cbor':
        try {
          encoded = Uint8List.fromList(node.writeToBuffer());
        } catch (e) {
          throw IPLDEncodingError('Failed to encode CBOR: $e');
        }
        break;

      case 'dag-json':
        try {
          encoded = Uint8List.fromList(utf8.encode(node.writeToJson()));
        } catch (e) {
          throw IPLDEncodingError('Failed to encode JSON: $e');
        }
        break;

      default:
        throw UnsupportedError('Unsupported codec: $codec');
    }

    final cid = await _createCID(encoded, codec);
    return (encoded, cid);
  }

  /// Decodes data using the specified codec
  Future<IPLDNode> _decodeData(Uint8List data, String codec) async {
    switch (codec) {
      case 'raw':
        return IPLDNode()
          ..kind = Kind.BYTES
          ..bytesValue = data;

      case 'dag-pb':
        try {
          final dagNode = MerkleDAGNode.fromBytes(data);
          return _convertFromMerkleDAGNode(dagNode);
        } catch (e) {
          throw IPLDDecodingError('Failed to decode DAG-PB: $e');
        }

      case 'dag-cbor':
        try {
          return IPLDNode.fromBuffer(data);
        } catch (e) {
          throw IPLDDecodingError('Failed to decode CBOR: $e');
        }

      case 'dag-json':
        try {
          return IPLDNode.fromJson(utf8.decode(data));
        } catch (e) {
          throw IPLDDecodingError('Failed to decode JSON: $e');
        }

      default:
        throw UnsupportedError('Unsupported codec: $codec');
    }
  }

  /// Puts a node into the blockstore with the specified codec
  Future<Block> put(
    dynamic value, {
    String codec = 'dag-cbor',
    String? hashAlg,
  }) async {
    try {
      // Convert to protobuf IPLDNode
      final ipldNode = _toIPLDNode(value);
      final (encoded, cid) = await _encodeData(ipldNode, codec);

      final block = await Block.fromData(encoded, format: codec);
      await _blockStore.putBlock(block);
      return block;
    } catch (e) {
      _logger.error('Failed to put IPLD data', e);
      rethrow;
    }
  }

  /// Gets and decodes a node from the blockstore
  Future<dynamic> get(CID cid) async {
    try {
      final block = await _blockStore.getBlock(cid.toString());
      final decoded =
          await _decodeData(Uint8List.fromList(block.block.data), cid.codec);
      return _toIPLDNode(decoded);
    } catch (e) {
      _logger.error('Failed to get IPLD data', e);
      rethrow;
    }
  }

  /// Resolves an IPLD path
  Future<dynamic> resolve(String path) async {
    _logger.debug('Resolving IPLD path: $path');

    try {
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        throw IPLDResolutionError('Empty path');
      }

      final rootCid = CID.decode(segments[0]);
      var current = await get(rootCid);

      for (var i = 1; i < segments.length && current != null; i++) {
        current = await _resolvePathSegment(current, segments[i]);
      }

      return current;
    } catch (e, stackTrace) {
      _logger.error('Failed to resolve path', e, stackTrace);
      rethrow;
    }
  }

  /// Resolves a single path segment within an IPLD node
  Future<dynamic> _resolvePathSegment(dynamic node, String segment) async {
    if (node is MerkleDAGNode) {
      final link = node.links.firstWhere(
        (l) => l.name == segment,
        orElse: () => throw IPLDResolutionError('Link not found: $segment'),
      );
      return await get(CID.decode(link.cid.toString()));
    }

    if (node is Map) {
      if (!node.containsKey(segment)) {
        throw IPLDResolutionError('Property not found: $segment');
      }
      final value = node[segment];
      if (value is String && value.startsWith('ipfs://')) {
        return await get(CID.decode(value.substring(7)));
      }
      return value;
    }

    throw IPLDResolutionError('Cannot traverse: invalid node type');
  }

  /// Starts the IPLD handler
  Future<void> start() async {
    _logger.debug('Starting IPLDHandler...');
    try {
      // Initialize codec support
      _logger.verbose('Initializing IPLD codecs');
      // Additional initialization if needed
      _logger.debug('IPLDHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPLDHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the IPLD handler
  Future<void> stop() async {
    _logger.debug('Stopping IPLDHandler...');
    try {
      // Cleanup if needed
      _logger.debug('IPLDHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop IPLDHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Gets the status of the IPLD handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'supported_codecs': CODECS.keys.toList(),
      'enabled': _config.enableIPLD,
    };
  }

  /// Executes a selector query on an IPLD node
  Future<List<dynamic>> executeSelector(
      CID rootCid, IPLDSelector selector) async {
    final results = <dynamic>[];
    final visited = <String>{};

    Future<void> traverse(CID cid, IPLDSelector currentSelector) async {
      if (visited.contains(cid.toString())) return;
      visited.add(cid.toString());

      final node = await get(cid);
      if (node == null) return;

      switch (currentSelector.type) {
        case SelectorType.all:
          results.add(node);
          if (node is MerkleDAGNode) {
            for (final link in node.links) {
              await traverse(CID.decode(link.cid.toString()), currentSelector);
            }
          }
          break;

        case SelectorType.none:
          // None selector explicitly matches nothing
          break;

        case SelectorType.matcher:
          if (_matchesCriteria(node, currentSelector.criteria)) {
            results.add(node);
          }
          break;

        case SelectorType.explore:
          // Explore selector traverses specific paths
          if (currentSelector.fieldPath != null) {
            final value = _resolveFieldPath(node, currentSelector.fieldPath!);
            if (value != null &&
                value is String &&
                value.startsWith('ipfs://')) {
              final linkedCid = CID.decode(value.substring(7));
              for (final subSelector in currentSelector.subSelectors ?? []) {
                await traverse(linkedCid, subSelector);
              }
            }
          }
          break;

        case SelectorType.recursive:
          if (currentSelector.maxDepth != null &&
              visited.length > currentSelector.maxDepth!) {
            return;
          }

          if (currentSelector.subSelectors?.isNotEmpty ?? false) {
            final subSelector = currentSelector.subSelectors!.first;
            if (_matchesCriteria(node, subSelector.criteria)) {
              results.add(node);
            }
          }

          if (node is MerkleDAGNode && !(currentSelector.stopAtLink ?? false)) {
            for (final link in node.links) {
              await traverse(CID.decode(link.cid.toString()), currentSelector);
            }
          }
          break;

        case SelectorType.union:
          for (final subSelector in currentSelector.subSelectors ?? []) {
            await traverse(cid, subSelector);
          }
          break;

        case SelectorType.intersection:
          final matchesAll =
              (currentSelector.subSelectors ?? []).every((subSelector) {
            return _matchesCriteria(node, subSelector.criteria);
          });
          if (matchesAll) {
            results.add(node);
          }
          break;

        case SelectorType.condition:
          // Condition selector evaluates a condition before traversing
          if (_matchesCriteria(node, currentSelector.criteria)) {
            for (final subSelector in currentSelector.subSelectors ?? []) {
              await traverse(cid, subSelector);
            }
          }
          break;
      }
    }

    await traverse(rootCid, selector);
    return results;
  }

  bool _matchesCriteria(dynamic node, Map<String, dynamic> criteria) {
    if (criteria.isEmpty) return true;

    for (final entry in criteria.entries) {
      final value = _resolveFieldPath(node, entry.key);
      if (!_matchesValue(value, entry.value)) {
        return false;
      }
    }
    return true;
  }

  dynamic _resolveFieldPath(dynamic node, String path) {
    final parts = path.split('.');
    dynamic current = node;

    for (final part in parts) {
      if (current == null) return null;
      if (current is Map) {
        current = current[part];
      } else if (current is MerkleDAGNode) {
        switch (part) {
          case 'cid':
            current = current.cid;
            break;
          case 'links':
            current = current.links;
            break;
          case 'data':
            current = current.data;
            break;
          default:
            current = null;
        }
      } else {
        return null;
      }
    }
    return current;
  }

  bool _matchesValue(dynamic value, dynamic criterion) {
    if (criterion is Map && criterion.containsKey('\$regex')) {
      final pattern = RegExp(criterion['\$regex']);
      return value is String && pattern.hasMatch(value);
    }

    if (criterion is Map && criterion.containsKey('\$gt')) {
      return value is num && value > criterion['\$gt'];
    }

    if (criterion is Map && criterion.containsKey('\$lt')) {
      return value is num && value < criterion['\$lt'];
    }

    return value == criterion;
  }

  Future<MerkleDAGNode> _convertToMerkleDAGNode(IPLDNode node) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('Cannot convert non-map to MerkleDAGNode');
    }

    final data = node.mapValue.entries
        .firstWhere((e) => e.key == 'Data', orElse: () => MapEntry())
        .value
        .bytesValue;

    final linkEntries = node.mapValue.entries
        .firstWhere((e) => e.key == 'Links', orElse: () => MapEntry())
        .value
        .listValue
        .values;

    final List<Link> links = linkEntries.map((linkNode) {
      if (linkNode.kind != Kind.MAP) {
        throw IPLDEncodingError('Invalid link format');
      }
      return _convertToMerkleLink(linkNode);
    }).toList();

    return MerkleDAGNode(
      cid: await CID.computeForData(Uint8List.fromList(data), codec: 'dag-pb'),
      links: links,
      data: Uint8List.fromList(data),
      size: data.length,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: {},
      isDirectory: false,
    );
  }

  IPLDNode _convertFromMerkleDAGNode(MerkleDAGNode dagNode) {
    final links = IPLDList()
      ..values.addAll(
        dagNode.links.map(_convertFromMerkleLink),
      );

    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()
        ..entries.addAll([
          MapEntry()
            ..key = 'Data'
            ..value = (IPLDNode()
              ..kind = Kind.BYTES
              ..bytesValue = dagNode.data),
          MapEntry()
            ..key = 'Links'
            ..value = (IPLDNode()
              ..kind = Kind.LIST
              ..listValue = links),
        ]));
  }

  Link _convertToMerkleLink(IPLDNode node) {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('Cannot convert non-map to Link');
    }

    final map = node.mapValue.entries;
    return Link(
      name: map.firstWhere((e) => e.key == 'Name').value.stringValue,
      cid: Uint8List.fromList(
          map.firstWhere((e) => e.key == 'Cid').value.bytesValue),
      hash: Uint8List.fromList(
          map.firstWhere((e) => e.key == 'Hash').value.bytesValue),
      size: map.firstWhere((e) => e.key == 'Size').value.intValue.toInt(),
      metadata: map
          .firstWhere((e) => e.key == 'Metadata', orElse: () => MapEntry())
          .value
          .mapValue
          .entries
          .fold<Map<String, String>>(
              {}, (map, e) => map..[e.key] = e.value.stringValue),
    );
  }

  IPLDNode _convertFromMerkleLink(Link link) {
    final entries = [
      MapEntry()
        ..key = 'Name'
        ..value = (IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = link.name),
      MapEntry()
        ..key = 'Cid'
        ..value = (IPLDNode()
          ..kind = Kind.BYTES
          ..bytesValue = link.cid),
      MapEntry()
        ..key = 'Hash'
        ..value = (IPLDNode()
          ..kind = Kind.BYTES
          ..bytesValue = link.hash),
      MapEntry()
        ..key = 'Size'
        ..value = (IPLDNode()
          ..kind = Kind.INTEGER
          ..intValue = link.size),
    ];

    if (link.metadata != null) {
      entries.add(
        MapEntry()
          ..key = 'Metadata'
          ..value = (IPLDNode()
            ..kind = Kind.MAP
            ..mapValue = (IPLDMap()
              ..entries.addAll(
                link.metadata!.entries.map(
                  (e) => MapEntry()
                    ..key = e.key
                    ..value = (IPLDNode()
                      ..kind = Kind.STRING
                      ..stringValue = e.value),
                ),
              ))),
      );
    }

    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()..entries.addAll(entries));
  }

  IPLDNode _toIPLDNode(dynamic value) {
    final node = IPLDNode();

    if (value == null) {
      node.kind = Kind.NULL;
    } else if (value is bool) {
      node.kind = Kind.BOOL;
      node.boolValue = value;
    } else if (value is int) {
      if (value >= -9223372036854775808 && value <= 9223372036854775807) {
        node.kind = Kind.INTEGER;
        node.intValue = Int64(value);
      } else {
        node.kind = Kind.BIG_INT;
        node.bigIntValue = _encodeBigInt(BigInt.from(value));
      }
    } else if (value is BigInt) {
      node.kind = Kind.BIG_INT;
      node.bigIntValue = _encodeBigInt(value);
    } else if (value is double) {
      node.kind = Kind.FLOAT;
      node.floatValue = value;
    } else if (value is String) {
      node.kind = Kind.STRING;
      node.stringValue = value;
    } else if (value is Uint8List) {
      node.kind = Kind.BYTES;
      node.bytesValue = value;
    } else if (value is List) {
      node.kind = Kind.LIST;
      node.listValue = IPLDList()
        ..values.addAll(
          value.map((e) => _toIPLDNode(e)),
        );
    } else if (value is Map) {
      node.kind = Kind.MAP;
      node.mapValue = IPLDMap()
        ..entries.addAll(
          value.entries.map(
            (e) => MapEntry()
              ..key = e.key.toString()
              ..value = _toIPLDNode(e.value),
          ),
        );
    } else if (value is CID) {
      node.kind = Kind.LINK;
      node.linkValue = IPLDLink()
        ..version = value.version.value
        ..codec = value.codec
        ..multihash = value.multihash;
    } else if (value is MerkleDAGNode) {
      return _convertFromMerkleDAGNode(value);
    } else {
      throw IPLDEncodingError('Unsupported value type: ${value.runtimeType}');
    }

    return node;
  }

  Uint8List _encodeBigInt(BigInt value) {
    // Convert to bytes in big-endian order
    var isNegative = value.isNegative;
    var bytes = (isNegative ? -value : value).toRadixString(16).padLeft(2, '0');
    if (bytes.length % 2 != 0) bytes = '0$bytes';

    var result = Uint8List(bytes.length ~/ 2 + 1);
    for (var i = 0; i < bytes.length; i += 2) {
      result[1 + i ~/ 2] = int.parse(bytes.substring(i, i + 2), radix: 16);
    }
    result[0] = isNegative ? 1 : 0;
    return result;
  }
}
