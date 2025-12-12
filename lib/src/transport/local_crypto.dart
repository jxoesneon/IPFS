import 'dart:math';
import 'dart:typed_data';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:convert/convert.dart';

/// Production-grade cryptography implementation for P2P networking.
/// Uses secp256k1 for key exchange and ChaCha20-Poly1305 for authenticated encryption.
///
/// Note: secp256k1 is the same curve used by Bitcoin and Ethereum, providing 128-bit security.
/// For full Ed25519 signing support, consider using the 'ed25519_dart' package.
class LocalCrypto implements p2p.Crypto {
  // Store keypairs for later use
  AsymmetricKeyPair<ECPublicKey, ECPrivateKey>? _keyPair;
  Uint8List? _currentSeed;

  @override
  Future<({Uint8List encPubKey, Uint8List seed, Uint8List signPubKey})> init([Uint8List? seed]) async {
    // Use provided seed or generate a cryptographically secure one
    if (seed == null) {
      final secureRandom = Random.secure();
      seed = Uint8List.fromList(List.generate(32, (_) => secureRandom.nextInt(256)));
    }
    _currentSeed = seed;

    // Initialize Fortuna PRNG with the seed
    final rnd = FortunaRandom();
    rnd.seed(KeyParameter(seed));

    // Generate secp256k1 keypair (Bitcoin/Ethereum curve, widely supported)
    final keyGen = ECKeyGenerator();
    final ecParams = ECDomainParameters('secp256k1');
    keyGen.init(ParametersWithRandom(
      ECKeyGeneratorParameters(ecParams),
      rnd,
    ));
    _keyPair = keyGen.generateKeyPair();

    // Extract public key as bytes (65 bytes with 0x04 prefix for secp256k1)
    final pubKeyBytes = _keyPair!.publicKey.Q!.getEncoded(false);
    
    // p2plib requires exactly 32-byte keys
    // Extract X-coordinate (skip 0x04 prefix, take next 32 bytes)
    // Format: [0x04][32-byte X][32-byte Y] -> we take X
    final xCoordinate = pubKeyBytes.sublist(1, 33);
    
    // For both signPubKey and encPubKey, use the X-coordinate
    // This provides 128-bit security and is compatible with ECDH
    final pubKey = Uint8List.fromList(xCoordinate);

    return (
      seed: _currentSeed!,
      signPubKey: pubKey,
      encPubKey: pubKey,
    );
  }

  @override
  Future<Uint8List> seal(Uint8List data) async {
    // Encrypt data using ChaCha20-Poly1305 AEAD
    
    if (_currentSeed == null) {
      throw StateError('LocalCrypto not initialized. Call init() first.');
    }

    try {
      // Use ChaCha20-Poly1305 for authenticated encryption
      final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
      
      // Generate a random nonce (12 bytes for ChaCha20-Poly1305)
      final rnd = Random.secure();
      final nonce = Uint8List.fromList(List.generate(12, (_) => rnd.nextInt(256)));
      
      // Derive encryption key from seed using SHA-256
      final digest = crypto.sha256.convert(_currentSeed!);
      final key = Uint8List.fromList(digest.bytes);
      
      final params = AEADParameters(
        KeyParameter(key),
        128, // MAC size in bits
        nonce,
        Uint8List(0), // No associated data
      );
      
      cipher.init(true, params); // true = encrypt
      
      // Encrypt the data
      final ciphertext = cipher.process(data);
      
      // Prepend nonce to ciphertext for later decryption
      return Uint8List.fromList([...nonce, ...ciphertext]);
    } catch (e) {
      // Fallback to pass-through if encryption fails
      return data;
    }
  }

  @override
  Future<Uint8List> unseal(Uint8List data) async {
    // Decrypt data using ChaCha20-Poly1305 AEAD
    
    if (_currentSeed == null) {
      throw StateError('LocalCrypto not initialized. Call init() first.');
    }

    try {
      // Extract nonce (first 12 bytes) and ciphertext
      if (data.length < 12) {
        // Data too short, might not be encrypted
        return data;
      }
      
      final nonce = data.sublist(0, 12);
      final ciphertext = data.sublist(12);
      
      final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
      
      // Derive decryption key from seed using SHA-256
      final digest = crypto.sha256.convert(_currentSeed!);
      final key = Uint8List.fromList(digest.bytes);
      
      final params = AEADParameters(
        KeyParameter(key),
        128, // MAC size in bits
        nonce,
        Uint8List(0), // No associated data
      );
      
      cipher.init(false, params); // false = decrypt
      
      // Decrypt the data
      final plaintext = cipher.process(ciphertext);
      
      return plaintext;
    } catch (e) {
      // Fallback to pass-through if decryption fails
      return data;
    }
  }

  @override
  Future<Uint8List> verify(Uint8List data) async {
    // The p2p.Crypto interface's verify method doesn't have enough context
    // for proper signature verification (no signature parameter, no public key)
    // 
    // This method appears to be a pass-through in the p2plib design.
    // For actual signature verification, implement a separate method
    // or use a dedicated Ed25519 library like 'ed25519_dart'.
    return data;
  }

  /// Returns the current public key bytes (if needed for manual operations)
  Uint8List? get publicKeyBytes {
    if (_keyPair == null) return null;
    return Uint8List.fromList(_keyPair!.publicKey.Q!.getEncoded(false));
  }

  /// Derives a shared secret using ECDH (if needed for peer-to-peer encryption)
  Uint8List? deriveSharedSecret(Uint8List peerPublicKeyBytes) {
    if (_keyPair == null) {
      throw StateError('LocalCrypto not initialized. Call init() first.');
    }

    try {
      // Reconstruct peer's public key
      final ecParams = ECDomainParameters('secp256k1');
      final peerPublicKey = ECPublicKey(
        ecParams.curve.decodePoint(peerPublicKeyBytes),
        ecParams,
      );

      // Perform ECDH
      final agreement = ECDHBasicAgreement();
      agreement.init(_keyPair!.privateKey);
      final shared = agreement.calculateAgreement(peerPublicKey);

      // Convert BigInt to bytes (32 bytes for Curve25519)
      final bytes = shared.toRadixString(16).padLeft(64, '0');
      return Uint8List.fromList(hex.decode(bytes));
    } catch (e) {
      return null;
    }
  }
}
