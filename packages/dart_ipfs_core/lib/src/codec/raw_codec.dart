// lib/src/codec/raw_codec.dart
import 'dart:typed_data';

import 'codec.dart';

/// Codec for raw binary data.
///
/// The raw multicodec (`0x55`) encodes a [Uint8List] as itself and decodes
/// bytes into a [Uint8List].
class RawCodec implements IPLDCodec {
  @override
  String get name => 'raw';

  @override
  int get code => 0x55;

  @override
  Future<Uint8List> encode(dynamic value) async {
    if (value is! Uint8List) {
      throw ArgumentError('Raw codec requires Uint8List input');
    }
    return Uint8List.fromList(value);
  }

  @override
  Future<Uint8List> decode(Uint8List data) async => Uint8List.fromList(data);
}
