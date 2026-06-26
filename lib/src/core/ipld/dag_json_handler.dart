// lib/src/core/ipld/dag_json_handler.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_multihash/dart_multihash.dart';
import 'package:fixnum/fixnum.dart';
import 'package:multibase/multibase.dart';

/// The upper inclusive bound of the JSON safe integer range (2^53).
const int _maxSafeInteger = 0x20000000000000;

/// The lower inclusive bound of the JSON safe integer range.
const int _minSafeInteger = -0x20000000000000;

/// Errors thrown while encoding a value into DAG-JSON.
class DagJsonEncodingError implements Exception {
  /// Creates an encoding error.
  DagJsonEncodingError(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'DagJsonEncodingError: $message';
}

/// An integer value is outside the range that can be represented without loss
/// in a JSON number.
class DagJsonIntegerRangeError extends DagJsonEncodingError {
  /// Creates an integer range error.
  DagJsonIntegerRangeError(super.message);
}

/// Errors thrown while decoding a DAG-JSON string into an IPLD node.
class DagJsonDecodingError implements Exception {
  /// Creates a decoding error.
  DagJsonDecodingError(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'DagJsonDecodingError: $message';
}

/// Parser-level limits for [decodeDagJson].
///
/// Defaults follow the security recommendations in the DAG-JSON specification.
class DagJsonDecodeOptions {
  /// Creates a set of decode limits.
  const DagJsonDecodeOptions({
    this.maxStringLength = 8 * 1024 * 1024,
    this.maxNestingDepth = 1024,
    this.maxObjectSize = 1000000,
    this.maxDocumentSize = 32 * 1024 * 1024,
  });

  /// Maximum length of a decoded string value.
  final int maxStringLength;

  /// Maximum nesting depth of objects and arrays.
  final int maxNestingDepth;

  /// Maximum number of keys in a single object.
  final int maxObjectSize;

  /// Maximum total length of the input document.
  final int maxDocumentSize;
}

/// Encodes [node] into a compact, canonical DAG-JSON string.
///
/// The output matches the IPLD DAG-JSON specification: no whitespace, map keys
/// sorted by length then lexicographic UTF-8 bytes, bytes encoded as
/// `{"/":{"bytes":"<base64url-no-padding>"}}`, and CID links encoded as
/// `{"/":"<cid-string>"}`.
///
/// Throws [DagJsonEncodingError] for unsupported values, including non-finite
/// floats, integers outside the JSON safe range, and illegal use of the `/`
/// reserved namespace in literal maps.
String encodeDagJson(IPLDNode node) => DAGJsonHandler.encode(node);

/// Decodes a DAG-JSON string into an [IPLDNode].
///
/// In strict mode (the default), the parser rejects duplicate keys, invalid
/// reserved-namespace maps, integers outside the JSON safe range, and malformed
/// CID/base64url strings. In lenient mode, only reserved-namespace validation
/// and CID/bytes parsing remain strict.
///
/// Throws [DagJsonDecodingError] or [DagJsonIntegerRangeError] on invalid
/// input.
IPLDNode decodeDagJson(
  String json, {
  bool strict = true,
  DagJsonDecodeOptions? options,
}) =>
    DAGJsonHandler.decode(json, strict: strict, options: options);

/// Convenience that encodes [node] as DAG-JSON and hashes the UTF-8 bytes with
/// SHA2-256 under the DAG-JSON multicodec (0x0129).
///
/// The returned CID uses the CIDv1 + base32 lowercase representation that is the
/// canonical string form for DAG-JSON content addressing.
CID computeCidDagJson(IPLDNode node) {
  final bytes = utf8.encode(encodeDagJson(node));
  final digest = sha256.convert(bytes);
  final multihash = Multihash.encode(
    'sha2-256',
    Uint8List.fromList(digest.bytes),
  );
  return CID.v1('dag-json', multihash);
}

/// Handles spec-compliant DAG-JSON encoding and decoding for IPLD nodes.
///
/// Use the top-level helpers [encodeDagJson], [decodeDagJson], and
/// [computeCidDagJson] for the public API, or call the static methods directly.
class DAGJsonHandler {
  /// Encodes an [IPLDNode] to a spec-compliant DAG-JSON string.
  static String encode(IPLDNode node) {
    final buffer = StringBuffer();
    _writeNode(node, buffer);
    return buffer.toString();
  }

  /// Decodes a DAG-JSON string into an [IPLDNode].
  static IPLDNode decode(
    String jsonStr, {
    bool strict = true,
    DagJsonDecodeOptions? options,
  }) {
    final parser = _DagJsonParser(
      jsonStr,
      strict,
      options ?? const DagJsonDecodeOptions(),
    );
    return parser.parse();
  }

  static void _writeNode(IPLDNode node, StringBuffer buffer) {
    switch (node.kind) {
      case Kind.NULL:
        buffer.write('null');
      case Kind.BOOL:
        buffer.write(node.boolValue ? 'true' : 'false');
      case Kind.INTEGER:
        final value = node.intValue.toInt();
        if (value < _minSafeInteger || value > _maxSafeInteger) {
          throw DagJsonIntegerRangeError(
            'Integer $value is outside the JSON safe integer range '
            '[$_minSafeInteger, $_maxSafeInteger]',
          );
        }
        buffer.write(value);
      case Kind.FLOAT:
        final value = node.floatValue;
        if (!value.isFinite) {
          throw DagJsonEncodingError('Non-finite float value: $value');
        }
        // json.encode emits the shortest JSON number representation for doubles
        // (e.g. 1.0, 1e10) and rejects NaN/Infinity, which we already check.
        buffer.write(json.encode(value));
      case Kind.STRING:
        buffer.write(json.encode(node.stringValue));
      case Kind.BYTES:
        final encoded = base64Url
            .encode(Uint8List.fromList(node.bytesValue))
            .replaceAll('=', '');
        buffer.write('{');
        buffer.write(json.encode('/'));
        buffer.write(':{');
        buffer.write(json.encode('bytes'));
        buffer.write(':');
        buffer.write(json.encode(encoded));
        buffer.write('}}');
      case Kind.LIST:
        final values = node.listValue.values;
        buffer.write('[');
        for (var i = 0; i < values.length; i++) {
          if (i > 0) buffer.write(',');
          _writeNode(values[i], buffer);
        }
        buffer.write(']');
      case Kind.MAP:
        final entries = node.mapValue.entries;
        final seen = <String>{};
        for (final entry in entries) {
          if (!seen.add(entry.key)) {
            throw DagJsonEncodingError('Duplicate map key "${entry.key}"');
          }
          if (entry.key == '/') {
            throw DagJsonEncodingError(
              'Reserved map key "/" in literal map; use Kind.LINK or '
              'Kind.BYTES for the reserved namespace',
            );
          }
        }
        final sorted = entries.toList()
          ..sort((a, b) => _canonicalKeyCompare(a.key, b.key));
        buffer.write('{');
        for (var i = 0; i < sorted.length; i++) {
          if (i > 0) buffer.write(',');
          buffer.write(json.encode(sorted[i].key));
          buffer.write(':');
          _writeNode(sorted[i].value, buffer);
        }
        buffer.write('}');
      case Kind.LINK:
        final link = node.linkValue;
        final multihash = Multihash.decode(Uint8List.fromList(link.multihash));
        final cid = CID(
          version: link.version,
          multihash: multihash,
          codec: link.codec.isEmpty ? 'dag-pb' : link.codec,
          multibaseType:
              link.version == 0 ? Multibase.base58btc : Multibase.base32,
        );
        final cidStr = cid.encode();
        buffer.write('{');
        buffer.write(json.encode('/'));
        buffer.write(':');
        buffer.write(json.encode(cidStr));
        buffer.write('}');
      default:
        throw DagJsonEncodingError('Unsupported IPLD kind: ${node.kind}');
    }
  }

  static int _canonicalKeyCompare(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    final aLen = aBytes.length;
    final bLen = bBytes.length;
    if (aLen < bLen) return -1;
    if (aLen > bLen) return 1;
    for (var i = 0; i < aLen; i++) {
      final av = aBytes[i];
      final bv = bBytes[i];
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return 0;
  }
}

class _DagJsonParser {
  _DagJsonParser(this._input, this._strict, this._options) {
    if (_input.length > _options.maxDocumentSize) {
      throw DagJsonDecodingError(
        'Document length ${_input.length} exceeds maxDocumentSize '
        '${_options.maxDocumentSize}',
      );
    }
  }

  final String _input;
  final bool _strict;
  final DagJsonDecodeOptions _options;
  int _pos = 0;
  int _depth = 0;

  IPLDNode parse() {
    final node = _parseValue();
    _skipWhitespace();
    if (_pos != _input.length) {
      throw DagJsonDecodingError('Trailing data after JSON value');
    }
    return node;
  }

  IPLDNode _parseValue() {
    _skipWhitespace();
    if (_pos >= _input.length) {
      throw DagJsonDecodingError('Unexpected end of input');
    }
    final c = _input.codeUnitAt(_pos);
    switch (c) {
      case 0x7b: // {
        return _parseObject();
      case 0x5b: // [
        return _parseArray();
      case 0x22: // "
        return _parseStringValue();
      case 0x74: // t
        return _parseTrue();
      case 0x66: // f
        return _parseFalse();
      case 0x6e: // n
        return _parseNull();
      default:
        if (c == 0x2d || (c >= 0x30 && c <= 0x39)) {
          return _parseNumber();
        }
        throw DagJsonDecodingError(
          'Unexpected character at position $_pos: 0x${c.toRadixString(16)}',
        );
    }
  }

  IPLDNode _parseObject() {
    assert(_input.codeUnitAt(_pos) == 0x7b);
    _depth++;
    if (_depth > _options.maxNestingDepth) {
      throw DagJsonDecodingError('Nesting depth exceeded');
    }
    _pos++;

    final entries = <String, IPLDNode>{};
    _skipWhitespace();
    if (_pos < _input.length && _input.codeUnitAt(_pos) == 0x7d) {
      _pos++;
      _depth--;
      return _finishObject(entries);
    }

    while (true) {
      _skipWhitespace();
      if (_pos >= _input.length || _input.codeUnitAt(_pos) != 0x22) {
        throw DagJsonDecodingError('Expected string key at position $_pos');
      }
      final keyNode = _parseStringValue();
      final key = keyNode.stringValue;

      if (_strict && entries.containsKey(key)) {
        throw DagJsonDecodingError('Duplicate key "$key"');
      }

      _skipWhitespace();
      if (_pos >= _input.length || _input.codeUnitAt(_pos) != 0x3a) {
        throw DagJsonDecodingError('Expected colon at position $_pos');
      }
      _pos++;

      final value = _parseValue();
      entries[key] = value;

      if (entries.length > _options.maxObjectSize) {
        throw DagJsonDecodingError('Object size exceeded maxObjectSize');
      }

      _skipWhitespace();
      if (_pos >= _input.length) {
        throw DagJsonDecodingError('Unexpected end of input');
      }
      final c = _input.codeUnitAt(_pos);
      if (c == 0x2c) {
        // Another member follows.
        _pos++;
        continue;
      } else if (c == 0x7d) {
        _pos++;
        break;
      } else {
        throw DagJsonDecodingError(
          'Expected comma or closing brace at position $_pos',
        );
      }
    }

    _depth--;
    return _finishObject(entries);
  }

  IPLDNode _finishObject(Map<String, IPLDNode> entries) {
    if (!entries.containsKey('/')) {
      final map = IPLDMap();
      for (final entry in entries.entries) {
        map.entries.add(MapEntry(key: entry.key, value: entry.value));
      }
      return IPLDNode(kind: Kind.MAP, mapValue: map);
    }

    // Reserved namespace: the object must match one of the two valid forms.
    // If it does not, it is treated as a literal map.
    if (entries.length == 1) {
      final value = entries['/']!;
      if (value.kind == Kind.STRING) {
        try {
          return _decodeLink(value.stringValue);
        } catch (_) {
          // Not a valid CID link; treat as a literal map.
        }
      } else if (value.kind == Kind.MAP) {
        try {
          return _decodeBytes(value.mapValue);
        } catch (_) {
          // Not a valid bytes map; treat as a literal map.
        }
      }
    }

    // Literal map (including escaped "/" keys that are not reserved forms).
    final map = IPLDMap();
    for (final entry in entries.entries) {
      map.entries.add(MapEntry(key: entry.key, value: entry.value));
    }
    return IPLDNode(kind: Kind.MAP, mapValue: map);
  }

  IPLDNode _decodeLink(String cidStr) {
    try {
      final cid = CID.decode(cidStr);
      return IPLDNode(
        kind: Kind.LINK,
        linkValue: IPLDLink(
          version: cid.version,
          codec: cid.codec ?? '',
          multihash: cid.multihash.toBytes(),
        ),
      );
    } catch (e) {
      throw DagJsonDecodingError('Invalid CID link "$cidStr": $e');
    }
  }

  IPLDNode _decodeBytes(IPLDMap bytesMap) {
    if (bytesMap.entries.length != 1) {
      throw DagJsonDecodingError('Invalid bytes reserved namespace');
    }
    final entry = bytesMap.entries.first;
    if (entry.key != 'bytes' || entry.value.kind != Kind.STRING) {
      throw DagJsonDecodingError('Invalid bytes reserved namespace');
    }
    var b64 = entry.value.stringValue;
    if (b64.contains('=')) {
      throw DagJsonDecodingError('Bytes base64url string must not contain padding');
    }
    // DAG-JSON uses unpadded base64url; Dart's decoder requires padding.
    b64 = base64Url.normalize(b64);
    try {
      final bytes = Uint8List.fromList(base64Url.decode(b64));
      return IPLDNode(kind: Kind.BYTES, bytesValue: bytes);
    } catch (e) {
      throw DagJsonDecodingError('Invalid base64url bytes string: $e');
    }
  }

  IPLDNode _parseArray() {
    assert(_input.codeUnitAt(_pos) == 0x5b);
    _depth++;
    if (_depth > _options.maxNestingDepth) {
      throw DagJsonDecodingError('Nesting depth exceeded');
    }
    _pos++;

    final values = <IPLDNode>[];
    _skipWhitespace();
    if (_pos < _input.length && _input.codeUnitAt(_pos) == 0x5d) {
      _pos++;
      _depth--;
      return IPLDNode(kind: Kind.LIST, listValue: IPLDList(values: values));
    }

    while (true) {
      final value = _parseValue();
      values.add(value);

      _skipWhitespace();
      if (_pos >= _input.length) {
        throw DagJsonDecodingError('Unexpected end of input');
      }
      final c = _input.codeUnitAt(_pos);
      if (c == 0x2c) {
        _pos++;
        continue;
      } else if (c == 0x5d) {
        _pos++;
        break;
      } else {
        throw DagJsonDecodingError(
          'Expected comma or closing bracket at position $_pos',
        );
      }
    }

    _depth--;
    return IPLDNode(kind: Kind.LIST, listValue: IPLDList(values: values));
  }

  IPLDNode _parseStringValue() {
    assert(_input.codeUnitAt(_pos) == 0x22);
    final buffer = StringBuffer();
    buffer.write('"');
    _pos++;

    while (_pos < _input.length) {
      final c = _input.codeUnitAt(_pos);
      if (c == 0x22) {
        // Closing quote.
        buffer.write('"');
        _pos++;
        break;
      } else if (c == 0x5c) {
        // Escape sequence: include the backslash and the next character.
        buffer.write('\\');
        _pos++;
        if (_pos >= _input.length) {
          throw DagJsonDecodingError('Unexpected end of string escape');
        }
        buffer.write(_input[_pos]);
        _pos++;
      } else {
        buffer.write(_input[_pos]);
        _pos++;
      }
    }

    final token = buffer.toString();
    if (!token.endsWith('"')) {
      throw DagJsonDecodingError('Unterminated string');
    }

    String value;
    try {
      value = json.decode(token) as String;
    } catch (e) {
      throw DagJsonDecodingError('Invalid string literal: $e');
    }

    if (_strict && value.length > _options.maxStringLength) {
      throw DagJsonDecodingError('String exceeds maxStringLength');
    }

    return IPLDNode(kind: Kind.STRING, stringValue: value);
  }

  IPLDNode _parseTrue() {
    if (_input.startsWith('true', _pos)) {
      _pos += 4;
      return IPLDNode(kind: Kind.BOOL, boolValue: true);
    }
    throw DagJsonDecodingError('Invalid literal "true" at position $_pos');
  }

  IPLDNode _parseFalse() {
    if (_input.startsWith('false', _pos)) {
      _pos += 5;
      return IPLDNode(kind: Kind.BOOL, boolValue: false);
    }
    throw DagJsonDecodingError('Invalid literal "false" at position $_pos');
  }

  IPLDNode _parseNull() {
    if (_input.startsWith('null', _pos)) {
      _pos += 4;
      return IPLDNode(kind: Kind.NULL);
    }
    throw DagJsonDecodingError('Invalid literal "null" at position $_pos');
  }

  IPLDNode _parseNumber() {
    final start = _pos;
    var isFloat = false;

    if (_input.codeUnitAt(_pos) == 0x2d) {
      _pos++;
    }
    while (_pos < _input.length) {
      final c = _input.codeUnitAt(_pos);
      if (c >= 0x30 && c <= 0x39) {
        _pos++;
      } else if (c == 0x2e || c == 0x65 || c == 0x45) {
        isFloat = true;
        _pos++;
        if (c == 0x65 || c == 0x45) {
          if (_pos < _input.length) {
            final sign = _input.codeUnitAt(_pos);
            if (sign == 0x2b || sign == 0x2d) {
              _pos++;
            }
          }
        }
      } else {
        break;
      }
    }

    final token = _input.substring(start, _pos);
    if (token == '-' || token.isEmpty) {
      throw DagJsonDecodingError('Invalid number at position $start');
    }

    if (isFloat) {
      final value = double.parse(token);
      if (!value.isFinite) {
        throw DagJsonDecodingError('Non-finite float value');
      }
      return IPLDNode(kind: Kind.FLOAT, floatValue: value);
    } else {
      final value = int.parse(token);
      if (_strict && (value < _minSafeInteger || value > _maxSafeInteger)) {
        throw DagJsonIntegerRangeError(
          'Integer $value is outside the JSON safe integer range',
        );
      }
      return IPLDNode(kind: Kind.INTEGER, intValue: Int64(value));
    }
  }

  void _skipWhitespace() {
    while (_pos < _input.length) {
      final c = _input.codeUnitAt(_pos);
      if (c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d) {
        _pos++;
      } else {
        break;
      }
    }
  }
}
