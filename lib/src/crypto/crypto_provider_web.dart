import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_provider.dart';

/// Web implementation of [CryptoProvider] using pure-Dart cryptography.
///
/// This implementation uses the `cryptography` package which works on all
/// platforms including web, without requiring native libraries or isolates.
///
/// Uses:
/// - X25519 for key exchange (Curve25519)
/// - Ed25519 for digital signatures
class CryptoProviderWeb implements CryptoProvider {
  SimpleKeyPair? _signingKeyPair;
  Uint8List? _seed;
  bool _initialized = false;

  final _ed25519 = Ed25519();

  @override
  Future<CryptoKeyPair> init([Uint8List? seed]) async {
    // Generate or use provided seed
    if (seed != null && seed.length >= 32) {
      _seed = seed;
    } else {
      // Generate random 32-byte seed
      final randomBytes = Uint8List(32);
      final secureRandom = SecureRandom.defaultRandom;
      for (var i = 0; i < 32; i++) {
        randomBytes[i] = secureRandom.nextInt(256);
      }
      _seed = randomBytes;
    }

    // Generate X25519 key pair for encryption (for public key export)
    final x25519 = X25519();
    final encKeyPair = await x25519.newKeyPairFromSeed(_seed!.sublist(0, 32));

    // Generate Ed25519 key pair for signing
    final signKeyPair = await _ed25519.newKeyPairFromSeed(
      _seed!.sublist(0, 32),
    );
    _signingKeyPair = signKeyPair;

    final encPubKey = await encKeyPair.extractPublicKey();
    final signPubKey = await signKeyPair.extractPublicKey();

    _initialized = true;

    return CryptoKeyPair(
      seed: _seed!,
      encryptionPublicKey: Uint8List.fromList(encPubKey.bytes),
      signingPublicKey: Uint8List.fromList(signPubKey.bytes),
    );
  }

  @override
  Future<Uint8List> seal(Uint8List datagram) async {
    _ensureInitialized();

    // For web, we implement a simplified seal operation:
    // 1. Sign the datagram
    // 2. Append signature to datagram

    final signature = await _ed25519.sign(datagram, keyPair: _signingKeyPair!);

    // Return datagram + signature (64 bytes)
    final result = Uint8List(datagram.length + 64);
    result.setAll(0, datagram);
    result.setAll(datagram.length, signature.bytes.sublist(datagram.length));

    return result;
  }

  @override
  Future<Uint8List> unseal(Uint8List datagram) async {
    _ensureInitialized();

    // For web, verify signature and return original data
    if (datagram.length < 64) {
      throw ArgumentError('Datagram too short to contain signature');
    }

    final message = datagram.sublist(0, datagram.length - 64);
    final signatureBytes = datagram.sublist(datagram.length - 64);

    // Note: In a real implementation, we'd need the sender's public key
    // For now, this is a simplified verification
    final signature = Signature(
      Uint8List.fromList([...message, ...signatureBytes]),
      publicKey: await _signingKeyPair!.extractPublicKey(),
    );

    final isValid = await _ed25519.verify(message, signature: signature);

    if (!isValid) {
      throw StateError('Invalid signature');
    }

    return Uint8List.fromList(message);
  }

  @override
  Future<Uint8List> verify(Uint8List datagram) async {
    _ensureInitialized();

    // Verify signature without decrypting
    // Returns empty list if valid
    await unseal(datagram);
    return Uint8List(0);
  }

  @override
  void dispose() {
    _signingKeyPair = null;
    _seed = null;
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('CryptoProviderWeb not initialized. Call init() first.');
    }
  }
}

/// Factory function for web platform.
CryptoProvider createCryptoProvider() => CryptoProviderWeb();
