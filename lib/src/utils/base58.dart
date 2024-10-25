// lib/src/utils/base58.dart

import 'dart:typed_data';

const String _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

class Base58 {
  /// Encodes a Uint8List to a Base58 string.
  String encode(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '';
    }

    BigInt number = BigInt.from(0);
    for (final byte in bytes) {
      number = number * BigInt.from(256) + BigInt.from(byte);
    }

    String encoded = '';
    while (number > BigInt.from(0)) {
      final remainder = number % BigInt.from(58);
      number = number ~/ BigInt.from(58);
      encoded = _base58Alphabet[remainder.toInt()] + encoded;
    }

    // Add leading zeros
    for (final byte in bytes) {
      if (byte == 0) {
        encoded = _base58Alphabet[0] + encoded;
      } else {
        break;
      }
    }

    return encoded;
  }

  Uint8List base58Decode(String input) {
    final BigInt base = BigInt.from(58);
    BigInt result = BigInt.zero;
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final index = _base58Alphabet.indexOf(char);
      if (index == -1) {
        throw ArgumentError('Invalid base58 character: $char');
      }
      result = result * base + BigInt.from(index);
    }

    // Add leading zeros
    final leadingZeros =
        input.split('').takeWhile((c) => c == _base58Alphabet[0]).length;
    final bytes = bigIntToUint8List(
        result); // Use the helper function to convert BigInt to Uint8List
    final decoded = Uint8List(leadingZeros + bytes.length)
      ..setAll(leadingZeros, bytes);

    return decoded;
  }

  /// Converts a BigInt to a Uint8List.
  Uint8List bigIntToUint8List(BigInt bigInt) {
    final data = ByteData((bigInt.bitLength / 8).ceil());
    for (int i = 0; i < data.lengthInBytes; i++) {
      data.setUint8(i, bigInt.toUnsigned(8).toInt());
      bigInt = bigInt >> 8;
    }
    return data.buffer.asUint8List();
  }
}
