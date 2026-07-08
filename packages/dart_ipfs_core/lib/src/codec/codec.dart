// lib/src/codec/codec.dart
import 'dart:typed_data';

/// Interface for all IPLD codecs in dart_ipfs_core.
///
/// Codecs operate on plain Dart values: [Map], [List], [Uint8List],
/// [String], [int], [double], [bool], and [null].
abstract class IPLDCodec {
  /// Multicodec name (e.g., 'dag-cbor').
  String get name;

  /// Multicodec integer code (e.g., `0x71` for DAG-CBOR).
  int get code;

  /// Encodes [value] into bytes.
  Future<Uint8List> encode(dynamic value);

  /// Decodes bytes into a Dart value.
  Future<dynamic> decode(Uint8List data);
}
