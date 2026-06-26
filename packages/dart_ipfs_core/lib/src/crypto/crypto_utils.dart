// lib/src/crypto/crypto_utils.dart
//
// SEC-001: Cryptographic utilities for secure key storage.
// Provides PBKDF2 key derivation, AES-256-GCM encryption, and memory zeroing.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:pointycastle/export.dart';

/// Result of AES-GCM encryption containing ciphertext and nonce.
///
/// The [ciphertext] includes the authentication tag at the end.
class EncryptedData {
  /// Creates an [EncryptedData] with the ciphertext and nonce.
  const EncryptedData({required this.ciphertext, required this.nonce});

  /// The encrypted ciphertext (includes 16-byte auth tag at end for AES-GCM).
  final Uint8List ciphertext;

  /// The 12-byte nonce/IV used for encryption.
  final Uint8List nonce;

  /// Serializes to bytes: [nonce (12 bytes)] + [ciphertext].
  ///
  /// This format is suitable for storage or transmission.
  Uint8List toBytes() {
    final result = Uint8List(nonce.length + ciphertext.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, ciphertext);
    return result;
  }

  /// Deserializes from bytes.
  ///
  /// Expects the first 12 bytes to be the nonce.
  /// Throws [ArgumentError] if [bytes] is shorter than 12 bytes.
  static EncryptedData fromBytes(Uint8List bytes) {
    if (bytes.length < CryptoUtils.nonceSize) {
      throw ArgumentError(
        'Encrypted data too short: expected at least ${CryptoUtils.nonceSize} bytes',
      );
    }
    return EncryptedData(
      nonce: bytes.sublist(0, CryptoUtils.nonceSize),
      ciphertext: bytes.sublist(CryptoUtils.nonceSize),
    );
  }
}

/// Cryptographic utilities for secure key management.
///
/// **Security Features:**
/// - PBKDF2-HMAC-SHA256 with configurable iterations (default 100,000)
/// - AES-256-GCM authenticated encryption
/// - Memory zeroing for sensitive data
/// - Cryptographically secure random generation
/// - Constant-time comparison
class CryptoUtils {
  /// Default PBKDF2 iteration count.
  ///
  /// 100,000 iterations provides a good balance between security and performance
  /// (~100ms on modern hardware).
  static const int defaultIterations = 100000;

  /// AES key size in bytes (256 bits).
  static const int keySize = 32;

  /// AES-GCM nonce size in bytes (96 bits).
  static const int nonceSize = 12;

  /// PBKDF2 salt size in bytes.
  static const int saltSize = 16;

  /// AES-GCM authentication tag size in bytes (128 bits).
  static const int tagSize = 16;

  /// Derives a key from a password using PBKDF2-HMAC-SHA256.
  ///
  /// [password] - The password to derive from (must not be empty)
  /// [salt] - Random salt (must be at least 8 bytes, use [generateSalt])
  /// [iterations] - PBKDF2 iterations (default [defaultIterations])
  /// [keyLength] - Output key length in bytes (default [keySize])
  ///
  /// Returns the derived key as a [Uint8List].
  static Uint8List deriveKey(
    String password,
    Uint8List salt, {
    int iterations = defaultIterations,
    int keyLength = keySize,
  }) {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }
    if (salt.length < 8) {
      throw ArgumentError('Salt must be at least 8 bytes');
    }

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, keyLength));

    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final key = Uint8List(keyLength);
    pbkdf2.deriveKey(passwordBytes, 0, key, 0);

    // Zero password bytes
    zeroMemory(passwordBytes);

    return key;
  }

  /// Encrypts data using AES-256-GCM.
  ///
  /// [plaintext] - The data to encrypt
  /// [key] - The 32-byte AES-256 key
  ///
  /// Returns [EncryptedData] containing ciphertext and nonce.
  /// The ciphertext includes the 16-byte authentication tag.
  ///
  /// Throws [ArgumentError] if the key length is incorrect.
  static Future<EncryptedData> encrypt(
    Uint8List plaintext,
    Uint8List key,
  ) async {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes (AES-256)');
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
    final ciphertext = Uint8List(
      secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    ciphertext.setAll(0, secretBox.cipherText);
    ciphertext.setAll(secretBox.cipherText.length, secretBox.mac.bytes);

    return EncryptedData(ciphertext: ciphertext, nonce: nonce);
  }

  /// Decrypts AES-256-GCM encrypted data.
  ///
  /// [encrypted] - The encrypted data to decrypt
  /// [key] - The 32-byte AES-256 key
  ///
  /// Throws [crypto.SecretBoxAuthenticationError] if authentication fails.
  /// Throws [ArgumentError] if the key or ciphertext length is incorrect.
  static Future<Uint8List> decrypt(
    EncryptedData encrypted,
    Uint8List key,
  ) async {
    if (key.length != keySize) {
      throw ArgumentError('Key must be $keySize bytes (AES-256)');
    }

    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);

    // Split ciphertext and MAC (last 16 bytes)
    final ciphertext = encrypted.ciphertext;
    if (ciphertext.length < tagSize) {
      throw ArgumentError(
        'Ciphertext too short: expected at least $tagSize bytes for the auth tag',
      );
    }

    final macBytes = ciphertext.sublist(ciphertext.length - tagSize);
    final actualCiphertext = ciphertext.sublist(0, ciphertext.length - tagSize);

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
  ///
  /// [length] - Number of random bytes to generate.
  static Uint8List randomBytes(int length) {
    if (length <= 0) {
      throw ArgumentError('Length must be positive');
    }
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Generates a random salt for PBKDF2.
  ///
  /// Uses [saltSize] (16 bytes) by default.
  static Uint8List generateSalt() {
    return randomBytes(saltSize);
  }

  /// Constant-time comparison to prevent timing attacks.
  ///
  /// Returns `true` if [a] and [b] are equal.
  static bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
