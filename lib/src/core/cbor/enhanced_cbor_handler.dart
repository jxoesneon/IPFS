import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';

/// CBOR encoding/decoding for IPLD data structures.
///
/// This handler provides bidirectional conversion between IPLD nodes
/// and CBOR binary format, supporting DAG-CBOR, DAG-PB, and CID links.
///
/// **Supported CBOR Tags:**
/// - `42`: DAG-PB (protobuf encoded)
/// - `43`: DAG-CBOR
/// - `6`: CID link
/// - `45`: Raw binary data
///
/// Example:
/// ```dart
/// // Encode an IPLD node to CBOR
/// final bytes = await EnhancedCBORHandler.encodeCbor(ipldNode);
///
/// // Decode CBOR back to IPLD
/// final node = await EnhancedCBORHandler.decodeCborWithTags(bytes);
/// ```
///
/// See also:
/// - [IPLDNode] for the IPLD data model
/// - [MerkleDAGNode] for DAG-PB nodes
class EnhancedCBORHandler {
  static final _encoder = const CborEncoder();
  static final _decoder = const CborDecoder();

  /// Mapping of CBOR tag values to their human-readable codec names.
  static const cborTags = {
    // Core IPLD Codecs
    0x55: 'raw',
    0x70: 'dag-pb',
    0x71: 'dag-cbor',
    0x0129: 'dag-json',
    0x72: 'libp2p-key',

    // IPFS-specific tags
    0x01: 'cidv1',
    0x02: 'cidv2',
    0x03: 'cidv3',
    0x51: 'raw-leaves',
    0x81: 'unixfs',
    0x90: 'identity',
    0x91: 'id-multihash',
    0x92: 'id-sha2-256',
    0x93: 'id-sha2-512',
    0x94: 'id-sha3-512',
    0xb0: 'multicodec',
    0xb1: 'multibase',
    0xb2: 'multihash',

    // IPLD Namespace tags
    0x300: 'ipld-ns',
    0x301: 'ipfs-ns',
    0x302: 'ipns-ns',
    0x303: 'swarm-ns',
    0x304: 'dnslink-ns',

    // Legacy tags (for compatibility)
    42: 'dag-pb',
    43: 'dag-cbor',
    44: 'dag-json',
    45: 'raw',
    6: 'cid-link',
  };

  /// Encodes an IPLD node to CBOR bytes with support for indefinite length
  static Future<Uint8List> encodeCbor(IPLDNode node) async {
    final value = convertIPLDNodeToCbor(node);
    return Uint8List.fromList(_encoder.convert(value));
  }

  /// Decodes CBOR bytes with tag handling and indefinite length support
  static Future<IPLDNode> decodeCborWithTags(Uint8List data) async {
    final decoded = _decoder.convert(data);
    return convertCborToIPLDNode(decoded);
  }

  /// Converts an IPLD node to a CBOR value with indefinite length support
  static CborValue convertIPLDNodeToCbor(IPLDNode node) {
    switch (node.kind) {
      case Kind.NULL:
        return const CborNull();
      case Kind.BOOL:
        return CborBool(node.boolValue);
      case Kind.INTEGER:
        return CborSmallInt(node.intValue.toInt());
      case Kind.FLOAT:
        return CborFloat(node.floatValue);
      case Kind.STRING:
        return CborString(node.stringValue);
      case Kind.BYTES:
        return CborBytes(node.bytesValue, tags: [45]); // Raw tag
      case Kind.LIST:
        final list = node.listValue.values
            .map((e) => convertIPLDNodeToCbor(e))
            .toList();
        return CborList(list);
      case Kind.MAP:
        final map = <CborValue, CborValue>{};
        for (final entry in node.mapValue.entries) {
          map[CborString(entry.key)] = convertIPLDNodeToCbor(entry.value);
        }
        return CborMap(map, tags: [43]); // DAG-CBOR tag
      case Kind.LINK:
        final link = node.linkValue;
        Uint8List cidBytes;
        if (link.version == 0) {
           // CIDv0: just multihash
           cidBytes = Uint8List.fromList(link.multihash);
        } else {
           // CIDv1
           // Reconstruct CID to get bytes
           // We need MultihashInfo from bytes
           final mh = Multihash.decode(Uint8List.fromList(link.multihash));
           final cid = CID.v1(link.codec, mh);
           cidBytes = cid.toBytes();
        }
        return CborBytes(cidBytes, tags: [6]); // Tag 6 for CID link
      case Kind.BIG_INT:
        return CborBigInt.fromBytes(node.bigIntValue);
      default:
        throw IPLDEncodingError('Unsupported IPLD kind: ${node.kind}');
    }
  }

  /// Converts a CBOR value to an IPLD node with tag handling
  static IPLDNode convertCborToIPLDNode(CborValue value) {
    if (value is CborBytes && value.tags.isNotEmpty) {
      final tag = value.tags.first;
      switch (tag) {
        case 42: // DAG-PB
          return convertFromMerkleDAGNode(
            MerkleDAGNode.fromBytes(Uint8List.fromList(value.bytes)),
          );
        case 43: // DAG-CBOR
          return convertCborValueToIPLDNode(value);
        case 6: // CID Link
          return _convertCIDFromBytes(Uint8List.fromList(value.bytes));
        default:
          return convertCborValueToIPLDNode(value);
      }
    }
    return convertCborValueToIPLDNode(value);
  }

  /// Converts a CBOR value to an IPLD node
  static IPLDNode convertCborValueToIPLDNode(CborValue value) {
    if (value is CborNull) {
      return IPLDNode()..kind = Kind.NULL;
    } else if (value is CborBool) {
      return IPLDNode()
        ..kind = Kind.BOOL
        ..boolValue = value.toString() == 'true';
    } else if (value is CborSmallInt) {
      return IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(int.parse(value.toString()));
    } else if (value is CborFloat) {
      return IPLDNode()
        ..kind = Kind.FLOAT
        ..floatValue = double.parse(value.toString());
    } else if (value is CborString) {
      return IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = value.toString();
    } else if (value is CborBytes) {
      return IPLDNode()
        ..kind = Kind.BYTES
        ..bytesValue = value.bytes;
    } else if (value is CborList) {
      final list = IPLDList();
      for (final item in value.toList()) {
        list.values.add(convertCborToIPLDNode(item));
      }
      return IPLDNode()
        ..kind = Kind.LIST
        ..listValue = list;
    } else if (value is CborMap) {
      final map = IPLDMap();
      for (final entry in value.entries) {
        map.entries.add(
          MapEntry()
            ..key = entry.key.toString()
            ..value = convertCborToIPLDNode(entry.value),
        );
      }
      return IPLDNode()
        ..kind = Kind.MAP
        ..mapValue = map;
    } else {
      throw IPLDDecodingError('Unsupported CBOR type: ${value.runtimeType}');
    }
  }

  /// Converts a MerkleDAGNode to an IPLDNode
  static IPLDNode convertFromMerkleDAGNode(MerkleDAGNode dagNode) {
    final links = IPLDList()
      ..values.addAll(dagNode.links.map(_convertFromMerkleLink));

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

  /// Converts an IPLDNode to a MerkleLink
  static Link convertToMerkleLink(IPLDNode node) {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('Cannot convert non-map to Link');
    }

    final map = node.mapValue.entries;

    // Support both standard names (Hash, Tsize) and internal names (Cid, Size) for compatibility
    final nameEntry = map.firstWhere(
      (e) => e.key == 'Name',
      orElse: () => MapEntry()
        ..key = 'Name'
        ..value = (IPLDNode()
          ..kind = Kind.STRING
          ..stringValue = ''),
    );

    final cidEntry = map.firstWhere(
      (e) => e.key == 'Hash',
      orElse: () => map.firstWhere(
        (e) => e.key == 'Cid',
        orElse: () => MapEntry()
          ..key = 'Hash'
          ..value = (IPLDNode()
            ..kind = Kind.BYTES
            ..bytesValue = Uint8List(0)),
      ),
    );

    final sizeEntry = map.firstWhere(
      (e) => e.key == 'Tsize',
      orElse: () => map.firstWhere(
        (e) => e.key == 'Size',
        orElse: () => MapEntry()
          ..key = 'Tsize'
          ..value = (IPLDNode()
            ..kind = Kind.INTEGER
            ..intValue = Int64(0)),
      ),
    );

    CID cid;
    if (cidEntry.value.kind == Kind.LINK) {
      // Extract CID from Link
      final link = cidEntry.value.linkValue;
      cid = CID.v1(
        link.codec,
        Multihash.decode(Uint8List.fromList(link.multihash)),
      ); // Assuming multihash bytes are valid
      // Ideally reuse CID constructor from components
    } else {
      // Assume bytes
      cid = CID.fromBytes(Uint8List.fromList(cidEntry.value.bytesValue));
    }

    return Link(
      name: nameEntry.value.stringValue,
      cid: cid,
      size: sizeEntry.value.intValue.toInt(),
    );
  }

  /// Converts a Link to an IPLDNode
  static IPLDNode _convertFromMerkleLink(Link link) {
    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()
        ..entries.addAll([
          MapEntry()
            ..key = 'Name'
            ..value = (IPLDNode()
              ..kind = Kind.STRING
              ..stringValue = link.name),
          MapEntry()
            ..key = 'Hash'
            ..value = (IPLDNode()
              ..kind = Kind.LINK
              ..linkValue = (IPLDLink()
                ..version = link.cid.version
                ..codec = link.cid.codec ?? 'dag-pb'
                ..multihash = link.cid.multihash
                    .toBytes())), // Encode CID as Link
          MapEntry()
            ..key = 'Tsize'
            ..value = (IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = link.size),
        ]));
  }

  static IPLDNode _convertCIDFromBytes(Uint8List bytes) {
    try {
      // CIDv0: 32-byte SHA-256 hash with 0x12 prefix
      if (bytes.length == 34 && bytes[0] == 0x12 && bytes[1] == 0x20) {
        return IPLDNode()
          ..kind = Kind.LINK
          ..linkValue = (IPLDLink()
            ..version = 0
            ..codec =
                'dag-pb' // CIDv0 is always dag-pb
            ..multihash = bytes);
      }

      // CIDv1+: <version><multicodec><multihash>
      if (bytes.length > 2) {
        final version = bytes[0];
        if (version == 1) {
          final codec = _getCodecFromCode(bytes[1]);
          final multihash = bytes.sublist(2);

          // Validate multihash format
          if (multihash.length < 2) {
            throw IPLDDecodingError('Invalid multihash length');
          }

          // Check hash function (first byte) and length (second byte)
          final hashFn = multihash[0];
          final hashLen = multihash[1];

          // Validate according to IPFS multihash spec
          if (!_isValidMultihash(hashFn, hashLen, multihash.sublist(2))) {
            throw IPLDDecodingError('Invalid multihash format');
          }

          return IPLDNode()
            ..kind = Kind.LINK
            ..linkValue = (IPLDLink()
              ..version = version
              ..codec = codec
              ..multihash = multihash);
        }
      }

      throw IPLDDecodingError('Unsupported CID version');
    } catch (e) {
      throw IPLDDecodingError('Failed to decode CID: $e');
    }
  }

  static String _getCodecFromCode(int code) {
    const codecMap = {
      0x00: 'identity',
      0x55: 'raw',
      0x70: 'dag-pb',
      0x71: 'dag-cbor',
      0x72: 'libp2p-key',
      0xd1: 'ipld-ns',
      0xd2: 'ipfs-ns',
      0x0129: 'dag-json-binary',
      0x012a: 'dag-jose',
      0x012b: 'dag-cose',
    };

    final codec = codecMap[code];
    if (codec == null) {
      throw IPLDDecodingError(
        'Unsupported codec code: 0x${code.toRadixString(16)}',
      );
    }
    return codec;
  }

  // Add helper method for multihash validation
  static bool _isValidMultihash(int hashFn, int hashLen, List<int> digest) {
    // IPFS supported hash functions
    const supportedHashFns = {
      0x12: 32, // sha2-256: 32 bytes
      0x13: 64, // sha2-512: 64 bytes
      0x14: 28, // sha3-512: 28 bytes
      0x16: 32, // blake2b-256: 32 bytes
      0x17: 64, // blake2b-512: 64 bytes
      0x56: 32, // dbl-sha2-256: 32 bytes
    };

    // Check if hash function is supported
    if (!supportedHashFns.containsKey(hashFn)) {
      return false;
    }

    // Validate digest length matches the expected length
    return hashLen == supportedHashFns[hashFn] && digest.length == hashLen;
  }
}
