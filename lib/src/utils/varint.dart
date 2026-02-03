// lib/src/utils/varint.dart

import 'dart:typed_data';

/// Encodes an integer as an unsigned variable-length integer (varint).
///
/// Varints use 7 bits per byte with the MSB indicating continuation.
/// Used in IPFS for compact encoding of lengths and identifiers.
Uint8List encodeVarint(int value) {
  final bytes = <int>[];
  do {
    var byte = value & 0x7f;
    value >>= 7;
    if (value > 0) {
      byte |= 0x80;
    }
    bytes.add(byte);
  } while (value > 0);
  return Uint8List.fromList(bytes);
}

/// Decodes an unsigned varint from a byte array.
///
/// Returns a tuple containing the decoded integer and the number of bytes read.
(int, int) decodeVarint(Uint8List bytes) {
  var value = 0;
  var shift = 0;
  var i = 0;
  for (; i < bytes.length; i++) {
    final byte = bytes[i];
    value |= (byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) {
      break;
    }
    shift += 7;
  }
  return (value, i + 1); // i + 1 to include the last byte read
}
