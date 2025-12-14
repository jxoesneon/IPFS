// lib/src/utils/base58.dart

import 'dart:typed_data';

/// The Bitcoin/IPFS Base58 alphabet (excludes 0, O, I, l).
const String _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/// Base58 encoding/decoding for IPFS identifiers.
///
/// Base58 is a binary-to-text encoding scheme used in Bitcoin and IPFS
/// for representing large integers (like peer IDs and keys) as
/// human-readable strings. It excludes visually ambiguous characters
/// (0, O, I, l) to reduce transcription errors.
///
/// Example:
/// ```dart
/// final base58 = Base58();
///
/// // Encode bytes to Base58
/// final encoded = base58.encode(peerIdBytes);
/// print('Peer ID: $encoded');
///
/// // Decode Base58 back to bytes
/// final decoded = base58.base58Decode(encoded);
/// ```
///
/// See also:
/// - [CID] which uses multibase encoding including Base58
class Base58 {
  /// Encodes a [bytes] array to a Base58 string.
  ///
  /// Preserves leading zeros as '1' characters.
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

  /// Decodes a Base58 [input] string back to bytes.
  ///
  /// Throws [ArgumentError] for invalid Base58 characters.
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

  /// Converts a BigInt to a Uint8List (Big Endian).
  Uint8List bigIntToUint8List(BigInt bigInt) {
    if (bigInt == BigInt.zero) return Uint8List(0);
    final length = (bigInt.bitLength + 7) ~/ 8;
    final data = Uint8List(length);
    for (int i = length - 1; i >= 0; i--) {
      data[i] = bigInt.toUnsigned(8).toInt();
      bigInt = bigInt >> 8;
    }
    return data;
  }
}
