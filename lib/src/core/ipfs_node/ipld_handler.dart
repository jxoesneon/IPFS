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
import 'package:dart_ipfs/src/core/data_structures/metadata.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/ipld/extensions/ipld_node_json.dart';
import 'package:dart_ipfs/src/core/ipld/jose_cose_handler.dart';
import 'package:dart_ipfs/src/core/ipld/path/ipld_path_handler.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_multihash/dart_multihash.dart' as multihash_lib;
import 'package:fixnum/fixnum.dart';

/// Handles IPLD (InterPlanetary Linked Data) operations
class IPLDHandler {

  IPLDHandler(this._config, this._blockStore) {
    _logger = Logger(
      'IPLDHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
  }
  final IPFSConfig _config;
  final BlockStore _blockStore;
  final Map<String, IPLDSchema> _schemas = {};
  late final Logger _logger;

  /// Puts a value into the blockstore
  Future<Block> put(
    dynamic value, {
    String codec = 'dag-cbor',
    String? schemaType,
  }) async {
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
      return await _decodeData(
        Uint8List.fromList(block.block.data),
        cid.codec ?? 'raw',
      );
    } catch (e) {
      _logger.error('Failed to get IPLD data', e);
      rethrow;
    }
  }

  /// Resolves a path through IPLD data according to IPFS standards
  Future<(dynamic, String?)> resolveLink(CID root, String path) async {
    if (path.isEmpty) return (await get(root), root.toString());

    var currentNode = await get(root);
    var remainingPath = IPLDPathHandler.normalizePath(path);
    var lastCid = root;

    while (remainingPath.isNotEmpty) {
      final segments = remainingPath.split('/');
      final segment = segments[0];

      if (segment.isEmpty) {
        remainingPath = segments.sublist(1).join('/');
        continue;
      }

      final result = await _resolveSegment(currentNode, segment);
      if (result == null) {
        throw IPLDResolutionError('Unable to resolve segment: $segment');
      }

      final (resolvedNode, cid) = result;
      currentNode = resolvedNode;
      lastCid = cid;

      remainingPath = segments.sublist(1).join('/');
    }

    return (currentNode, lastCid.toString());
  }

  // Helper methods for link resolution
  bool _isCIDLink(String value) {
    return value.startsWith('ipfs://') ||
        value.startsWith('/ipfs/') ||
        value.startsWith('Qm') ||
        value.startsWith('bafy');
  }

  bool _isIPLDLink(Map<dynamic, dynamic> value) {
    return value.containsKey('/') || // IPLD link format
        value.containsKey('cid') || // Alternative link format
        value.containsKey('Link'); // DAG-PB link format
  }

  Future<CID> _resolveCIDLink(String value) async {
    if (value.startsWith('ipfs://')) {
      return CID.decode(value.substring(7));
    } else if (value.startsWith('/ipfs/')) {
      return CID.decode(value.substring(6));
    } else {
      return CID.decode(value);
    }
  }

  Future<CID> _resolveIPLDLink(Map<dynamic, dynamic> value) async {
    if (value.containsKey('/')) {
      return CID.decode(value['/'] as String);
    } else if (value.containsKey('cid')) {
      return CID.decode(value['cid'] as String);
    } else if (value.containsKey('Link')) {
      return CID.decode(value['Link'] as String);
    }
    throw IPLDResolutionError('Invalid IPLD link format');
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

    final cid = await CID.computeForData(encoded, format: codec);
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
      links: links,
      data: Uint8List.fromList(data),
      mtime: DateTime.now().millisecondsSinceEpoch,
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
    CID rootCid,
    IPLDSelector selector,
  ) async {
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
          await _traverseLinks(node, (link) => traverse(link, currentSelector));
          break;

        case SelectorType.none:
          break;

        case SelectorType.explore:
          if (currentSelector.fieldPath != null) {
            final value = _resolveFieldPath(node, currentSelector.fieldPath!);
            if (value != null &&
                currentSelector.subSelectors?.isNotEmpty == true) {
              if (value is String && _isCIDLink(value)) {
                final linkedCid = await _resolveCIDLink(value);
                await traverse(linkedCid, currentSelector.subSelectors!.first);
              }
            }
          }
          break;

        case SelectorType.matcher:
          if (_matchesCriteria(node, currentSelector.criteria)) {
            results.add(node);
          }
          break;

        case SelectorType.recursive:
          if (currentSelector.maxDepth == null ||
              visited.length <= currentSelector.maxDepth!) {
            if (currentSelector.subSelectors?.isNotEmpty == true) {
              final subSelector = currentSelector.subSelectors!.first;
              if (_matchesCriteria(node, subSelector.criteria)) {
                results.add(node);
              }
            }

            if (!(currentSelector.stopAtLink ?? false)) {
              await _traverseLinks(
                node,
                (link) => traverse(link, currentSelector),
              );
            }
          }
          break;

        case SelectorType.union:
          for (final subSelector in currentSelector.subSelectors ?? []) {
            await traverse(cid, subSelector as IPLDSelector);
          }
          break;

        case SelectorType.intersection:
          if (currentSelector.subSelectors?.every(
                (selector) => _matchesCriteria(node, selector.criteria),
              ) ??
              false) {
            results.add(node);
            await _traverseLinks(
              node,
              (link) => traverse(link, currentSelector),
            );
          }
          break;
      }
    }

    await traverse(rootCid, selector);
    return results;
  }

  Future<void> _traverseLinks(
    dynamic node,
    Future<void> Function(CID) callback,
  ) async {
    if (node is MerkleDAGNode) {
      for (final link in node.links) {
        await callback(CID.decode(link.cid.toString()));
      }
    } else if (node is Map) {
      for (final value in node.values) {
        if (value is String && _isCIDLink(value)) {
          await callback(await _resolveCIDLink(value));
        }
      }
    }
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
      final pattern = RegExp(criterion['\$regex'] as String);
      return value is String && pattern.hasMatch(value);
    }

    if (criterion is Map && criterion.containsKey('\$gt')) {
      return value is num && value > (criterion['\$gt'] as num);
    }

    if (criterion is Map && criterion.containsKey('\$lt')) {
      return value is num && value < (criterion['\$lt'] as num);
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
        ..values.addAll(value.map((e) => _toIPLDNode(e)));
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
        ..version = value.version
        ..codec = value.codec ?? ''
        ..multihash = value.multihash.toBytes();
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

    final header = node.mapValue.entries
        .firstWhere((e) => e.key == 'header')
        .value;

    final algorithm = header.mapValue.entries
        .firstWhere((e) => e.key == 'alg')
        .value
        .stringValue;

    switch (algorithm) {
      case 'JWS':
        return await JoseCoseHandler.encodeJWS(
          node,
          _config.keystore.privateKey,
        );
      case 'JWE':
        final recipientKey = await _getRecipientKey(node);
        return await JoseCoseHandler.encodeJWE(node, recipientKey);
      case 'COSE':
        return await JoseCoseHandler.encodeCOSE(
          node,
          _config.keystore.privateKey,
        );
      default:
        throw IPLDEncodingError('Unsupported JOSE algorithm: $algorithm');
    }
  }

  Future<IPLDNode> _decodeJose(Uint8List data) async {
    final joseData = json.decode(utf8.decode(data));

    final header = json.decode(
      utf8.decode(base64Url.decode(joseData['protected'] as String)),
    );
    final payload = base64Url.decode(joseData['payload'] as String);

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
                      ..stringValue = header['alg'] as String),
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
    final header = node.mapValue.entries
        .firstWhere((e) => e.key == 'header')
        .value;
    final recipientEntry = header.mapValue.entries.firstWhere(
      (e) => e.key == 'recipient',
    );

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
      format: 'dag-cbor',
    );

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
    final cid = await CID.computeForData(encoded, format: 'dag-cbor');

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
          final linkedBlock = await _blockStore.getBlock(
            entry.value.linkValue.toString(),
          );
          final linkedNode = await _decodeData(
            Uint8List.fromList(linkedBlock.block.data),
            entry.value.linkValue.codec,
          );
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

  Future<dynamic> resolvePath(String path) async {
    path = IPLDPathHandler.normalizePath(path);
    final (namespace, rootCid, remainingPath) = IPLDPathHandler.parsePath(path);

    switch (namespace) {
      case 'ipfs':
        return await _resolveIPFSPath(rootCid, remainingPath);
      case 'ipld':
        return await _resolveIPLDPath(rootCid, remainingPath);
      case 'ipns':
        throw UnimplementedError('IPNS resolution not yet implemented');
      default:
        throw IPLDPathError('Unsupported namespace: $namespace');
    }
  }

  Future<dynamic> _resolveIPFSPath(CID rootCid, String? remainingPath) async {
    final rootNode = await get(rootCid);
    if (remainingPath == null) return rootNode;

    if (rootNode is MerkleDAGNode) {
      // Check if this is a UnixFS node
      if (_isUnixFSNode(rootNode)) {
        return _resolveUnixFSPath(rootNode, remainingPath);
      }
      return _resolvePathInDAGNode(rootNode, remainingPath);
    } else {
      final (result, remaining) = await resolveLink(rootCid, remainingPath);
      if (remaining != null) {
        throw IPLDPathError('Unable to fully resolve path: $remaining');
      }
      return result;
    }
  }

  bool _isUnixFSNode(MerkleDAGNode node) {
    try {
      // Check for UnixFS protobuf data
      final data = node.data;
      if (data.isEmpty) return false;

      // Parse UnixFS Data message
      final unixFsData = Data.fromBuffer(data);
      return unixFsData.hasType(); // Check if type field is set
    } catch (e) {
      _logger.debug('Not a UnixFS node: $e');
      return false;
    }
  }

  Future<dynamic> _resolvePathInDAGNode(MerkleDAGNode node, String path) async {
    final parts = path.split('/');
    var current = node;

    for (final part in parts) {
      if (part.isEmpty) continue;

      var found = false;
      for (final link in current.links) {
        if (link.name == part) {
          final block = await _blockStore.getBlock(link.cid.toString());

          current = MerkleDAGNode.fromBytes(
            Uint8List.fromList(block.block.data),
          );
          found = true;
          break;
        }
      }

      if (!found) {
        throw IPLDPathError('Path segment not found: $part');
      }
    }

    return current;
  }

  Future<dynamic> _resolveUnixFSPath(MerkleDAGNode node, String path) async {
    // Parse UnixFS data
    final unixFsData = Data.fromBuffer(node.data);

    // Verify it's a directory
    if (unixFsData.type != Data_DataType.Directory &&
        unixFsData.type != Data_DataType.HAMTShard) {
      throw IPLDPathError('Not a directory');
    }

    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    var current = node;

    for (final part in parts) {
      var found = false;
      for (final link in current.links) {
        if (link.name == part) {
          final block = await _blockStore.getBlock(link.cid.toString());

          current = MerkleDAGNode.fromBytes(
            Uint8List.fromList(block.block.data),
          );

          // Verify child node
          if (_isUnixFSNode(current)) {
            final childData = Data.fromBuffer(current.data);
            if (childData.type == Data_DataType.File) {
              // Return file data if this is the last path component
              if (part == parts.last) {
                return childData.data;
              }
              throw IPLDPathError('Cannot traverse through file: $part');
            }
          }

          found = true;
          break;
        }
      }

      if (!found) {
        throw IPLDPathError('Path not found: $part');
      }
    }

    return current;
  }

  /// Resolves a single path segment
  /// Resolves a single path segment
  Future<(dynamic, CID)?> _resolveSegment(dynamic node, String segment) async {
    // Handle standard IPLDNode wrapper
    if (node is IPLDNode) {
      if (node.kind == Kind.MAP) {
        // 1. Direct property access
        final entry = node.mapValue.entries.firstWhere(
          (e) => e.key == segment,
          orElse: () => MapEntry(),
        );

        if (entry.key == segment) {
          final value = entry.value;
          // If value is a Link (native IPLD Link), resolve it?
          // For now return value. Logic in _resolveIPLDPath handles traversal if needed.
          // Check if value is a Link (CID)
          if (value.kind == Kind.LINK) {
            final link = value.linkValue;
            // Construct CID
            final cid = CID.v1(
              link.codec,
              multihash_lib.Multihash.decode(
                Uint8List.fromList(link.multihash),
              ),
            );
            final resolvedNode = await get(cid);
            return (resolvedNode, cid);
          }

          // For non-link values, create dummy/raw CID for path tracking?
          // Returning (value, rootCid) or similar.
          // _resolveIPLDPath handles null CID? No it expects CID.
          // Computed CID for the value node.
          final cid = await CID.computeForData(
            Uint8List.fromList(utf8.encode(value.toString())),
          );
          return (value, cid);
        }

        // 2. DAG-PB Named Link Resolution (via "Links" array)
        // If "Links" exists and is a List
        final linksEntry = node.mapValue.entries.firstWhere(
          (e) => e.key == 'Links',
          orElse: () => MapEntry(),
        );

        if (linksEntry.key == 'Links' && linksEntry.value.kind == Kind.LIST) {
          for (final linkNode in linksEntry.value.listValue.values) {
            if (linkNode.kind == Kind.MAP) {
              final nameEntry = linkNode.mapValue.entries.firstWhere(
                (e) => e.key == 'Name',
                orElse: () => MapEntry(),
              );

              if (nameEntry.key == 'Name' &&
                  nameEntry.value.stringValue == segment) {
                // Match found! Get Hash/Cid
                final hashEntry = linkNode.mapValue.entries.firstWhere(
                  (e) => e.key == 'Hash',
                  orElse: () => linkNode.mapValue.entries.firstWhere(
                    (e) => e.key == 'Cid',
                    orElse: () => MapEntry(),
                  ),
                );

                if (hashEntry.hasValue()) {
                  CID cid;
                  if (hashEntry.value.kind == Kind.LINK) {
                    final l = hashEntry.value.linkValue;
                    cid = CID.v1(
                      l.codec,
                      multihash_lib.Multihash.decode(
                        Uint8List.fromList(l.multihash),
                      ),
                    );
                  } else if (hashEntry.value.kind == Kind.BYTES) {
                    cid = CID.fromBytes(
                      Uint8List.fromList(hashEntry.value.bytesValue),
                    );
                  } else {
                    continue;
                  }

                  final resolvedNode = await get(cid);
                  return (resolvedNode, cid);
                }
              }
            }
          }
        }
      } else if (node.kind == Kind.LIST) {
        final index = int.tryParse(segment);
        if (index != null &&
            index >= 0 &&
            index < node.listValue.values.length) {
          final value = node.listValue.values[index];
          if (value.kind == Kind.LINK) {
            final link = value.linkValue;
            final cid = CID.v1(
              link.codec,
              multihash_lib.Multihash.decode(
                Uint8List.fromList(link.multihash),
              ),
            );
            final resolvedNode = await get(cid);
            return (resolvedNode, cid);
          }
          final cid = await CID.computeForData(
            Uint8List.fromList(utf8.encode(value.toString())),
          );
          return (value, cid);
        }
      }
    }

    // Fallback for legacy Map/List/MerkleDAGNode (if ever used directly)
    if (node is Map) {
      if (!node.containsKey(segment)) {
        return null;
      }

      final value = node[segment];
      if (value is String && _isCIDLink(value)) {
        final cid = await _resolveCIDLink(value);
        final resolvedNode = await get(cid);
        return (resolvedNode, cid);
      } else if (value is Map && _isIPLDLink(value)) {
        final cid = await _resolveIPLDLink(value);
        final resolvedNode = await get(cid);
        return (resolvedNode, cid);
      }
      // For non-link values, create a dummy CID
      return (
        value,
        await CID.computeForData(utf8.encode(value.toString()), format: 'raw'),
      );
    }

    if (node is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= node.length) {
        return null;
      }

      final value = node[index];
      if (value is String && _isCIDLink(value)) {
        final cid = await _resolveCIDLink(value);
        final resolvedNode = await get(cid);
        return (resolvedNode, cid);
      }
      // For non-link array values, create a dummy CID
      return (
        value,
        await CID.computeForData(utf8.encode(value.toString()), format: 'raw'),
      );
    }

    if (node is MerkleDAGNode) {
      for (final link in node.links) {
        if (link.name == segment) {
          final cid = CID.decode(link.cid.toString());
          final resolvedNode = await get(cid);
          return (resolvedNode, cid);
        }
      }
    }

    return null;
  }

  /// Resolves an IPLD path starting from a root CID
  Future<dynamic> _resolveIPLDPath(CID rootCid, String? remainingPath) async {
    final rootNode = await get(rootCid);
    if (remainingPath == null) return rootNode;

    var current = rootNode;
    final parts = remainingPath.split('/').where((p) => p.isNotEmpty).toList();

    for (final part in parts) {
      if (current is Map) {
        if (!current.containsKey(part)) {
          throw IPLDPathError('Property not found: $part');
        }
        current = current[part];

        if (current is String && _isCIDLink(current)) {
          final cid = await _resolveCIDLink(current);
          current = await get(cid);
        } else if (current is Map && _isIPLDLink(current)) {
          final cid = await _resolveIPLDLink(current);
          current = await get(cid);
        }
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) {
          throw IPLDPathError('Invalid array index: $part');
        }
        current = current[index];
      } else if (current is MerkleDAGNode) {
        final result = await _resolveSegment(current, part);
        if (result == null) {
          throw IPLDPathError('Path segment not found: $part');
        }
        current = result.$1;
      } else {
        throw IPLDPathError('Cannot traverse: invalid node type');
      }
    }

    return current;
  }

  Future<IPLDMetadata> _extractMetadata(MerkleDAGNode node) async {
    if (!_isUnixFSNode(node)) {
      throw IPLDPathError('Not a UnixFS node');
    }

    final unixFsData = Data.fromBuffer(node.data);

    // Create properties map
    final properties = <String, String>{};

    // Add file mode if present
    if (unixFsData.hasMode()) {
      properties['mode'] = unixFsData.mode.toString();
    }

    // Calculate mtime if present
    DateTime? lastModified;
    if (unixFsData.hasMtime()) {
      lastModified = DateTime.fromMillisecondsSinceEpoch(
        unixFsData.mtime.toInt() * 1000 + (unixFsData.mtimeNsecs ~/ 1000000),
      );
      properties['mtime'] = lastModified.toIso8601String();
    }

    return IPLDMetadata(
      size: unixFsData.filesize.toInt(),
      properties: properties,
      lastModified: lastModified,
      contentType: 'application/ipfs-unixfs',
    );
  }

  Future<IPLDMetadata> getMetadata(CID cid) async {
    final node = await get(cid);

    if (node is MerkleDAGNode) {
      return _extractMetadata(node);
    }

    // For non-MerkleDAG nodes, return basic metadata
    return IPLDMetadata(
      size: node.toString().length,
      contentType: _inferContentType(node),
    );
  }

  String? _inferContentType(dynamic node) {
    if (node is MerkleDAGNode) {
      return _isUnixFSNode(node)
          ? 'application/ipfs-unixfs'
          : 'application/dag-pb';
    } else if (node is Map) {
      return 'application/dag-cbor';
    }
    return null;
  }

  Future<(dynamic, IPLDMetadata)> resolveWithMetadata(String path) async {
    final resolved = await resolvePath(path);
    final metadata = await getMetadata(
      resolved is MerkleDAGNode
          ? resolved.cid
          : await CID.computeForData(utf8.encode(resolved.toString())),
    );
    return (resolved, metadata);
  }
}
