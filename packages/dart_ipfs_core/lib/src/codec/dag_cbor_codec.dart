// lib/src/codec/dag_cbor_codec.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../cid/cid.dart';
import '../utils/varint.dart';
import 'codec.dart';

/// Codec for DAG-CBOR.
///
/// The DAG-CBOR multicodec (`0x71`) encodes IPLD data as canonical CBOR,
/// following the IPLD DAG-CBOR specification
/// (https://ipld.io/specs/codecs/dag-cbor/spec/):
///
/// - CID links are CBOR tag 42 applied to a byte string of the CID bytes
///   prefixed by the multibase identity byte `0x00`.
/// - Map keys must be strings and are emitted in canonical order: first by
///   encoded key length, then bytewise lexicographic order.
/// - Integers use the smallest possible representation; values outside the
///   major type 0/1 range (`[0, 2^64 - 1]` and `[-2^64, -1]`) use the
///   bignum tags 2 and 3.
/// - Floats are always 64-bit (`0xfb`); non-finite values are rejected and
///   `-0.0` is normalized to `0.0` on encode.
///
/// When [strict] is true (the default), [decode] additionally rejects:
///
/// - CBOR tags other than 2, 3, and 42.
/// - Duplicate or non-string map keys, and keys out of canonical order.
/// - Indefinite-length strings, bytes, arrays, maps, and `break` tokens.
/// - 16-bit and 32-bit floats, `-0.0`, and non-finite floats.
/// - Non-canonical integer/length encodings (including non-`0xd82a` tag 42).
/// - Bignum tags applied to values representable as major types 0/1, and
///   bignum byte strings with leading zero bytes.
/// - Reserved additional-info values, `undefined`, and unassigned simple
///   values.
/// - Extraneous trailing bytes after the top-level item.
///
/// In lenient mode ([strict] = false) non-canonical integer/length
/// encodings, out-of-order map keys, sub-64-bit floats, and `-0.0` are
/// accepted (with `-0.0` normalized to `0.0`), but unsupported tags,
/// indefinite-length items, non-string keys, duplicates, and invalid CID
/// links are still rejected.
///
/// Encode errors are reported as [ArgumentError]; decode errors as
/// [FormatException].
class DagCborCodec implements IPLDCodec {
  /// Creates a new [DagCborCodec] instance.
  ///
  /// [strict] controls decode-time canonical enforcement; encoding is always
  /// canonical regardless of this flag.
  DagCborCodec({this.strict = true});

  /// Whether decoding enforces canonical DAG-CBOR rules.
  final bool strict;

  /// Maximum nesting depth for encode/decode recursion.
  static const int _maxDepth = 1024;

  static final BigInt _b23 = BigInt.from(23);
  static final BigInt _b255 = BigInt.from(255);
  static final BigInt _b65535 = BigInt.from(65535);
  static final BigInt _b4294967295 = BigInt.from(4294967295);
  static final BigInt _maxUint64 = BigInt.parse('18446744073709551615');
  static final BigInt _maxInt64 = BigInt.parse('9223372036854775807');
  static final BigInt _minInt64 = BigInt.parse('-9223372036854775808');
  static final BigInt _byteMask = BigInt.from(0xff);
  static final BigInt _tag2 = BigInt.from(2);
  static final BigInt _tag3 = BigInt.from(3);
  static final BigInt _tag42 = BigInt.from(42);

  @override
  String get name => 'dag-cbor';

  @override
  int get code => 0x71;

  @override
  Future<Uint8List> encode(dynamic value) async {
    final writer = _CborWriter();
    _encodeValue(writer, value, 0);
    return writer.toBytes();
  }

  @override
  Future<dynamic> decode(Uint8List data) async {
    final reader = _CborReader(data);
    final value = _decodeItem(reader, 0);
    if (reader.offset != data.length) {
      throw const FormatException(
        'Extraneous bytes after top-level DAG-CBOR item',
      );
    }
    return value;
  }

  // ---- Encoder ----

  void _encodeValue(_CborWriter writer, dynamic value, int depth) {
    if (depth > _maxDepth) {
      throw ArgumentError('DAG-CBOR maximum recursion depth exceeded');
    }
    if (value == null) {
      writer.addByte(0xf6);
      return;
    }
    if (value is bool) {
      writer.addByte(value ? 0xf5 : 0xf4);
      return;
    }
    if (value is int) {
      _encodeInt(writer, BigInt.from(value));
      return;
    }
    if (value is BigInt) {
      _encodeInt(writer, value);
      return;
    }
    if (value is double) {
      _encodeFloat(writer, value);
      return;
    }
    if (value is String) {
      _encodeString(writer, value);
      return;
    }
    if (value is Uint8List) {
      _encodeBytes(writer, value);
      return;
    }
    if (value is List<int>) {
      _encodeBytes(writer, Uint8List.fromList(value));
      return;
    }
    if (value is List) {
      _encodeIntArgument(writer, 4, BigInt.from(value.length));
      for (final item in value) {
        _encodeValue(writer, item, depth + 1);
      }
      return;
    }
    if (value is Map) {
      _encodeMap(writer, value, depth);
      return;
    }
    throw ArgumentError(
      'Unsupported value type for DAG-CBOR: ${value.runtimeType}',
    );
  }

  /// Encodes a signed integer in its smallest canonical form.
  ///
  /// `[0, 2^64 - 1]` uses major type 0 and `[-2^64, -1]` uses major type 1.
  /// Only values outside those ranges use the bignum tags 2 and 3.
  void _encodeInt(_CborWriter writer, BigInt value) {
    if (value.sign >= 0) {
      if (value <= _maxUint64) {
        _encodeIntArgument(writer, 0, value);
      } else {
        writer.addByte(0xc2); // tag 2: positive bignum
        _encodeBytes(writer, _bigIntToMinimalBytes(value));
      }
    } else {
      final abs = -value;
      if (abs - BigInt.one <= _maxUint64) {
        // Major type 1 stores (-1 - value) = abs - 1.
        _encodeIntArgument(writer, 1, abs - BigInt.one);
      } else {
        writer.addByte(0xc3); // tag 3: negative bignum
        _encodeBytes(writer, _bigIntToMinimalBytes(abs - BigInt.one));
      }
    }
  }

  void _encodeIntArgument(_CborWriter writer, int majorType, BigInt value) {
    if (value <= _b23) {
      writer.addByte((majorType << 5) | value.toInt());
    } else if (value <= _b255) {
      writer.addByte((majorType << 5) | 24);
      writer.addByte(value.toInt());
    } else if (value <= _b65535) {
      writer.addByte((majorType << 5) | 25);
      writer.addByte((value.toInt() >> 8) & 0xff);
      writer.addByte(value.toInt() & 0xff);
    } else if (value <= _b4294967295) {
      writer.addByte((majorType << 5) | 26);
      final v = value.toInt();
      writer.addByte((v >> 24) & 0xff);
      writer.addByte((v >> 16) & 0xff);
      writer.addByte((v >> 8) & 0xff);
      writer.addByte(v & 0xff);
    } else if (value <= _maxUint64) {
      writer.addByte((majorType << 5) | 27);
      for (var i = 7; i >= 0; i--) {
        writer.addByte(((value >> (i * 8)) & _byteMask).toInt());
      }
    } else {
      throw ArgumentError('Integer argument out of CBOR range');
    }
  }

  void _encodeFloat(_CborWriter writer, double value) {
    if (!value.isFinite) {
      throw ArgumentError('Non-finite floats are not allowed in DAG-CBOR');
    }
    // DAG-CBOR has a single canonical form for zero: -0.0 becomes 0.0.
    final canonical = value == 0.0 ? 0.0 : value;
    writer.addByte(0xfb); // major type 7, 64-bit float
    final buffer = ByteData(8)..setFloat64(0, canonical, Endian.big);
    writer.addBytes(buffer.buffer.asUint8List());
  }

  void _encodeString(_CborWriter writer, String value) {
    final bytes = utf8.encode(value);
    _encodeIntArgument(writer, 3, BigInt.from(bytes.length));
    writer.addBytes(bytes);
  }

  void _encodeBytes(_CborWriter writer, List<int> bytes) {
    _encodeIntArgument(writer, 2, BigInt.from(bytes.length));
    writer.addBytes(bytes);
  }

  void _encodeMap(_CborWriter writer, Map<dynamic, dynamic> value, int depth) {
    // CID link: {'/': 'cid-string'} is the single-key link sentinel.
    if (value.length == 1 && value.containsKey('/')) {
      final link = value['/'];
      if (link is String) {
        _encodeLink(writer, link);
        return;
      }
    }

    final entries = value.entries.toList();
    final encodedKeys = <Uint8List>[];
    for (final entry in entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError(
          'DAG-CBOR map keys must be strings, got ${key.runtimeType}',
        );
      }
      encodedKeys.add(Uint8List.fromList(utf8.encode(key)));
    }

    // Canonical ordering: by encoded key length first, then bytewise
    // lexicographic order of the UTF-8 bytes.
    final order = List<int>.generate(entries.length, (i) => i)
      ..sort((a, b) => _compareKeyOrder(encodedKeys[a], encodedKeys[b]));

    // Duplicate keys cannot be represented canonically.
    for (var i = 1; i < order.length; i++) {
      if (_compareKeyOrder(
            encodedKeys[order[i - 1]],
            encodedKeys[order[i]],
          ) ==
          0) {
        throw ArgumentError(
          'Duplicate map key: ${entries[order[i]].key}',
        );
      }
    }

    _encodeIntArgument(writer, 5, BigInt.from(entries.length));
    for (final index in order) {
      _encodeIntArgument(writer, 3, BigInt.from(encodedKeys[index].length));
      writer.addBytes(encodedKeys[index]);
      _encodeValue(writer, entries[index].value, depth + 1);
    }
  }

  void _encodeLink(_CborWriter writer, String link) {
    final Uint8List cidBytes;
    try {
      cidBytes = CID.decode(link).toBytes();
    } catch (e) {
      throw ArgumentError('Invalid CID in DAG-CBOR link: $link ($e)');
    }
    final taggedBytes = Uint8List(cidBytes.length + 1);
    taggedBytes[0] = 0x00; // multibase identity prefix
    taggedBytes.setRange(1, taggedBytes.length, cidBytes);

    writer.addByte(0xd8); // tag with 1-byte argument
    writer.addByte(0x2a); // tag 42
    _encodeBytes(writer, taggedBytes);
  }

  // ---- Decoder ----

  dynamic _decodeItem(_CborReader reader, int depth) {
    if (depth > _maxDepth) {
      throw const FormatException('DAG-CBOR maximum recursion depth exceeded');
    }

    final initial = reader.readByte();
    final major = initial >> 5;
    final additional = initial & 0x1f;

    // Covers indefinite-length items (0x5f, 0x7f, 0x9f, 0xbf) and the
    // standalone break token (0xff).
    if (additional == 31) {
      throw const FormatException(
        'Indefinite-length items are not allowed in DAG-CBOR',
      );
    }

    // Major type 7 uses the additional info as a minor type, not a length.
    if (major == 7) {
      return _decodeSimpleOrFloat(reader, additional);
    }

    final argument = _readArgument(reader, additional);

    switch (major) {
      case 0:
        return _bigIntToDart(argument);
      case 1:
        return _bigIntToDart(-(argument + BigInt.one));
      case 2:
        return reader.readBytes(_argumentToInt(argument, reader));
      case 3:
        return _decodeString(reader, argument);
      case 4:
        return _decodeList(reader, argument, depth);
      case 5:
        return _decodeMap(reader, argument, depth);
      case 6:
        return _decodeTagged(reader, argument, depth);
      default:
        throw FormatException('Unsupported CBOR major type: $major');
    }
  }

  BigInt _readArgument(_CborReader reader, int additional) {
    if (additional <= 23) {
      return BigInt.from(additional);
    }
    if (additional == 24) {
      final value = BigInt.from(reader.readUint8());
      if (strict && value <= _b23) {
        throw const FormatException(
          'Non-canonical integer/length encoding in DAG-CBOR',
        );
      }
      return value;
    }
    if (additional == 25) {
      final value = BigInt.from(reader.readUint16());
      if (strict && value <= _b255) {
        throw const FormatException(
          'Non-canonical integer/length encoding in DAG-CBOR',
        );
      }
      return value;
    }
    if (additional == 26) {
      final value = BigInt.from(reader.readUint32());
      if (strict && value <= _b65535) {
        throw const FormatException(
          'Non-canonical integer/length encoding in DAG-CBOR',
        );
      }
      return value;
    }
    if (additional == 27) {
      final value = reader.readUint64();
      if (strict && value <= _b4294967295) {
        throw const FormatException(
          'Non-canonical integer/length encoding in DAG-CBOR',
        );
      }
      return value;
    }
    throw FormatException('Reserved CBOR additional info: $additional');
  }

  dynamic _decodeSimpleOrFloat(_CborReader reader, int additional) {
    switch (additional) {
      case 20:
        return false;
      case 21:
        return true;
      case 22:
        return null;
      case 23:
        throw const FormatException('Undefined is not supported in DAG-CBOR');
      case 24:
        throw const FormatException(
          'Unassigned simple values are not supported in DAG-CBOR',
        );
      case 25:
        if (strict) {
          throw const FormatException(
            'Half-precision floats are not allowed in strict DAG-CBOR',
          );
        }
        return _checkedFloat(_readFloat16(reader));
      case 26:
        if (strict) {
          throw const FormatException(
            'Single-precision floats are not allowed in strict DAG-CBOR',
          );
        }
        return _checkedFloat(_readFloat32(reader));
      case 27:
        final value = _readFloat64(reader);
        if (strict && value == 0.0 && value.isNegative) {
          throw const FormatException(
            'Negative zero is not allowed in DAG-CBOR',
          );
        }
        return _checkedFloat(value);
      default:
        throw FormatException(
          'Unsupported CBOR simple/float additional info: $additional',
        );
    }
  }

  double _checkedFloat(double value) {
    if (!value.isFinite) {
      throw const FormatException(
        'Non-finite floats are not allowed in DAG-CBOR',
      );
    }
    // Normalize -0.0 (accepted only in lenient mode) to the canonical 0.0.
    return value == 0.0 ? 0.0 : value;
  }

  String _decodeString(_CborReader reader, BigInt argument) {
    final bytes = reader.readBytes(_argumentToInt(argument, reader));
    try {
      return utf8.decode(bytes);
    } catch (_) {
      throw const FormatException('Invalid UTF-8 string in DAG-CBOR');
    }
  }

  List<dynamic> _decodeList(_CborReader reader, BigInt argument, int depth) {
    final length = _argumentToInt(argument, reader);
    return List<dynamic>.generate(
      length,
      (_) => _decodeItem(reader, depth + 1),
    );
  }

  Map<String, dynamic> _decodeMap(
    _CborReader reader,
    BigInt argument,
    int depth,
  ) {
    final length = _argumentToInt(argument, reader);
    final map = <String, dynamic>{};
    Uint8List? previousKeyBytes;
    for (var i = 0; i < length; i++) {
      final key = _decodeItem(reader, depth + 1);
      if (key is! String) {
        throw const FormatException(
          'DAG-CBOR map keys must be strings',
        );
      }
      final keyBytes = Uint8List.fromList(utf8.encode(key));
      if (strict &&
          previousKeyBytes != null &&
          _compareKeyOrder(previousKeyBytes, keyBytes) >= 0) {
        throw const FormatException(
          'DAG-CBOR map keys are not in canonical order',
        );
      }
      previousKeyBytes = keyBytes;
      final value = _decodeItem(reader, depth + 1);
      if (map.containsKey(key)) {
        throw FormatException('Duplicate map key: $key');
      }
      map[key] = value;
    }
    return map;
  }

  dynamic _decodeTagged(_CborReader reader, BigInt tag, int depth) {
    if (tag == _tag42) {
      final inner = _decodeItem(reader, depth + 1);
      if (inner is! Uint8List) {
        throw const FormatException(
          'Tag 42 must be applied to a byte string',
        );
      }
      if (inner.isEmpty || inner[0] != 0x00) {
        throw const FormatException(
          'Tag 42 byte string must start with 0x00',
        );
      }
      return _decodeLink(Uint8List.fromList(inner.sublist(1)));
    }

    if (tag == _tag2 || tag == _tag3) {
      final inner = _decodeItem(reader, depth + 1);
      if (inner is! Uint8List) {
        throw FormatException(
          'Tag $tag must be applied to a byte string',
        );
      }
      if (strict && inner.isNotEmpty && inner[0] == 0x00) {
        throw const FormatException('Non-minimal big-integer byte string');
      }
      final n = _bytesToBigInt(inner);
      // Values representable as major types 0/1 must not use the tags:
      // the tag is superfluous and therefore non-canonical.
      if (strict && n <= _maxUint64) {
        throw FormatException(
          'Tag $tag used for a value representable without a tag',
        );
      }
      // Tag 3 represents -(1 + n).
      final value = tag == _tag2 ? n : -(n + BigInt.one);
      return _bigIntToDart(value);
    }

    throw FormatException('Unsupported CBOR tag in DAG-CBOR: $tag');
  }

  /// Validates the CID byte structure and returns the `{'/': cid}` link map.
  Map<String, String> _decodeLink(Uint8List cidBytes) {
    _validateCidBytes(cidBytes);
    try {
      final cid = CID.fromBytes(cidBytes);
      // Ensure the link round-trips through this codec's string form.
      return {'/': cid.encode()};
    } catch (e) {
      throw FormatException('Invalid CID in tag 42 link: $e');
    }
  }

  /// Performs a structural check on raw CID bytes so malformed or
  /// trailing-garbage CIDs are rejected before parsing.
  void _validateCidBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Empty CID bytes in tag 42 link');
    }
    // CIDv0: a bare sha2-256 multihash, exactly 0x12 0x20 + 32 digest bytes.
    if (bytes[0] == 0x12) {
      if (bytes.length != 34 || bytes[1] != 0x20) {
        throw const FormatException('Invalid CIDv0 bytes in tag 42 link');
      }
      return;
    }
    // CIDv1: 0x01 <codec varint> <hash-code varint> <digest-length varint>
    // <digest>. The declared digest length must consume the input exactly.
    if (bytes[0] != 0x01) {
      throw const FormatException('Unsupported CID version in tag 42 link');
    }
    var index = 1;
    try {
      final (_, codecLen) = readVarint(bytes, index);
      index += codecLen;
      final (_, hashLen) = readVarint(bytes, index);
      index += hashLen;
      final (digestLen, lenLen) = readVarint(bytes, index);
      index += lenLen;
      if (digestLen <= 0 || index + digestLen != bytes.length) {
        throw const FormatException('Invalid CID length in tag 42 link');
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Malformed CID bytes in tag 42 link: $e');
    }
  }

  // ---- Shared helpers ----

  /// Converts a [BigInt] to [int] when it fits in the signed 64-bit range,
  /// otherwise keeps it as [BigInt].
  static dynamic _bigIntToDart(BigInt value) {
    if (value >= _minInt64 && value <= _maxInt64) {
      return value.toInt();
    }
    return value;
  }

  static int _argumentToInt(BigInt value, _CborReader reader) {
    if (value < BigInt.zero || value > _maxInt64) {
      throw const FormatException(
        'CBOR length/argument out of supported range',
      );
    }
    final result = value.toInt();
    // Each item consumes at least one byte, so a declared length larger
    // than the remaining input can never be satisfied.
    if (result > reader.remaining) {
      throw const FormatException('Truncated DAG-CBOR input');
    }
    return result;
  }

  /// Canonical map-key order: encoded length first, then bytewise order.
  static int _compareKeyOrder(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return a.length.compareTo(b.length);
    }
    for (var i = 0; i < a.length; i++) {
      final cmp = a[i].compareTo(b[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  static Uint8List _bigIntToMinimalBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List(0);
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
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
    // value = (1 + mantissa/1024) * 2^(exponent-15)
    //       = (1024 + mantissa) * 2^(exponent-25)
    return (sign == 1 ? -1.0 : 1.0) *
        math.pow(2.0, exponent - 25).toDouble() *
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
}

/// Byte accumulator for the DAG-CBOR encoder.
class _CborWriter {
  final _builder = BytesBuilder();

  void addByte(int byte) => _builder.addByte(byte);
  void addBytes(List<int> bytes) => _builder.add(bytes);
  Uint8List toBytes() => _builder.toBytes();
}

/// Byte reader for the DAG-CBOR decoder.
class _CborReader {
  _CborReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;

  int get remaining => bytes.length - offset;

  int readByte() {
    if (offset >= bytes.length) {
      throw const FormatException('Truncated DAG-CBOR input');
    }
    return bytes[offset++];
  }

  int readUint8() => readByte();

  int readUint16() => (readUint8() << 8) | readUint8();

  int readUint32() =>
      (readUint8() << 24) |
      (readUint8() << 16) |
      (readUint8() << 8) |
      readUint8();

  BigInt readUint64() {
    var result = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      result = (result << 8) | BigInt.from(readUint8());
    }
    return result;
  }

  Uint8List readBytes(int length) {
    if (length < 0) {
      throw const FormatException('Negative length in DAG-CBOR');
    }
    if (offset + length > bytes.length) {
      throw const FormatException('Truncated DAG-CBOR input');
    }
    final result = Uint8List.fromList(bytes.sublist(offset, offset + length));
    offset += length;
    return result;
  }
}
