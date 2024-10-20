// lib/src/utils/crypto.dart

import 'dart:convert'; // Import dart:convert for utf8
import 'package:crypto/crypto.dart';

/// Hashes a string and converts the hash to an integer.
int hashStringToInt(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes); // Use SHA-256 hash
  return digest.bytes
      .fold(0, (acc, byte) => (acc << 8) + byte); // Convert bytes to integer
}
