import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/link.dart';
import 'package:dart_ipfs/src/core/data_structures/merkle_dag_node.dart';
import 'package:dart_ipfs/src/core/errors/ipld_errors.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';

/// CBOR encoding/decoding for IPLD data structures.
///
/// This handler provides a spec-compliant DAG-CBOR encoder/decoder as defined
/// by the IPLD DAG-CBOR specification (https://ipld.io/specs/codecs/dag-cbor/spec/).
///
/// Supported features:
/// - CID links encoded as CBOR tag 42 with the `0x00` multibase prefix.
/// - Raw bytes encoded as plain CBOR byte strings (no non-standard tag 45).
/// - Canonical map key ordering (by length, then lexicographic byte order).
/// - Big integers via CBOR tags 2 (positive) and 3 (negative).
/// - 64-bit double-precision floats only; non-finite values are rejected.
/// - Strict decoding by default with optional lenient mode.
///
/// See also:
/// - [IPLDNode] for the IPLD data model
/// - [MerkleDAGNode] for DAG-PB nodes
class EnhancedCBORHandler {
  /// Mapping of CBOR tag values to their human-readable names.
  ///
  /// Only the IPLD-standard tags are listed. The legacy non-standard tag 45
  /// has been removed.
  static const cborTags = {
    0x02: 'positive-bignum',
    0x03: 'negative-bignum',
    0x2a: 'cid-link',
  };

  // ---- Public DAG-CBOR API ----

  /// Encodes an [IPLDNode] into canonical DAG-CBOR bytes.
  ///
  /// Throws [IPLDEncodingError] for unsupported values such as non-finite
  /// floats, non-string map keys, invalid UTF-8 strings, or values exceeding
  /// the configured size/depth limits.
  static Uint8List encodeDagCbor(IPLDNode node, {DagCborOptions? options}) {
    final opts = options ?? const DagCborOptions();
    final writer = _CborWriter();
    _encodeNode(writer, node, opts, 0);
    return writer.toBytes();
  }

  /// Decodes DAG-CBOR bytes into an [IPLDNode].
  ///
  /// In [strict] mode (the default) the decoder rejects:
  /// - CBOR tags other than 2, 3, and 42.
  /// - Duplicate map keys.
  /// - Indefinite-length strings, bytes, arrays, or maps.
  /// - Non-string map keys.
  /// - Non-finite floats and unsupported simple values.
  /// - Non-canonical integer/length encodings.
  ///
  /// In lenient mode, non-canonical integer/length encodings and out-of-order
  /// map keys are accepted, but CIDs and big integers are still decoded
  /// according to the spec and unsupported tags remain rejected.
  static IPLDNode decodeDagCbor(
    Uint8List data, {
    bool strict = true,
    DagCborOptions? options,
  }) {
    final opts = options ?? const DagCborOptions();
    if (data.length > opts.maxBytes) {
      throw IPLDDecodingError('Input exceeds maximum length');
    }
    final reader = _CborReader(data);
    final node = _decodeItem(reader, opts, 0, strict);
    if (reader.offset != data.length) {
      throw IPLDDecodingError('Extraneous bytes after top-level CBOR item');
    }
    return node;
  }

  /// Convenience that encodes [node] and hashes it with the DAG-CBOR
  /// multicodec (`0x71`) and the default hash function (sha2-256).
  static Future<CID> computeCidDagCbor(IPLDNode node) async {
    final bytes = encodeDagCbor(node);
    return CID.fromContent(bytes, codec: 'dag-cbor');
  }

  /// Encodes an IPLD node to CBOR bytes.
  ///
  /// This is a backwards-compatible alias for [encodeDagCbor].
  static Future<Uint8List> encodeCbor(IPLDNode node) async {
    return encodeDagCbor(node);
  }

  /// Decodes CBOR bytes into an IPLD node.
  ///
  /// This is a backwards-compatible alias for [decodeDagCbor] with
  /// `strict: false` so that existing, loosely encoded data can still be read.
  static Future<IPLDNode> decodeCborWithTags(Uint8List data) async {
    return decodeDagCbor(data, strict: false);
  }

  // ---- MerkleDAG conversion utilities (kept for DAG-PB codec) ----

  /// Converts a MerkleDAGNode to an IPLDNode.
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

  /// Converts an IPLDNode to a MerkleLink.
  static Link convertToMerkleLink(IPLDNode node) {
    if (node.kind != Kind.MAP) {
      throw IPLDEncodingError('Cannot convert non-map to Link');
    }

    final map = node.mapValue.entries;

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
      final link = cidEntry.value.linkValue;
      cid = CID.v1(
        link.codec,
        Multihash.decode(Uint8List.fromList(link.multihash)),
      );
    } else {
      cid = CID.fromBytes(Uint8List.fromList(cidEntry.value.bytesValue));
    }

    return Link(
      name: nameEntry.value.stringValue,
      cid: cid,
      size: sizeEntry.value.intValue.toInt(),
    );
  }

  /// Converts a Link to an IPLDNode.
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
                ..multihash = link.cid.multihash.toBytes())),
          MapEntry()
            ..key = 'Tsize'
            ..value = (IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = link.size),
        ]));
  }

  // ---- Encoder internals ----

  static void _encodeNode(
    _CborWriter writer,
    IPLDNode node,
    DagCborOptions options,
    int depth,
  ) {
    if (depth > options.maxDepth) {
      throw IPLDEncodingError('Maximum recursion depth exceeded');
    }

    switch (node.kind) {
      case Kind.NULL:
        writer.addByte(0xf6);
      case Kind.BOOL:
        writer.addByte(node.boolValue ? 0xf5 : 0xf4);
      case Kind.INTEGER:
        _encodeIntValue(writer, BigInt.from(node.intValue.toInt()));
      case Kind.FLOAT:
        _encodeFloat(writer, node.floatValue);
      case Kind.STRING:
        _encodeString(writer, node.stringValue);
      case Kind.BYTES:
        _encodeBytes(writer, node.bytesValue);
      case Kind.LIST:
        _encodeList(writer, node.listValue, options, depth);
      case Kind.MAP:
        _encodeMap(writer, node.mapValue, options, depth);
      case Kind.LINK:
        _encodeLink(writer, node.linkValue);
      case Kind.BIG_INT:
        final value = _decodeInternalBigInt(node.bigIntValue);
        _encodeIntValue(writer, value);
      default:
        throw IPLDEncodingError('Unsupported IPLD kind: ${node.kind}');
    }
  }

  /// Encodes a signed integer value using the smallest canonical CBOR form.
  ///
  /// Values in the unsigned range `[0, 2^64-1]` use major type 0. Values in the
  /// negative range `[-1, -2^64]` use major type 1. Values outside those ranges
  /// use CBOR big-integer tags 2 (positive) or 3 (negative).
  static void _encodeIntValue(_CborWriter writer, BigInt signedValue) {
    if (signedValue.sign >= 0) {
      // Positive or zero.
      if (signedValue <= _maxUnsignedInt64) {
        _encodeUnsigned(writer, signedValue);
      } else {
        _encodeTag2Positive(writer, signedValue);
      }
    } else {
      // Negative.
      final abs = -signedValue;
      // Major type 1 can represent [-1, -2^64]; its stored argument is abs - 1,
      // which must be <= 2^64 - 1.
      if (abs - BigInt.one <= _maxUnsignedInt64) {
        // CBOR negative value is encoded as (-1 - value) = abs - 1.
        _encodeNegative(writer, abs);
      } else {
        _encodeTag3Negative(writer, abs);
      }
    }
  }

  static void _encodeUnsigned(_CborWriter writer, BigInt value) {
    _encodeIntArgument(writer, 0, value);
  }

  static void _encodeNegative(_CborWriter writer, BigInt absValue) {
    // Encode -absValue as CBOR negative: stored value = absValue - 1.
    _encodeIntArgument(writer, 1, absValue - BigInt.one);
  }

  static void _encodeIntArgument(
    _CborWriter writer,
    int majorType,
    BigInt value,
  ) {
    if (value <= _int23) {
      writer.addByte((majorType << 5) | value.toInt());
    } else if (value <= _int255) {
      writer.addByte((majorType << 5) | 24);
      writer.addByte(value.toInt());
    } else if (value <= _int65535) {
      writer.addByte((majorType << 5) | 25);
      _writeUint16(writer, value.toInt());
    } else if (value <= _int4294967295) {
      writer.addByte((majorType << 5) | 26);
      _writeUint32(writer, value.toInt());
    } else if (value <= _maxUnsignedInt64) {
      writer.addByte((majorType << 5) | 27);
      _writeUint64(writer, value);
    } else {
      throw IPLDEncodingError('Integer argument out of CBOR range');
    }
  }

  static void _encodeTag2Positive(_CborWriter writer, BigInt value) {
    // CBOR tag 2 is encoded canonically as the single byte 0xc2 (major type 6, tag 2).
    writer.addByte(0xc2);
    _encodeBytes(writer, _bigIntToMinimalBytes(value));
  }

  static void _encodeTag3Negative(_CborWriter writer, BigInt absValue) {
    // CBOR tag 3 is encoded canonically as the single byte 0xc3 (major type 6, tag 3).
    writer.addByte(0xc3);
    // CBOR tag 3 represents -(1 + n), so n = absValue - 1.
    _encodeBytes(writer, _bigIntToMinimalBytes(absValue - BigInt.one));
  }

  static void _encodeFloat(_CborWriter writer, double value) {
    if (!value.isFinite) {
      throw IPLDEncodingError('Non-finite floats are not allowed in DAG-CBOR');
    }
    // Canonical DAG-CBOR always uses 64-bit double precision.
    writer.addByte(0xfb);
    _writeFloat64(writer, value);
  }

  static void _encodeString(_CborWriter writer, String value) {
    final bytes = utf8.encode(value);
    _encodeLength(writer, 3, bytes.length);
    writer.addBytes(bytes);
  }

  static void _encodeBytes(_CborWriter writer, List<int> bytes) {
    _encodeLength(writer, 2, bytes.length);
    writer.addBytes(bytes);
  }

  static void _encodeList(
    _CborWriter writer,
    IPLDList list,
    DagCborOptions options,
    int depth,
  ) {
    final values = list.values;
    _encodeLength(writer, 4, values.length);
    for (final item in values) {
      _encodeNode(writer, item, options, depth + 1);
    }
  }

  static void _encodeMap(
    _CborWriter writer,
    IPLDMap map,
    DagCborOptions options,
    int depth,
  ) {
    final entries = map.entries.toList();
    if (entries.length > options.maxMapSize) {
      throw IPLDEncodingError('Map exceeds maximum size');
    }

    // Sort keys canonically: by UTF-8 length, then lexicographic byte order.
    entries.sort((a, b) {
      final aBytes = utf8.encode(a.key);
      final bBytes = utf8.encode(b.key);
      if (aBytes.length != bBytes.length) {
        return aBytes.length.compareTo(bBytes.length);
      }
      for (var i = 0; i < aBytes.length; i++) {
        final cmp = aBytes[i].compareTo(bBytes[i]);
        if (cmp != 0) return cmp;
      }
      return 0;
    });

    _encodeLength(writer, 5, entries.length);
    for (final entry in entries) {
      _encodeString(writer, entry.key);
      _encodeNode(writer, entry.value, options, depth + 1);
    }
  }

  static void _encodeLink(_CborWriter writer, IPLDLink link) {
    Uint8List cidBytes;
    if (link.version == 0) {
      cidBytes = Uint8List.fromList(link.multihash);
    } else {
      final mh = Multihash.decode(Uint8List.fromList(link.multihash));
      final cid = CID.v1(link.codec, mh);
      cidBytes = cid.toBytes();
    }

    // Tag 42 with the multibase identity prefix 0x00.
    final taggedBytes = Uint8List(cidBytes.length + 1);
    taggedBytes[0] = 0x00;
    taggedBytes.setRange(1, taggedBytes.length, cidBytes);

    writer.addByte(0xd8); // major type 6, additional 24
    writer.addByte(0x2a); // tag 42
    _encodeBytes(writer, taggedBytes);
  }

  static void _encodeLength(_CborWriter writer, int majorType, int length) {
    _encodeIntArgument(writer, majorType, BigInt.from(length));
  }

  // ---- Decoder internals ----

  static IPLDNode _decodeItem(
    _CborReader reader,
    DagCborOptions options,
    int depth,
    bool strict,
  ) {
    if (depth > options.maxDepth) {
      throw IPLDDecodingError('Maximum recursion depth exceeded');
    }
    if (reader.offset >= reader.bytes.length) {
      throw IPLDDecodingError('Truncated input');
    }

    final initial = reader.readByte();
    final major = initial >> 5;
    final additional = initial & 0x1f;

    if (additional == 31) {
      throw IPLDDecodingError('Indefinite-length items are not allowed');
    }

    // Major type 7 uses additional info as the minor type, not a length.
    if (major == 7) {
      return _decodeSimpleOrFloat(reader, initial, additional, strict);
    }

    final argument = _readArgument(reader, additional, strict);

    switch (major) {
      case 0:
        return _makeIntNode(argument);
      case 1:
        return _makeIntNode(-(argument + BigInt.one));
      case 2:
        return _makeBytesNode(reader.readBytes(_argumentToInt(argument)));
      case 3:
        return _makeStringNode(
          reader.readBytes(_argumentToInt(argument)),
          options,
        );
      case 4:
        return _makeListNode(
          reader,
          options,
          depth,
          _argumentToInt(argument),
          strict,
        );
      case 5:
        return _makeMapNode(
          reader,
          options,
          depth,
          _argumentToInt(argument),
          strict,
        );
      case 6:
        return _decodeTagged(reader, options, depth, strict, argument);
      default:
        throw IPLDDecodingError('Unsupported CBOR major type: $major');
    }
  }

  static BigInt _readArgument(_CborReader reader, int additional, bool strict) {
    if (additional <= 23) {
      return BigInt.from(additional);
    }
    if (additional == 24) {
      final value = BigInt.from(reader.readUint8());
      if (strict && value <= _int23) {
        throw IPLDDecodingError('Non-canonical integer/length encoding');
      }
      return value;
    }
    if (additional == 25) {
      final value = BigInt.from(reader.readUint16());
      if (strict && value <= _int255) {
        throw IPLDDecodingError('Non-canonical integer/length encoding');
      }
      return value;
    }
    if (additional == 26) {
      final value = BigInt.from(reader.readUint32());
      if (strict && value <= _int65535) {
        throw IPLDDecodingError('Non-canonical integer/length encoding');
      }
      return value;
    }
    if (additional == 27) {
      final value = reader.readUint64();
      if (strict && value <= _int4294967295) {
        throw IPLDDecodingError('Non-canonical integer/length encoding');
      }
      return value;
    }
    throw IPLDDecodingError('Reserved CBOR additional info: $additional');
  }

  static IPLDNode _decodeSimpleOrFloat(
    _CborReader reader,
    int initial,
    int additional,
    bool strict,
  ) {
    switch (additional) {
      case 20:
        return IPLDNode()
          ..kind = Kind.BOOL
          ..boolValue = false;
      case 21:
        return IPLDNode()
          ..kind = Kind.BOOL
          ..boolValue = true;
      case 22:
        return IPLDNode()..kind = Kind.NULL;
      case 23:
        throw IPLDDecodingError('Undefined is not supported in DAG-CBOR');
      case 24:
        throw IPLDDecodingError('Unassigned simple values are not supported');
      case 25:
        if (strict) {
          throw IPLDDecodingError(
            'Half-precision floats are not allowed in strict DAG-CBOR',
          );
        }
        return _makeFloatNode(_readFloat16(reader));
      case 26:
        if (strict) {
          throw IPLDDecodingError(
            'Single-precision floats are not allowed in strict DAG-CBOR',
          );
        }
        return _makeFloatNode(_readFloat32(reader));
      case 27:
        return _makeFloatNode(_readFloat64(reader));
      default:
        throw IPLDDecodingError('Unsupported CBOR simple/float type');
    }
  }

  static IPLDNode _makeIntNode(BigInt value) {
    if (value >= _minInt64 && value <= _maxInt64) {
      return IPLDNode()
        ..kind = Kind.INTEGER
        ..intValue = Int64(value.toInt());
    }
    return IPLDNode()
      ..kind = Kind.BIG_INT
      ..bigIntValue = _encodeInternalBigInt(value);
  }

  static IPLDNode _makeBytesNode(Uint8List bytes) {
    return IPLDNode()
      ..kind = Kind.BYTES
      ..bytesValue = bytes;
  }

  static IPLDNode _makeStringNode(Uint8List bytes, DagCborOptions options) {
    if (bytes.length > options.maxStringLength) {
      throw IPLDDecodingError('String exceeds maximum length');
    }
    try {
      final text = utf8.decode(bytes);
      return IPLDNode()
        ..kind = Kind.STRING
        ..stringValue = text;
    } catch (_) {
      throw IPLDDecodingError('Invalid UTF-8 string');
    }
  }

  static IPLDNode _makeFloatNode(double value) {
    if (!value.isFinite) {
      throw IPLDDecodingError('Non-finite floats are not allowed in DAG-CBOR');
    }
    return IPLDNode()
      ..kind = Kind.FLOAT
      ..floatValue = value;
  }

  static IPLDNode _makeListNode(
    _CborReader reader,
    DagCborOptions options,
    int depth,
    int length,
    bool strict,
  ) {
    if (length > options.maxMapSize) {
      throw IPLDDecodingError('List exceeds maximum size');
    }
    final list = IPLDList();
    for (var i = 0; i < length; i++) {
      list.values.add(_decodeItem(reader, options, depth + 1, strict));
    }
    return IPLDNode()
      ..kind = Kind.LIST
      ..listValue = list;
  }

  static IPLDNode _makeMapNode(
    _CborReader reader,
    DagCborOptions options,
    int depth,
    int length,
    bool strict,
  ) {
    if (length > options.maxMapSize) {
      throw IPLDDecodingError('Map exceeds maximum size');
    }
    final map = IPLDMap();
    Uint8List? previousKeyBytes;
    for (var i = 0; i < length; i++) {
      final keyNode = _decodeItem(reader, options, depth + 1, strict);
      if (keyNode.kind != Kind.STRING) {
        throw IPLDDecodingError('Map keys must be strings');
      }
      final keyBytes = utf8.encode(keyNode.stringValue);
      if (strict) {
        if (previousKeyBytes != null) {
          final cmp = _compareCanonicalKeyOrder(previousKeyBytes, keyBytes);
          if (cmp >= 0) {
            throw IPLDDecodingError('Map keys are not in canonical order');
          }
        }
      }
      final valueNode = _decodeItem(reader, options, depth + 1, strict);
      final key = keyNode.stringValue;
      if (map.entries.any((e) => e.key == key)) {
        throw IPLDDecodingError('Duplicate map key: $key');
      }
      map.entries.add(
        MapEntry()
          ..key = key
          ..value = valueNode,
      );
      previousKeyBytes = keyBytes;
    }
    return IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = map;
  }

  static IPLDNode _decodeTagged(
    _CborReader reader,
    DagCborOptions options,
    int depth,
    bool strict,
    BigInt tag,
  ) {
    if (tag == BigInt.from(42)) {
      final inner = _decodeItem(reader, options, depth + 1, strict);
      if (inner.kind != Kind.BYTES) {
        throw IPLDDecodingError('Tag 42 must be applied to a byte string');
      }
      final bytes = inner.bytesValue;
      if (bytes.isEmpty || bytes[0] != 0x00) {
        throw IPLDDecodingError('Tag 42 byte string must start with 0x00');
      }
      return _convertCIDFromBytes(Uint8List.fromList(bytes.sublist(1)));
    }
    if (tag == BigInt.from(2)) {
      final inner = _decodeItem(reader, options, depth + 1, strict);
      if (inner.kind != Kind.BYTES) {
        throw IPLDDecodingError('Tag 2 must be applied to a byte string');
      }
      if (strict && _isNonMinimalBigIntBytes(inner.bytesValue)) {
        throw IPLDDecodingError('Non-minimal big-integer byte string');
      }
      final value = _minimalBytesToBigInt(inner.bytesValue);
      return _makeIntNode(value);
    }
    if (tag == BigInt.from(3)) {
      final inner = _decodeItem(reader, options, depth + 1, strict);
      if (inner.kind != Kind.BYTES) {
        throw IPLDDecodingError('Tag 3 must be applied to a byte string');
      }
      if (strict && _isNonMinimalBigIntBytes(inner.bytesValue)) {
        throw IPLDDecodingError('Non-minimal big-integer byte string');
      }
      final n = _minimalBytesToBigInt(inner.bytesValue);
      // CBOR tag 3 represents -(1 + n).
      return _makeIntNode(-(n + BigInt.one));
    }
    throw IPLDDecodingError('Unsupported CBOR tag: $tag');
  }

  // ---- CID conversion helpers ----

  static IPLDNode _convertCIDFromBytes(Uint8List bytes) {
    try {
      // The DAG-CBOR spec stores raw CID bytes; use the CID parser directly
      // so any standard IPLD codec (dag-json, dag-cbor, raw, etc.) is accepted.
      final cid = CID.fromBytes(bytes);
      final multihash = Uint8List.fromList(cid.multihash.toBytes());
      return IPLDNode()
        ..kind = Kind.LINK
        ..linkValue = (IPLDLink()
          ..version = cid.version
          ..codec = cid.codec ?? 'unknown'
          ..multihash = multihash);
    } catch (e) {
      throw IPLDDecodingError('Failed to decode CID: $e');
    }
  }

  // ---- BigInt helpers ----

  /// Internal representation: `[sign, ...bigEndianBytes]` where sign is 0 for
  /// positive and 1 for negative. This matches the convention used elsewhere
  /// in the dart_ipfs codebase.
  static BigInt _decodeInternalBigInt(List<int> bytes) {
    if (bytes.isEmpty) return BigInt.zero;
    final isNegative = bytes[0] == 1;
    final value = _minimalBytesToBigInt(bytes.sublist(1));
    return isNegative ? -value : value;
  }

  static Uint8List _encodeInternalBigInt(BigInt value) {
    if (value == BigInt.zero) return Uint8List.fromList([0, 0]);
    final isNegative = value.isNegative;
    final abs = isNegative ? -value : value;
    final bytes = _bigIntToMinimalBytes(abs);
    final result = Uint8List(bytes.length + 1);
    result[0] = isNegative ? 1 : 0;
    result.setRange(1, result.length, bytes);
    return result;
  }

  static Uint8List _bigIntToMinimalBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List(0);
    final hex = value.toRadixString(16).padLeft(value.bitLength + 4, '0');
    var cleanHex = hex.length % 2 != 0 ? '0$hex' : hex;
    // Remove leading zeros while keeping pairs.
    while (cleanHex.length > 2 && cleanHex.startsWith('00')) {
      cleanHex = cleanHex.substring(2);
    }
    final bytes = <int>[];
    for (var i = 0; i < cleanHex.length; i += 2) {
      bytes.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  static BigInt _minimalBytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  static bool _isNonMinimalBigIntBytes(List<int> bytes) {
    // Preferred serialization: no leading zero bytes. The value zero is
    // represented as an empty byte string.
    return bytes.isNotEmpty && bytes[0] == 0;
  }

  // ---- Canonical ordering helper ----

  static int _compareCanonicalKeyOrder(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return a.length.compareTo(b.length);
    }
    for (var i = 0; i < a.length; i++) {
      final cmp = a[i].compareTo(b[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  // ---- Binary writing helpers ----

  static void _writeUint16(_CborWriter writer, int value) {
    writer.addByte((value >> 8) & 0xff);
    writer.addByte(value & 0xff);
  }

  static void _writeUint32(_CborWriter writer, int value) {
    writer.addByte((value >> 24) & 0xff);
    writer.addByte((value >> 16) & 0xff);
    writer.addByte((value >> 8) & 0xff);
    writer.addByte(value & 0xff);
  }

  static void _writeUint64(_CborWriter writer, BigInt value) {
    for (var i = 7; i >= 0; i--) {
      writer.addByte(((value >> (i * 8)) & _byteMask).toInt());
    }
  }

  static void _writeFloat64(_CborWriter writer, double value) {
    final buffer = ByteData(8);
    buffer.setFloat64(0, value, Endian.big);
    writer.addBytes(buffer.buffer.asUint8List());
  }

  static double _readFloat16(_CborReader reader) {
    final bits = reader.readUint16();
    final sign = (bits & 0x8000) >> 15;
    final exponent = (bits & 0x7c00) >> 10;
    final mantissa = bits & 0x03ff;
    if (exponent == 0) {
      if (mantissa == 0) return sign == 1 ? -0.0 : 0.0;
      // Subnormal.
      return (sign == 1 ? -1.0 : 1.0) *
          math.pow(2.0, -24).toDouble() *
          mantissa.toDouble();
    }
    if (exponent == 31) {
      if (mantissa == 0) {
        return sign == 1 ? double.negativeInfinity : double.infinity;
      }
      return double.nan;
    }
    return (sign == 1 ? -1.0 : 1.0) *
        math.pow(2.0, exponent - 15).toDouble() *
        (1024 + mantissa).toDouble();
  }

  static double _readFloat32(_CborReader reader) {
    final buffer = ByteData(4);
    for (var i = 0; i < 4; i++) {
      buffer.setUint8(i, reader.readUint8());
    }
    return buffer.getFloat32(0, Endian.big);
  }

  static double _readFloat64(_CborReader reader) {
    final buffer = ByteData(8);
    for (var i = 0; i < 8; i++) {
      buffer.setUint8(i, reader.readUint8());
    }
    return buffer.getFloat64(0, Endian.big);
  }

  static int _argumentToInt(BigInt value) {
    if (value < BigInt.zero || value > _maxInt64) {
      throw IPLDDecodingError('CBOR length/argument out of supported range');
    }
    return value.toInt();
  }

  // ---- Constants ----

  static final BigInt _int23 = BigInt.from(23);
  static final BigInt _int255 = BigInt.from(255);
  static final BigInt _int65535 = BigInt.from(65535);
  static final BigInt _int4294967295 = BigInt.from(4294967295);
  static final BigInt _maxInt64 = BigInt.parse('9223372036854775807');
  static final BigInt _minInt64 = BigInt.parse('-9223372036854775808');
  static final BigInt _maxUnsignedInt64 = BigInt.parse('18446744073709551615');
  static final BigInt _byteMask = BigInt.from(0xff);
}

/// Configuration options for the DAG-CBOR encoder/decoder.
class DagCborOptions {
  /// Creates a set of DAG-CBOR options.
  const DagCborOptions({
    this.maxBytes = 32 * 1024 * 1024,
    this.maxDepth = 1024,
    this.maxMapSize = 1000000,
    this.maxStringLength = 8 * 1024 * 1024,
  });

  /// Maximum input size in bytes.
  final int maxBytes;

  /// Maximum recursion depth.
  final int maxDepth;

  /// Maximum number of entries in a map.
  final int maxMapSize;

  /// Maximum decoded string length in bytes.
  final int maxStringLength;
}

/// Simple byte accumulator for the encoder.
class _CborWriter {
  final _builder = BytesBuilder();

  void addByte(int byte) => _builder.addByte(byte);
  void addBytes(List<int> bytes) => _builder.add(bytes);
  Uint8List toBytes() => _builder.toBytes();
}

/// Byte reader for the decoder.
class _CborReader {
  _CborReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  int readByte() {
    if (offset >= bytes.length) {
      throw IPLDDecodingError('Truncated input');
    }
    return bytes[offset++];
  }

  int readUint8() => readByte();

  int readUint16() {
    final b1 = readUint8();
    final b2 = readUint8();
    return (b1 << 8) | b2;
  }

  int readUint32() {
    return (readUint8() << 24) |
        (readUint8() << 16) |
        (readUint8() << 8) |
        readUint8();
  }

  BigInt readUint64() {
    var result = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      result = (result << 8) | BigInt.from(readUint8());
    }
    return result;
  }

  Uint8List readBytes(int length) {
    if (length < 0) {
      throw IPLDDecodingError('Negative length');
    }
    if (offset + length > bytes.length) {
      throw IPLDDecodingError('Truncated input');
    }
    final result = bytes.sublist(offset, offset + length);
    offset += length;
    return result;
  }
}
