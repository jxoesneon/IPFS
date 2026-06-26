// src/core/ipfs_node/ipld_handler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/data_structures/metadata.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/core/errors/node_errors.dart';
import 'package:dart_ipfs/src/core/interfaces/i_lifecycle.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/advanced_codecs.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/ipld_codec.dart';
import 'package:dart_ipfs/src/core/ipld/codecs/standard_codecs.dart';
import 'package:dart_ipfs/src/core/ipld/path/ipld_path_handler.dart';
import 'package:dart_ipfs/src/core/ipld/schema/ipld_schema.dart';
import 'package:dart_ipfs/src/core/ipld/selectors/ipld_selector.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:dart_ipfs/src/utils/encoding.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_multihash/dart_multihash.dart' as multihash_lib;
import 'package:fixnum/fixnum.dart';

/// Handles IPLD (InterPlanetary Linked Data) operations using a Strategy pattern for codecs.
class IPLDHandler implements ILifecycle {
  /// Creates an IPLD handler with config and blockstore.
  IPLDHandler(this._config, this._blockStore) {
    _logger = Logger(
      'IPLDHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _registerDefaultCodecs();
  }
  final IPFSConfig _config;
  final BlockStore _blockStore;
  final Map<String, IPLDSchema> _schemas = {};
  final Map<String, IPLDCodec> _codecs = {};
  final Map<int, IPLDCodec> _codecsByCode = {};
  late final Logger _logger;
  bool _isRunning = true;

  /// Whether the IPLD handler is currently running.
  bool get isRunning => _isRunning;

  void _registerDefaultCodecs() {
    _registerCodec(RawCodec());
    _registerCodec(DagPbCodec());
    _registerCodec(DagCborCodec());
    _registerCodec(DagJsonCodec());
    _registerCodec(
      DagJoseCodec(
        () async => _config.keystore.privateKey,
        (node) async => _getRecipientKey(node),
      ),
    );
  }

  void _registerCodec(IPLDCodec codec) {
    _codecs[codec.name] = codec;
    _codecsByCode[codec.code] = codec;
  }

  /// Registers a codec for IPLD data.
  void registerCodec(IPLDCodec codec) {
    _registerCodec(codec);
  }

  /// Registers a schema for validation.
  void registerSchema(IPLDSchema schema) {
    _schemas[schema.name] = schema;
  }

  /// Puts a value into the blockstore
  Future<Block> put(
    dynamic value, {
    String codec = 'dag-cbor',
    String? schemaType,
  }) async {
    if (!_isRunning) {
      throw ComponentError('IPLDHandler', 'Handler is not running');
    }
    try {
      final ipldNode = _toIPLDNode(value);

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
    } catch (e, st) {
      _logger.error('Failed to put IPLD data', e, st);
      rethrow;
    }
  }

  /// Gets a value from the blockstore
  Future<dynamic> get(CID cid) async {
    if (!_isRunning) {
      throw ComponentError('IPLDHandler', 'Handler is not running');
    }
    try {
      final block = await _blockStore.getBlock(cid.toString());
      return await _decodeData(
        Uint8List.fromList(block.block.data),
        cid.codec ?? 'raw',
      );
    } catch (e, st) {
      _logger.error('Failed to get IPLD data', e, st);
      rethrow;
    }
  }

  /// Resolves a path through IPLD data
  Future<(dynamic, String?)> resolveLink(CID root, String path) async {
    if (!_isRunning) {
      throw ComponentError('IPLDHandler', 'Handler is not running');
    }
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

  /// Encodes data using the specified codec strategy
  Future<(Uint8List, CID)> _encodeData(IPLDNode node, String codecId) async {
    final codec = _codecs[codecId];
    if (codec == null) {
      throw UnsupportedError('Unsupported codec: $codecId');
    }

    try {
      final encoded = await codec.encode(node);
      // Use the codec's multicodec code for the CID and the codec name for the
      // block format metadata, per COUNCIL_DECISION_IPLDCODEC_RECONCILIATION.md.
      final format = EncodingUtils.getCodecFromCode(codec.code);
      final cid = await CID.computeForData(encoded, format: format);
      return (encoded, cid);
    } catch (e) {
      throw IPLDEncodingError('Failed to encode $codecId: $e');
    }
  }

  /// Decodes data using the specified codec strategy
  Future<IPLDNode> _decodeData(Uint8List data, String codecId) async {
    final codec = _codecs[codecId];
    if (codec == null) {
      throw UnsupportedError('Unsupported codec: $codecId');
    }

    try {
      return await codec.decode(data);
    } catch (e) {
      throw IPLDDecodingError('Failed to decode $codecId: $e');
    }
  }

  /// Starts the IPLD handler
  @override
  Future<void> start() async {
    if (_isRunning) return;
    _logger.debug('Starting IPLDHandler...');
    try {
      _logger.verbose('IPLD codecs initialized: ${_codecs.keys.join(", ")}');
      _isRunning = true;
      _logger.debug('IPLDHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start IPLDHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Stops the IPLD handler
  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _logger.debug('Stopping IPLDHandler...');
    try {
      _isRunning = false;
      _logger.debug('IPLDHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop IPLDHandler', e, stackTrace);
      rethrow;
    }
  }

  /// Gets the status of the IPLD handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'supported_codecs': _codecs.keys.toList(),
      'supported_codec_codes': _codecsByCode.keys.toList(),
      'enabled': _config.enableIPLD,
      'running': _isRunning,
    };
  }

  /// Executes a selector query on an IPLD node
  Future<List<SelectorResult>> executeSelector(
    CID rootCid,
    IPLDSelector selector,
  ) async {
    if (!_isRunning) {
      throw ComponentError('IPLDHandler', 'Handler is not running');
    }
    final results = <SelectorResult>[];
    final visited = <String>{};

    Future<void> traverse(CID cid, IPLDSelector currentSelector) async {
      if (visited.contains(cid.toString())) return;
      visited.add(cid.toString());

      final node = await get(cid) as IPLDNode?;
      if (node == null) return;

      switch (currentSelector.type) {
        case SelectorType.all:
          results.add(SelectorResult(cid: cid, node: node));
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
            results.add(SelectorResult(cid: cid, node: node));
          }
          break;

        case SelectorType.recursive:
          if (currentSelector.maxDepth == null ||
              visited.length <= currentSelector.maxDepth!) {
            if (currentSelector.subSelectors?.isNotEmpty == true) {
              final subSelector = currentSelector.subSelectors!.first;
              if (_matchesCriteria(node, subSelector.criteria)) {
                results.add(SelectorResult(cid: cid, node: node));
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
            visited.remove(cid.toString());
            await traverse(cid, subSelector as IPLDSelector);
          }
          break;

        case SelectorType.intersection:
          if (currentSelector.subSelectors?.every(
                (selector) => _matchesCriteria(node, selector.criteria),
              ) ??
              false) {
            results.add(SelectorResult(cid: cid, node: node));
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
    if (node is IPLDNode) {
      if (node.kind == Kind.MAP) {
        for (final entry in node.mapValue.entries) {
          if (entry.value.kind == Kind.LINK) {
            final link = entry.value.linkValue;
            final multihash = multihash_lib.Multihash.decode(
              Uint8List.fromList(link.multihash),
            );
            final cid = CID.v1(link.codec, multihash);
            await callback(cid);
          } else if (entry.value.kind == Kind.MAP) {
            final linkCid = _tryGetCidFromMap(entry.value);
            if (linkCid != null) {
              await callback(linkCid);
            } else {
              await _traverseLinks(entry.value, callback);
            }
          } else if (entry.value.kind == Kind.LIST) {
            await _traverseLinks(entry.value, callback);
          }
        }
      } else if (node.kind == Kind.LIST) {
        for (final value in node.listValue.values) {
          if (value.kind == Kind.LINK) {
            final link = value.linkValue;
            final multihash = multihash_lib.Multihash.decode(
              Uint8List.fromList(link.multihash),
            );
            final cid = CID.v1(link.codec, multihash);
            await callback(cid);
          } else if (value.kind == Kind.MAP) {
            final linkCid = _tryGetCidFromMap(value);
            if (linkCid != null) {
              await callback(linkCid);
            } else {
              await _traverseLinks(value, callback);
            }
          } else if (value.kind == Kind.LIST) {
            await _traverseLinks(value, callback);
          }
        }
      }
    } else if (node is MerkleDAGNode) {
      for (final link in node.links) {
        await callback(CID.decode(link.cid.toString()));
      }
    } else if (node is Map) {
      for (final value in node.values) {
        if (value is String && _isCIDLink(value)) {
          await callback(await _resolveCIDLink(value));
        } else if (value is CID) {
          await callback(value);
        }
      }
    }
  }

  CID? _tryGetCidFromMap(IPLDNode node) {
    if (node.kind != Kind.MAP) return null;
    for (final entry in node.mapValue.entries) {
      if (entry.key == '/') {
        if (entry.value.kind == Kind.STRING) {
          try {
            return CID.decode(entry.value.stringValue);
          } catch (_) {
            return null;
          }
        } else if (entry.value.kind == Kind.BYTES) {
          try {
            return CID.fromBytes(Uint8List.fromList(entry.value.bytesValue));
          } catch (_) {
            try {
              final mh = multihash_lib.Multihash.decode(
                Uint8List.fromList(entry.value.bytesValue),
              );
              return CID.v1('dag-cbor', mh);
            } catch (e) {
              return null;
            }
          }
        }
      }
    }
    return null;
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
      if (current is IPLDNode) {
        if (current.kind == Kind.LIST) {
          final index = int.tryParse(part);
          if (index != null &&
              index >= 0 &&
              index < current.listValue.values.length) {
            current = current.listValue.values[index];
            continue;
          } else {
            return null;
          }
        }

        if (current.kind == Kind.MAP) {
          final entry = current.mapValue.entries.firstWhere(
            (e) => e.key == part,
            orElse: () => MapEntry()..key = '',
          );
          if (entry.key == part) {
            current = entry.value;
            continue;
          } else {
            return null;
          }
        }
      } else if (current is Map) {
        current = current[part];
        continue;
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
        continue;
      }
      return null;
    }

    return current is IPLDNode ? _unwrapIPLDNode(current) : current;
  }

  dynamic _unwrapIPLDNode(IPLDNode node) {
    switch (node.kind) {
      case Kind.BOOL:
        return node.boolValue;
      case Kind.INTEGER:
        return node.intValue.toInt();
      case Kind.FLOAT:
        return node.floatValue;
      case Kind.STRING:
        return node.stringValue;
      case Kind.BYTES:
        return node.bytesValue;
      case Kind.LINK:
        final link = node.linkValue;
        final multihash = multihash_lib.Multihash.decode(
          Uint8List.fromList(link.multihash),
        );
        return CID.v1(link.codec, multihash).toString();
      case Kind.NULL:
        return null;
      case Kind.MAP:
        final cid = _tryGetCidFromMap(node);
        if (cid != null) return cid.toString();
        return node;
      case Kind.LIST:
        return node.listValue.values.map(_unwrapIPLDNode).toList();
      case Kind.BIG_INT:
        return _decodeBigInt(Uint8List.fromList(node.bigIntValue));
      default:
        return node;
    }
  }

  bool _matchesValue(dynamic value, dynamic criterion) {
    if (criterion is Map) {
      if (criterion.containsKey('\$regex')) {
        final pattern = RegExp(criterion['\$regex'] as String);
        return value is String && pattern.hasMatch(value);
      }
      if (criterion.containsKey('\$gt')) {
        return value is num && value > (criterion['\$gt'] as num);
      }
      if (criterion.containsKey('\$lt')) {
        return value is num && value < (criterion['\$lt'] as num);
      }
      if (criterion.containsKey('\$exists')) {
        final exists = criterion['\$exists'] as bool;
        return (value != null) == exists;
      }
      if (criterion.containsKey('\$type')) {
        final expectedType = criterion['\$type'] as String;
        return _checkType(value, expectedType);
      }
      if (criterion.containsKey('\$mod')) {
        final mod = criterion['\$mod'] as List;
        if (mod.length == 2 && value is num) {
          return value % (mod[0] as num) == (mod[1] as num);
        }
      }
      if (criterion.containsKey('\$all')) {
        final all = criterion['\$all'] as List;
        if (value is List) {
          return all.every((item) => value.contains(item));
        }
      }
      if (criterion.containsKey('\$size')) {
        final size = criterion['\$size'] as int;
        if (value is List) return value.length == size;
        if (value is Map) return value.length == size;
        if (value is String) return value.length == size;
      }
      if (criterion.containsKey('\$elemMatch')) {
        final elemMatch = criterion['\$elemMatch'] as Map<String, dynamic>;
        if (value is List) {
          return value.any((item) => _matchesCriteria(item, elemMatch));
        }
      }
    }
    return value == criterion;
  }

  bool _checkType(dynamic value, String type) {
    switch (type.toLowerCase()) {
      case 'string':
        return value is String;
      case 'number':
      case 'int':
      case 'float':
        return value is num;
      case 'boolean':
      case 'bool':
        return value is bool;
      case 'list':
      case 'array':
        return value is List;
      case 'map':
      case 'object':
        return value is Map || value is IPLDNode && value.kind == Kind.MAP;
      case 'null':
        return value == null;
      case 'link':
      case 'cid':
        return value is CID || (value is String && _isCIDLink(value));
      default:
        return false;
    }
  }

  IPLDNode _toIPLDNode(dynamic value) {
    final node = IPLDNode();

    if (value == null) {
      node.kind = Kind.NULL;
    } else if (value is bool) {
      node.kind = Kind.BOOL;
      node.boolValue = value;
    } else if (value is int) {
      node.kind = Kind.INTEGER;
      node.intValue = Int64(value);
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
    } else {
      throw IPLDEncodingError('Unsupported value type: ${value.runtimeType}');
    }

    return node;
  }

  Uint8List _encodeBigInt(BigInt value) {
    if (value == BigInt.zero) return Uint8List.fromList([0, 0]);
    var isNegative = value.isNegative;
    var unsignedValue = isNegative ? -value : value;
    var hex = unsignedValue.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';

    var result = Uint8List(hex.length ~/ 2 + 1);
    result[0] = isNegative ? 1 : 0;
    for (var i = 0; i < hex.length; i += 2) {
      result[1 + i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  BigInt _decodeBigInt(Uint8List bytes) {
    if (bytes.length < 2) return BigInt.zero;
    var isNegative = bytes[0] == 1;
    var hex = '';
    for (var i = 1; i < bytes.length; i++) {
      hex += bytes[i].toRadixString(16).padLeft(2, '0');
    }
    var value = BigInt.parse(hex, radix: 16);
    return isNegative ? -value : value;
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

  bool _isCIDLink(String value) {
    return value.startsWith('ipfs://') ||
        value.startsWith('/ipfs/') ||
        (value.length > 2 &&
            (value.startsWith('b') || value.startsWith('B'))) ||
        value.startsWith('Qm');
  }

  bool _isIPLDLink(Map<dynamic, dynamic> value) {
    return value.containsKey('/') ||
        value.containsKey('cid') ||
        value.containsKey('Link');
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

  /// Resolves an IPFS/IPLD/IPNS path.
  Future<dynamic> resolvePath(String path) async {
    if (!_isRunning) {
      throw ComponentError('IPLDHandler', 'Handler is not running');
    }
    path = IPLDPathHandler.normalizePath(path);
    final (namespace, rootCid, remainingPath) = IPLDPathHandler.parsePath(path);

    dynamic result;
    switch (namespace) {
      case 'ipfs':
        result = await _resolveIPFSPath(rootCid, remainingPath);
        break;
      case 'ipld':
        result = await _resolveIPLDPath(rootCid, remainingPath);
        break;
      case 'ipns':
        throw UnimplementedError('IPNS resolution not yet implemented');
      default:
        throw IPLDPathError('Unsupported namespace: $namespace');
    }

    return result;
  }

  Future<dynamic> _resolveIPFSPath(CID rootCid, String? remainingPath) async {
    final rootNode = await get(rootCid);
    if (remainingPath == null) return rootNode;

    if (rootNode is MerkleDAGNode) {
      if (_isUnixFSNode(rootNode)) {
        return _resolveUnixFSPath(rootNode, remainingPath);
      }
      return _resolvePathInDAGNode(rootNode, remainingPath);
    } else if (rootNode is IPLDNode && _isDagPbNode(rootNode)) {
      if (_isUnixFSIpldNode(rootNode)) {
        return _resolveUnixFSPathIpld(rootNode, remainingPath);
      }
      return _resolvePathInDagPbIpldNode(rootNode, remainingPath);
    } else {
      final (result, _) = await resolveLink(rootCid, remainingPath);
      return result;
    }
  }

  bool _isDagPbNode(IPLDNode node) {
    if (node.kind != Kind.MAP) return false;
    final entries = node.mapValue.entries;
    return entries.any((e) => e.key == 'Data') &&
        entries.any((e) => e.key == 'Links');
  }

  bool _isUnixFSIpldNode(IPLDNode node) {
    try {
      final dataEntry = node.mapValue.entries.firstWhere(
        (e) => e.key == 'Data',
      );
      if (dataEntry.value.kind != Kind.BYTES) return false;
      final unixFsData = Data.fromBuffer(dataEntry.value.bytesValue);
      return unixFsData.hasType();
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> _resolveUnixFSPathIpld(IPLDNode node, String path) async {
    final dataEntry = node.mapValue.entries.firstWhere((e) => e.key == 'Data');
    final unixFsData = Data.fromBuffer(dataEntry.value.bytesValue);

    if (unixFsData.type != Data_DataType.Directory &&
        unixFsData.type != Data_DataType.HAMTShard) {
      throw IPLDPathError('Not a directory');
    }

    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    var current = node;

    for (final part in parts) {
      var found = false;
      final linksEntry = current.mapValue.entries.firstWhere(
        (e) => e.key == 'Links',
      );
      for (final linkNode in linksEntry.value.listValue.values) {
        final link = EnhancedCBORHandler.convertToMerkleLink(linkNode);
        if (link.name == part) {
          final block = await _blockStore.getBlock(link.cid.toString());
          final nextNode = await _decodeData(
            Uint8List.fromList(block.block.data),
            link.cid.codec ?? 'dag-pb',
          );

          if (_isUnixFSIpldNode(nextNode)) {
            final childDataEntry = nextNode.mapValue.entries.firstWhere(
              (e) => e.key == 'Data',
            );
            final childData = Data.fromBuffer(childDataEntry.value.bytesValue);
            if (childData.type == Data_DataType.File) {
              if (part == parts.last) return childData.data;
              throw IPLDPathError('Cannot traverse through file: $part');
            }
          }
          current = nextNode;
          found = true;
          break;
        }
      }
      if (!found) throw IPLDPathError('Path not found: $part');
    }
    return current;
  }

  Future<dynamic> _resolvePathInDagPbIpldNode(
    IPLDNode node,
    String path,
  ) async {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    var current = node;

    for (final part in parts) {
      var found = false;
      final linksEntry = current.mapValue.entries.firstWhere(
        (e) => e.key == 'Links',
      );
      for (final linkNode in linksEntry.value.listValue.values) {
        final link = EnhancedCBORHandler.convertToMerkleLink(linkNode);
        if (link.name == part) {
          final block = await _blockStore.getBlock(link.cid.toString());
          current = await _decodeData(
            Uint8List.fromList(block.block.data),
            link.cid.codec ?? 'dag-pb',
          );
          found = true;
          break;
        }
      }
      if (!found) throw IPLDPathError('Path segment not found: $part');
    }
    return current;
  }

  bool _isUnixFSNode(MerkleDAGNode node) {
    try {
      final data = node.data;
      if (data.isEmpty) return false;
      final unixFsData = Data.fromBuffer(data);
      return unixFsData.hasType();
    } catch (e) {
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
      if (!found) throw IPLDPathError('Path segment not found: $part');
    }
    return current;
  }

  Future<dynamic> _resolveUnixFSPath(MerkleDAGNode node, String path) async {
    final unixFsData = Data.fromBuffer(node.data);
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
          if (_isUnixFSNode(current)) {
            final childData = Data.fromBuffer(current.data);
            if (childData.type == Data_DataType.File) {
              if (part == parts.last) return childData.data;
              throw IPLDPathError('Cannot traverse through file: $part');
            }
          }
          found = true;
          break;
        }
      }
      if (!found) throw IPLDPathError('Path not found: $part');
    }
    return current;
  }

  Future<(dynamic, CID)?> _resolveSegment(dynamic node, String segment) async {
    if (node is IPLDNode) {
      if (node.kind == Kind.MAP) {
        final linkCid = _tryGetCidFromMap(node);
        if (linkCid != null) {
          final resolvedNode = await get(linkCid);
          return _resolveSegment(resolvedNode, segment);
        }

        final entry = node.mapValue.entries.firstWhere(
          (e) => e.key == segment,
          orElse: () => MapEntry(),
        );

        if (entry.key == segment) {
          final value = entry.value;
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
          if (value.kind == Kind.MAP) {
            final innerCid = _tryGetCidFromMap(value);
            if (innerCid != null) {
              final resolvedNode = await get(innerCid);
              return (resolvedNode, innerCid);
            }
          }
          final cid = await CID.computeForData(
            Uint8List.fromList(utf8.encode(value.toString())),
          );
          return (value, cid);
        }

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

    if (node is Map) {
      if (!node.containsKey(segment)) return null;
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
      return (
        value,
        await CID.computeForData(utf8.encode(value.toString()), format: 'raw'),
      );
    }

    if (node is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= node.length) return null;
      final value = node[index];
      if (value is String && _isCIDLink(value)) {
        final cid = await _resolveCIDLink(value);
        final resolvedNode = await get(cid);
        return (resolvedNode, cid);
      }
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
          current = await get(await _resolveCIDLink(current));
        } else if (current is Map && _isIPLDLink(current)) {
          current = await get(await _resolveIPLDLink(current));
        }
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) {
          throw IPLDPathError('Invalid index: $part');
        }
        current = current[index];
      } else {
        final result = await _resolveSegment(current, part);
        if (result == null) {
          throw IPLDPathError('Path segment not found: $part');
        }
        current = result.$1;
      }
    }
    return current;
  }

  Future<IPLDMetadata> _extractMetadata(MerkleDAGNode node) async {
    if (!_isUnixFSNode(node)) throw IPLDPathError('Not a UnixFS node');
    final unixFsData = Data.fromBuffer(node.data);
    final properties = <String, String>{};
    if (unixFsData.hasMode()) properties['mode'] = unixFsData.mode.toString();
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

  /// Returns metadata for a CID.
  Future<IPLDMetadata> getMetadata(CID cid) async {
    final node = await get(cid);
    if (node is MerkleDAGNode && _isUnixFSNode(node)) {
      return _extractMetadata(node);
    }
    if (node is IPLDNode && _isDagPbNode(node) && _isUnixFSIpldNode(node)) {
      return _extractMetadataFromIpld(node);
    }
    return IPLDMetadata(
      size: node is Uint8List ? node.length : node.toString().length,
      contentType: _inferContentType(node),
    );
  }

  Future<IPLDMetadata> _extractMetadataFromIpld(IPLDNode node) async {
    if (!_isUnixFSIpldNode(node)) throw IPLDPathError('Not a UnixFS node');
    final dataEntry = node.mapValue.entries.firstWhere((e) => e.key == 'Data');
    final unixFsData = Data.fromBuffer(dataEntry.value.bytesValue);
    final properties = <String, String>{};
    if (unixFsData.hasMode()) properties['mode'] = unixFsData.mode.toString();
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

  /// Infers the content type of an IPLD node.
  String? _inferContentType(dynamic node) {
    if (node is MerkleDAGNode) {
      return _isUnixFSNode(node)
          ? 'application/ipfs-unixfs'
          : 'application/dag-pb';
    }
    if (node is IPLDNode) {
      if (_isDagPbNode(node)) {
        return _isUnixFSIpldNode(node)
            ? 'application/ipfs-unixfs'
            : 'application/dag-pb';
      }
    }
    if (node is Map) return 'application/dag-cbor';
    if (node is IPLDNode && node.kind == Kind.MAP) {
      return 'application/dag-cbor';
    }
    return null;
  }

  /// Resolves a path and returns both the content and metadata.
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
