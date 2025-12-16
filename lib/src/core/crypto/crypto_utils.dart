// lib/src/core/crypto/crypto_utils.dart
//
// SEC-001: Cryptographic utilities for secure key storage
// Provides PBKDF2 key derivation, AES-256-GCM encryption, and memory zeroing.

import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:cryptography/cryptography.dart' as crypto;

/// Result of AES-GCM encryption containing ciphertext, nonce, and auth tag.
class EncryptedData {
  /// The encrypted ciphertext (includes auth tag at end for AES-GCM).
  final Uint8List ciphertext;

  /// The 12-byte nonce/IV used for encryption.
  final Uint8List nonce;

  const EncryptedData({required this.ciphertext, required this.nonce});

  /// Serializes to bytes: [nonce (12)] + [ciphertext]
  Uint8List toBytes() {
    return Uint8List.fromList([...nonce, ...ciphertext]);
  }

  /// Deserializes from bytes
  static EncryptedData fromBytes(Uint8List bytes) {
    if (bytes.length < 12) {
      throw ArgumentError('Encrypted data too short');
    }
    return EncryptedData(
      nonce: bytes.sublist(0, 12),
      ciphertext: bytes.sublist(12),
    );
  }
}

/// Cryptographic utilities for secure key management.
///
/// **Security Features:**
/// - PBKDF2 with configurable iterations (default 100,000)
/// - AES-256-GCM authenticated encryption
/// - Memory zeroing for sensitive data
/// - Cryptographically secure random generation
class CryptoUtils {
  /// Default PBKDF2 iteration count.
  /// 100,000 iterations provides ~100ms on modern hardware.
  static const int defaultIterations = 100000;

  /// AES key size in bytes (256 bits).
  static const int keySize = 32;

  /// AES-GCM nonce size in bytes.
  static const int nonceSize = 12;

  /// PBKDF2 salt size in bytes.
  static const int saltSize = 16;

  /// Derives a key from a password using PBKDF2-HMAC-SHA256.
  ///
  /// [password] - The password to derive from
  /// [salt] - Random salt (use [randomBytes] to generate)
  /// [iterations] - PBKDF2 iterations (default 100,000)
  /// [keyLength] - Output key length in bytes (default 32 for AES-256)
  static Uint8List deriveKey(
    String password,
    Uint8List salt, {
    int iterations = defaultIterations,
    int keyLength = keySize,
  }) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, keyLength));

    final passwordBytes = Uint8List.fromList(password.codeUnits);
    final key = Uint8List(keyLength);
    pbkdf2.deriveKey(passwordBytes, 0, key, 0);

    // Zero password bytes
    zeroMemory(passwordBytes);

    return key;
  }

  /// Encrypts data using AES-256-GCM.
  ///
  /// Returns [EncryptedData] containing ciphertext and nonce.
  /// The ciphertext includes the 16-byte authentication tag.
  static Future<EncryptedData> encrypt(
    Uint8List plaintext,
    Uint8List key,
  ) async {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes');
    }

    final nonce = randomBytes(nonceSize);
    final algorithm = crypto.AesGcm.with256bits();

    final secretKey = crypto.SecretKey(key);
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine ciphertext + MAC
    final ciphertext = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return EncryptedData(ciphertext: ciphertext, nonce: nonce);
  }

  /// Decrypts AES-256-GCM encrypted data.
  ///
  /// Throws [crypto.SecretBoxAuthenticationError] if authentication fails.
  static Future<Uint8List> decrypt(
    EncryptedData encrypted,
    Uint8List key,
  ) async {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes');
    }

    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);

    // Split ciphertext and MAC (last 16 bytes)
    final ciphertext = encrypted.ciphertext;
    if (ciphertext.length < 16) {
      throw ArgumentError('Ciphertext too short');
    }

    final macBytes = ciphertext.sublist(ciphertext.length - 16);
    final actualCiphertext = ciphertext.sublist(0, ciphertext.length - 16);

    final secretBox = crypto.SecretBox(
      actualCiphertext,
      nonce: encrypted.nonce,
      mac: crypto.Mac(macBytes),
    );

    final plaintext = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(plaintext);
  }

  /// Zeros a memory buffer to prevent sensitive data from lingering.
  ///
  /// **Security Note:** Call this immediately after using sensitive data
  /// like private keys, passwords, or seeds.
  static void zeroMemory(Uint8List buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  /// Generates cryptographically secure random bytes.
  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Generates a random salt for PBKDF2.
  static Uint8List generateSalt() {
    return randomBytes(saltSize);
  }

  /// Constant-time comparison to prevent timing attacks.
  static bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
