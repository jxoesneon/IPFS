import 'dart:typed_data';

/// Result of cryptographic key pair generation.
class CryptoKeyPair {
  /// Creates a new key pair result.
  CryptoKeyPair({
    required this.seed,
    required this.encryptionPublicKey,
    required this.signingPublicKey,
  });

  /// The seed used to generate the keys.
  final Uint8List seed;

  /// Public key for encryption (X25519).
  final Uint8List encryptionPublicKey;

  /// Public key for signing (Ed25519).
  final Uint8List signingPublicKey;
}

/// Abstract interface for cryptographic operations.
///
/// This abstraction allows different implementations for IO (using p2plib)
/// and web (using pure-Dart cryptography package) platforms.
abstract class CryptoProvider {
  /// Initializes the crypto provider and generates key pairs.
  ///
  /// If [seed] is provided, uses it to deterministically generate keys.
  /// Otherwise, generates a random seed.
  Future<CryptoKeyPair> init([Uint8List? seed]);

  /// Seals (encrypts and signs) a datagram.
  ///
  /// The datagram should contain routing information (header) followed
  /// by the payload to encrypt.
  Future<Uint8List> seal(Uint8List datagram);

  /// Unseals (decrypts and verifies) a datagram.
  ///
  /// Returns the decrypted payload if signature is valid.
  /// Throws if signature verification fails.
  Future<Uint8List> unseal(Uint8List datagram);

  /// Verifies the signature of a datagram without decrypting.
  ///
  /// Returns empty bytes if valid, throws if invalid.
  Future<Uint8List> verify(Uint8List datagram);

  /// Disposes of any resources (key material, isolates, etc.).
  void dispose();
}
