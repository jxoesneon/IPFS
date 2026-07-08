// lib/src/codec/dag_cbor_codec.dart
import 'dart:typed_data';

import 'package:cbor/cbor.dart' as cbor;

import '../cid/cid.dart';
import 'codec.dart';

/// Codec for DAG-CBOR.
///
/// The DAG-CBOR multicodec (`0x71`) encodes IPLD data as canonical CBOR.
/// CID links are represented as CBOR tag 42 with the CID bytes prefixed by
/// `0x00`, matching the IPLD DAG-CBOR specification.
class DagCborCodec implements IPLDCodec {
  @override
  String get name => 'dag-cbor';

  @override
  int get code => 0x71;

  @override
  Future<Uint8List> encode(dynamic value) async {
    final cborValue = _toCbor(value);
    return Uint8List.fromList(cbor.cborEncode(cborValue));
  }

  @override
  Future<dynamic> decode(Uint8List data) async {
    final decoded = cbor.cborDecode(data);
    return _fromCbor(decoded);
  }

  /// Converts a Dart value to a [cbor.CborValue].
  cbor.CborValue _toCbor(dynamic value) {
    if (value == null) return const cbor.CborNull();
    if (value is bool) return cbor.CborBool(value);
    if (value is int) return cbor.CborValue(value);
    if (value is double) return cbor.CborValue(value);
    if (value is String) return cbor.CborString(value);
    if (value is Uint8List) return cbor.CborBytes(value);
    if (value is List<int>) return cbor.CborBytes(Uint8List.fromList(value));
    if (value is List) {
      return cbor.CborList(value.map(_toCbor).toList());
    }
    if (value is Map) {
      // CID link: {'/': 'cid-string'} -> CBOR tag 42 with 0x00 + CID bytes
      if (value.length == 1 && value.containsKey('/')) {
        final link = value['/'];
        if (link is String) {
          final cid = CID.decode(link);
          final cidBytes = cid.toBytes();
          final taggedBytes = Uint8List(cidBytes.length + 1);
          taggedBytes[0] = 0x00;
          taggedBytes.setAll(1, cidBytes);
          return cbor.CborBytes(taggedBytes, tags: const [42]);
        }
      }
      return cbor.CborMap({
        for (final entry in value.entries)
          cbor.CborValue(entry.key.toString()): _toCbor(entry.value),
      });
    }
    throw ArgumentError(
      'Unsupported value type for DAG-CBOR: ${value.runtimeType}',
    );
  }

  /// Converts a [cbor.CborValue] back to a Dart value.
  dynamic _fromCbor(cbor.CborValue value) {
    if (value is cbor.CborNull) return null;
    if (value is cbor.CborBool) return value.value;
    if (value is cbor.CborInt) return value.toInt();
    if (value is cbor.CborFloat) return value.value;
    if (value is cbor.CborString) return value.toString();
    if (value is cbor.CborBytes) {
      final bytes = Uint8List.fromList(value.bytes);
      // CID link tag 42
      if (value.tags.contains(42) && bytes.isNotEmpty && bytes[0] == 0x00) {
        final cid = CID.fromBytes(bytes.sublist(1));
        return {'/': cid.encode()};
      }
      return bytes;
    }
    if (value is cbor.CborList) {
      return value.map(_fromCbor).toList();
    }
    if (value is cbor.CborMap) {
      return {
        for (final entry in value.entries)
          _fromCbor(entry.key).toString(): _fromCbor(entry.value),
      };
    }
    return value.toObject();
  }
}
