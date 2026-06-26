// lib/src/utils/varint.dart
import 'dart:typed_data';

/// Reads a varint from [bytes] starting at [offset].
///
/// Returns a record containing the decoded value and the number of bytes
/// consumed. Throws [FormatException] if the varint is malformed or exceeds
/// the maximum length of 9 bytes.
(int value, int length) readVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  var index = offset;

  while (true) {
    if (index >= bytes.length) {
      throw const FormatException('Truncated varint');
    }
    final byte = bytes[index];
    value |= (byte & 0x7f) << shift;
    index++;
    if ((byte & 0x80) == 0) {
      return (value, index - offset);
    }
    shift += 7;
    if (shift > 63) {
      throw const FormatException('Varint too long');
    }
  }
}

/// Encodes [value] as a varint into a [Uint8List].
Uint8List encodeVarint(int value) {
  if (value < 0) {
    throw ArgumentError('Value must be non-negative: $value');
  }

  final bytes = <int>[];
  while (value >= 0x80) {
    bytes.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.add(value);
  return Uint8List.fromList(bytes);
}
