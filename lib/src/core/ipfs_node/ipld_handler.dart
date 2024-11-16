// src/core/ipfs_node/ipld_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/extensions/ipld_node_json.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/core/ipld/jose_cose_handler.dart';

/// Handles IPLD (InterPlanetary Linked Data) operations
class IPLDHandler {
  final IPFSConfig _config;
  final BlockStore _blockStore;
  final Map<String, IPLDSchema> _schemas = {};
  late final Logger _logger;

  IPLDHandler(this._config, this._blockStore) {
    _logger = Logger('IPLDHandler',
        debug: _config.debug, verbose: _config.verboseLogging);
  }

  /// Puts a value into the blockstore
  Future<Block> put(dynamic value,
      {String codec = 'dag-cbor', String? schemaType}) async {
    try {
      final ipldNode = _toIPLDNode(value);

      // Validate against schema if specified
      if (schemaType != null) {
        final schema = _schemas[schemaType];
        if (schema == null) {
          throw IPLDSchemaError('Schema not found: $schemaType');
        }

        final isValid = await schema.validate(schemaType, ipldNode);
        if (!isValid) {
          throw IPLDSchemaError('Data does not match schema: $schemaType');
        }
      }

      final (encoded, cid) = await _encodeData(ipldNode, codec);
      final block = await Block.fromData(encoded, format: codec);
      await _blockStore.putBlock(block);
      return block;
    } catch (e) {
      _logger.error('Failed to put IPLD data', e);
      rethrow;
    }
  }

  /// Gets a value from the blockstore
  Future<dynamic> get(CID cid) async {
    try {
      final block = await _blockStore.getBlock(cid.toString());
      return await _decodeData(Uint8List.fromList(block.block.data), cid.codec);
    } catch (e) {
      _logger.error('Failed to get IPLD data', e);
      rethrow;
    }
  }

  /// Resolves a path through IPLD data
  Future<dynamic> resolve(CID root, String path) async {
    if (path.isEmpty) return await get(root);

    final segments = path.split('/');
    var node = await get(root);

    for (final segment in segments) {
      if (segment.isEmpty) continue;

      if (node is List) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= node.length) {
          throw IPLDResolutionError('Invalid array index: $segment');
        }
        node = node[index];
        continue;
      }

      if (node is Map) {
        if (!node.containsKey(segment)) {
          throw IPLDResolutionError('Property not found: $segment');
        }
        final value = node[segment];
        if (value is String && value.startsWith('ipfs://')) {
          return await get(CID.decode(value.substring(7)));
        }
        node = value;
        continue;
      }

      throw IPLDResolutionError('Cannot traverse: invalid node type');
    }

    return node;
  }

  /// Encodes data using the specified codec
  Future<(Uint8List, CID)> _encodeData(IPLDNode node, String codec) async {
    Uint8List encoded;

    switch (codec) {
      case 'raw':
        if (node.kind != Kind.BYTES) {
          throw IPLDEncodingError('Raw codec requires bytes data');
        }
        encoded = Uint8List.fromList(node.bytesValue);
        break;

      case 'dag-pb':
        try {
          final dagNode = await _convertToMerkleDAGNode(node);
          encoded = dagNode.toBytes();
        } catch (e) {
          throw IPLDEncodingError('Failed to encode DAG-PB: $e');
        }
        break;

      case 'dag-cbor':
        try {
          encoded = await EnhancedCBORHandler.encodeCbor(node);
        } catch (e) {
          throw IPLDEncodingError('Failed to encode CBOR: $e');
        }
        break;

      case 'dag-json':
        try {
          encoded = Uint8List.fromList(utf8.encode(node.toJson()));
        } catch (e) {
          throw IPLDEncodingError('Failed to encode JSON: $e');
        }
        break;

      case 'dag-jose':
        try {
          encoded = await _encodeJose(node);
        } catch (e) {
          throw IPLDEncodingError('Failed to encode JOSE: $e');
        }
        break;

      case 'car':
        try {
          encoded = await _encodeCAR(node);
        } catch (e) {
          throw IPLDEncodingError('Failed to encode CAR: $e');
        }
        break;

      case 'wasm':
        if (node.kind != Kind.BYTES) {
          throw IPLDEncodingError('WASM codec requires bytes data');
        }
        encoded = Uint8List.fromList(node.bytesValue);
        break;
      default:
        throw UnsupportedError('Unsupported codec: $codec');
    }

    final cid = await CID.computeForData(encoded, codec: codec);
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
          return EnhancedCBORHandler.convertFromMerkleDAGNode(dagNode);
        } catch (e) {
          throw IPLDDecodingError('Failed to decode DAG-PB: $e');
        }

      case 'dag-cbor':
        try {
          return await EnhancedCBORHandler.decodeCborWithTags(data);
        } catch (e) {
          throw IPLDDecodingError('Failed to decode CBOR: $e');
        }

      case 'dag-json':
        try {
          return IPLDNode.fromJson(utf8.decode(data));
        } catch (e) {
          throw IPLDDecodingError('Failed to decode JSON: $e');
        }

      case 'dag-jose':
        try {
          return await _decodeJose(data);
        } catch (e) {
          throw IPLDDecodingError('Failed to decode JOSE: $e');
        }

      default:
        throw UnsupportedError('Unsupported codec: $codec');
    }
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
      return EnhancedCBORHandler.convertToMerkleLink(linkNode);
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
      'supported_codecs': EncodingUtils.supportedCodecs,
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

        case SelectorType.exploreRecursive:
          if (currentSelector.maxDepth != null &&
              visited.length > currentSelector.maxDepth!) {
            return;
          }
          results.add(node);
          if (node is Map) {
            for (final value in node.values) {
              if (value is String && value.startsWith('ipfs://')) {
                final linkedCid = CID.decode(value.substring(7));
                await traverse(linkedCid, currentSelector);
              }
            }
          }
          break;

        case SelectorType.exploreUnion:
          for (final subSelector in currentSelector.subSelectors ?? []) {
            await traverse(cid, subSelector);
          }
          break;

        case SelectorType.exploreAll:
          results.add(node);
          if (node is Map) {
            for (final value in node.values) {
              if (value is String && value.startsWith('ipfs://')) {
                final linkedCid = CID.decode(value.substring(7));
                await traverse(linkedCid, currentSelector);
              }
            }
          }
          break;

        case SelectorType.exploreRange:
          if (node is List) {
            final start = currentSelector.startIndex ?? 0;
            final end = currentSelector.endIndex ?? node.length;
            for (var i = start; i < end && i < node.length; i++) {
              final value = node[i];
              if (value is String && value.startsWith('ipfs://')) {
                final linkedCid = CID.decode(value.substring(7));
                await traverse(linkedCid, currentSelector.subSelectors!.first);
              }
            }
          }
          break;

        case SelectorType.exploreFields:
          if (node is Map) {
            for (final field in currentSelector.fields ?? []) {
              final value = node[field];
              if (value is String && value.startsWith('ipfs://')) {
                final linkedCid = CID.decode(value.substring(7));
                await traverse(linkedCid, currentSelector.subSelectors!.first);
              }
            }
          }
          break;

        case SelectorType.exploreIndex:
          if (node is List) {
            final index = currentSelector.startIndex ?? 0;
            if (index >= 0 && index < node.length) {
              final value = node[index];
              if (value is String && value.startsWith('ipfs://')) {
                final linkedCid = CID.decode(value.substring(7));
                await traverse(linkedCid, currentSelector.subSelectors!.first);
              }
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
      return EnhancedCBORHandler.convertFromMerkleDAGNode(value);
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

  Future<Uint8List> _encodeJose(IPLDNode node) async {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('JOSE encoding requires a map structure');
    }

    final header =
        node.mapValue.entries.firstWhere((e) => e.key == 'header').value;

    final algorithm = header.mapValue.entries
        .firstWhere((e) => e.key == 'alg')
        .value
        .stringValue;

    switch (algorithm) {
      case 'JWS':
        return await JoseCoseHandler.encodeJWS(
            node, _config.keystore.privateKey);
      case 'JWE':
        final recipientKey = await _getRecipientKey(node);
        return await JoseCoseHandler.encodeJWE(node, recipientKey);
      case 'COSE':
        return await JoseCoseHandler.encodeCOSE(
            node, _config.keystore.privateKey);
      default:
        throw IPLDEncodingError('Unsupported JOSE algorithm: $algorithm');
    }
  }

  Future<IPLDNode> _decodeJose(Uint8List data) async {
    final joseData = json.decode(utf8.decode(data));

    final header =
        json.decode(utf8.decode(base64Url.decode(joseData['protected'])));
    final payload = base64Url.decode(joseData['payload']);

    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()
        ..entries.addAll([
          MapEntry()
            ..key = 'header'
            ..value = (IPLDNode()
              ..kind = Kind.MAP
              ..mapValue = (IPLDMap()
                ..entries.addAll([
                  MapEntry()
                    ..key = 'alg'
                    ..value = (IPLDNode()
                      ..kind = Kind.STRING
                      ..stringValue = header['alg']),
                ]))),
          MapEntry()
            ..key = 'payload'
            ..value = (IPLDNode()
              ..kind = Kind.BYTES
              ..bytesValue = payload),
        ]));
  }

  /// Registers an IPLD schema
  void registerSchema(String name, Map<String, dynamic> schema) {
    _schemas[name] = IPLDSchema(name, schema);
  }

  Future<List<int>> _getRecipientKey(IPLDNode node) async {
    final header =
        node.mapValue.entries.firstWhere((e) => e.key == 'header').value;
    final recipientEntry =
        header.mapValue.entries.firstWhere((e) => e.key == 'recipient');

    if (recipientEntry.value.kind != Kind.BYTES) {
      throw IPLDEncodingError('Recipient key must be bytes');
    }

    return recipientEntry.value.bytesValue.toList();
  }

  /// Encodes an IPLD node to CAR format
  Future<Uint8List> _encodeCAR(IPLDNode node) async {
    final output = BytesBuilder();

    // Write CAR header (version 1)
    output.addByte(1); // version
    output.addByte(1); // characteristics

    // Write roots section
    final rootCid = await CID.computeForData(
        await EnhancedCBORHandler.encodeCbor(node),
        codec: 'dag-cbor');

    // Write number of roots (1)
    output.addByte(1);
    output.add(rootCid.toBytes());

    // Write the blocks section
    await _writeCarBlock(node, output);

    return output.toBytes();
  }

  /// Writes a node and its linked blocks to the CAR output
  Future<void> _writeCarBlock(IPLDNode node, BytesBuilder output) async {
    // Encode the node
    final encoded = await EnhancedCBORHandler.encodeCbor(node);
    final cid = await CID.computeForData(encoded, codec: 'dag-cbor');

    // Write block header
    final cidBytes = cid.toBytes();
    output.add(_encodeVarint(cidBytes.length));
    output.add(cidBytes);

    // Write block data
    output.add(_encodeVarint(encoded.length));
    output.add(encoded);

    // Recursively write linked blocks
    if (node.kind == Kind.MAP) {
      for (final entry in node.mapValue.entries) {
        if (entry.value.kind == Kind.LINK) {
          final linkedBlock =
              await _blockStore.getBlock(entry.value.linkValue.toString());
          final linkedNode = await _decodeData(
              Uint8List.fromList(linkedBlock.block.data),
              entry.value.linkValue.codec);
          await _writeCarBlock(linkedNode, output);
        }
      }
    }
  }

  /// Encodes an integer as a varint
  List<int> _encodeVarint(int value) {
    final bytes = <int>[];
    while (value >= 0x80) {
      bytes.add((value & 0x7f) | 0x80);
      value >>= 7;
    }
    bytes.add(value & 0x7f);
    return bytes;
  }
}
