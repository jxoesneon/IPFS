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
    if (value is BigInt) return _toCborBigInt(value);
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
      return _toCborMap(value);
    }
    throw ArgumentError(
      'Unsupported value type for DAG-CBOR: ${value.runtimeType}',
    );
  }

  /// Converts a Dart [Map] into a canonically-ordered [cbor.CborMap].
  ///
  /// Map entries are sorted by the byte-wise lexicographic order of their
  /// encoded CBOR keys, as required by canonical DAG-CBOR.
  cbor.CborMap _toCborMap(Map<dynamic, dynamic> value) {
    final entries = value.entries.toList();
    entries.sort((a, b) {
      final aBytes = cbor.cborEncode(_toCbor(a.key));
      final bBytes = cbor.cborEncode(_toCbor(b.key));
      final minLength = aBytes.length < bBytes.length ? aBytes.length : bBytes.length;
      for (var i = 0; i < minLength; i++) {
        final cmp = aBytes[i] - bBytes[i];
        if (cmp != 0) return cmp;
      }
      return aBytes.length - bBytes.length;
    });

    return cbor.CborMap.fromEntries(
      entries.map(
        (entry) => MapEntry(
          _toCbor(entry.key),
          _toCbor(entry.value),
        ),
      ),
    );
  }

  /// Converts a [BigInt] to a CBOR value.
  ///
  /// Values inside the signed 64-bit range become regular CBOR ints, while
  /// values outside that range become CBOR bignums (tag 2 or 3).
  cbor.CborValue _toCborBigInt(BigInt value) {
    const minInt64 = -9223372036854775808;
    const maxInt64 = 9223372036854775807;
    if (value.compareTo(BigInt.from(minInt64)) >= 0 &&
        value.compareTo(BigInt.from(maxInt64)) <= 0) {
      return cbor.CborInt(value);
    }
    return cbor.CborBigInt(value);
  }

  /// Converts a [cbor.CborValue] back to a Dart value.
  dynamic _fromCbor(cbor.CborValue value) {
    if (value is cbor.CborNull) return null;
    if (value is cbor.CborBool) return value.value;
    if (value is cbor.CborFloat) return value.value;
    if (value is cbor.CborString) return value.toString();
    if (value is cbor.CborBigInt) {
      return value.toBigInt();
    }
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
    if (value is cbor.CborInt) return value.toInt();
    return value.toObject();
  }
}
