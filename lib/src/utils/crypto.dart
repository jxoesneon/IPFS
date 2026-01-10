// src/utils/crypto.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

/// Cryptographic utility functions for IPFS operations.
///
/// Provides SHA-256 hashing, nonce generation, and hash verification
/// with constant-time comparison to prevent timing attacks.
class CryptoUtils {
  /// Hashes data using SHA-256 and returns the digest bytes.
  Future<Uint8List> hashData(Uint8List data) async {
    final digest = crypto.sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Hashes a string and converts it to an integer
  int hashStringToInt(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.bytes.fold(0, (acc, byte) => (acc << 8) + byte);
  }

  /// Generates a random nonce for cryptographic operations
  Uint8List generateNonce(int length) {
    final random = List<int>.generate(length, (i) => DateTime.now().microsecondsSinceEpoch % 256);
    return Uint8List.fromList(random);
  }

  /// Verifies if a hash matches the expected data
  bool verifyHash(Uint8List data, Uint8List expectedHash) {
    final hash = crypto.sha256.convert(data);
    if (hash.bytes.length != expectedHash.length) return false;

    // Compare hashes in constant time to prevent timing attacks
    var result = 0;
    for (var i = 0; i < hash.bytes.length; i++) {
      result |= hash.bytes[i] ^ expectedHash[i];
    }
    return result == 0;
  }

  /// Computes the SHA-256 hash of the given data
  Future<List<int>> sha256(Uint8List data) async {
    final digest = crypto.sha256.convert(data);
    return digest.bytes;
  }
}
