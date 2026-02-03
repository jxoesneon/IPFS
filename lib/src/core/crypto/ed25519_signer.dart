// lib/src/core/crypto/ed25519_signer.dart
//
// SEC-004: Unified Ed25519 signing service for IPNS and other signatures.
// Uses the 'cryptography' package for Ed25519 operations.

import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_utils.dart';

/// Unified Ed25519 signing service.
///
/// Provides Ed25519 key generation, signing, and verification.
/// Used for IPNS record signatures and peer identity.
///
/// **Security Features:**
/// - Ed25519 (128-bit security level)
/// - Deterministic signatures (no random nonce)
/// - Memory zeroing for private keys
///
/// Example:
/// ```dart
/// final signer = Ed25519Signer();
/// final keyPair = await signer.generateKeyPair();
/// final signature = await signer.sign(data, keyPair);
/// final isValid = await signer.verify(data, signature, keyPair.publicKey);
/// ```
class Ed25519Signer {
  final Ed25519 _algorithm = Ed25519();

  /// Generates a new Ed25519 key pair.
  ///
  /// Optionally accepts a 32-byte [seed] for deterministic key generation.
  /// If no seed is provided, a cryptographically secure random seed is used.
  Future<SimpleKeyPair> generateKeyPair({Uint8List? seed}) async {
    if (seed != null) {
      if (seed.length != 32) {
        throw ArgumentError('Seed must be 32 bytes');
      }
      return await _algorithm.newKeyPairFromSeed(seed);
    }
    return await _algorithm.newKeyPair();
  }

  /// Creates a key pair from a 32-byte seed.
  ///
  /// Useful for deterministic key recovery from encrypted storage.
  Future<SimpleKeyPair> keyPairFromSeed(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be 32 bytes');
    }
    return await _algorithm.newKeyPairFromSeed(seed);
  }

  /// Signs data using an Ed25519 private key.
  ///
  /// Returns a 64-byte Ed25519 signature.
  Future<Uint8List> sign(Uint8List data, SimpleKeyPair keyPair) async {
    final signature = await _algorithm.sign(data, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies an Ed25519 signature.
  ///
  /// Returns `true` if the signature is valid for the given data and public key.
  Future<bool> verify(
    Uint8List data,
    Uint8List signatureBytes,
    SimplePublicKey publicKey,
  ) async {
    try {
      final signature = Signature(signatureBytes, publicKey: publicKey);
      return await _algorithm.verify(data, signature: signature);
    } catch (e) {
      // Invalid signature format or verification failure
      return false;
    }
  }

  /// Extracts the public key from a key pair.
  Future<SimplePublicKey> extractPublicKey(SimpleKeyPair keyPair) async {
    return await keyPair.extractPublicKey();
  }

  /// Extracts the public key bytes from a key pair.
  Future<Uint8List> extractPublicKeyBytes(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Extracts the private key seed (32 bytes) from a key pair.
  ///
  /// **Security Note:** The caller is responsible for zeroing the returned
  /// bytes after use. Use [CryptoUtils.zeroMemory].
  Future<Uint8List> extractSeed(SimpleKeyPair keyPair) async {
    final privateKey = await keyPair.extractPrivateKeyBytes();
    // Ed25519 private key is 32-byte seed
    return Uint8List.fromList(privateKey.sublist(0, 32));
  }

  /// Creates a public key from raw bytes.
  SimplePublicKey publicKeyFromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError('Public key must be 32 bytes');
    }
    return SimplePublicKey(bytes, type: KeyPairType.ed25519);
  }
}

/// Extension to help with key pair management and cleanup.
extension KeyPairExtensions on SimpleKeyPair {
  /// Extracts seed and immediately zeros old copy if provided.
  ///
  /// Returns the 32-byte seed for key recovery.
  Future<Uint8List> extractSeedAndZero() async {
    final privateKeyBytes = await extractPrivateKeyBytes();
    final seed = Uint8List.fromList(privateKeyBytes.sublist(0, 32));
    // Zero the full private key bytes
    CryptoUtils.zeroMemory(Uint8List.fromList(privateKeyBytes));
    return seed;
  }
}

