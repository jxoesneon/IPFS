// src/utils/private_key.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:convert/convert.dart';

/// ECDSA private key for IPFS cryptographic operations.
///
/// Wraps an elliptic curve key pair for signing and verification.
/// Uses secp256k1 curve compatible with Bitcoin/Ethereum.
class IPFSPrivateKey implements PrivateKey {
  final AsymmetricKeyPair<ECPublicKey, ECPrivateKey> _keyPair;

  /// The signing algorithm (e.g., 'ECDSA').
  final String algorithm;

  /// Creates a key from an existing [_keyPair].
  IPFSPrivateKey(this._keyPair, this.algorithm);

  /// The public key component.
  ECPublicKey get publicKey => _keyPair.publicKey;

  /// The private key component.
  ECPrivateKey get privateKey => _keyPair.privateKey;

  /// Returns the compressed public key bytes (SEC1)
  Uint8List get publicKeyBytes {
    if (algorithm == 'ECDSA') {
      // Compressed EC point: 0x02/0x03 + X (32 bytes)
      return _keyPair.publicKey.Q!.getEncoded(true); // true = compressed
    }
    // Fallback or other algos
    return Uint8List(0);
  }

  /// Signs the given data using the private key
  Uint8List sign(Uint8List data) {
    // ECDSA with SHA-256
    final signer = Signer('SHA-256/ECDSA');

    // Create and seed a secure random source
    final random = SecureRandom('Fortuna');
    final seedSource = Random.secure();
    random.seed(KeyParameter(
      Uint8List.fromList(
          List<int>.generate(32, (_) => seedSource.nextInt(256))),
    ));

    final params = ParametersWithRandom(
      PrivateKeyParameter(_keyPair.privateKey),
      random,
    );

    signer.init(true, params);
    final signature = signer.generateSignature(data) as ECSignature;
    // Convert ECSignature to bytes
    final r = signature.r.toRadixString(16).padLeft(64, '0');
    final s = signature.s.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(List<int>.from(hex.decode(r + s)));
  }

  /// Verifies a signature using the corresponding public key
  bool verify(Uint8List data, Uint8List signature, {String? algorithm}) {
    final verifier = Signer('SHA-256/ECDSA');
    final params = PublicKeyParameter(_keyPair.publicKey);

    verifier.init(false, params);

    // Convert signature bytes back to ECSignature
    final r = BigInt.parse(hex.encode(signature.sublist(0, 32)), radix: 16);
    final s = BigInt.parse(hex.encode(signature.sublist(32)), radix: 16);
    final sig = ECSignature(r, s);

    return verifier.verifySignature(data, sig);
  }

  /// Creates a new key pair
  static Future<IPFSPrivateKey> generate([String algorithm = 'ECDSA']) async {
    final keyGen = KeyGenerator('EC');
    final params = ECKeyGeneratorParameters(ECCurve_secp256k1());

    final random = SecureRandom('Fortuna');
    final seedSource = Random.secure();
    random.seed(KeyParameter(
      Uint8List.fromList(
          List<int>.generate(32, (_) => seedSource.nextInt(256))),
    ));

    keyGen.init(ParametersWithRandom(params, random));
    final pair = keyGen.generateKeyPair();

    // Cast the key pair to the correct types
    final ecKeyPair = AsymmetricKeyPair<ECPublicKey, ECPrivateKey>(
      pair.publicKey as ECPublicKey,
      pair.privateKey as ECPrivateKey,
    );

    return IPFSPrivateKey(ecKeyPair, algorithm);
  }

  /// Creates an IPFSPrivateKey from a base64-encoded string
  static IPFSPrivateKey fromString(String privateKeyStr) {
    // Decode the private key string
    final keyBytes = base64Url.decode(privateKeyStr);
    final d = BigInt.parse(hex.encode(keyBytes), radix: 16);

    // Generate the corresponding public key point
    final curve = ECCurve_secp256k1();
    final point = curve.G * d;

    // Create the key pair
    final publicKey = ECPublicKey(point, curve);
    final privateKey = ECPrivateKey(d, curve);

    return IPFSPrivateKey(
        AsymmetricKeyPair<ECPublicKey, ECPrivateKey>(publicKey, privateKey),
        'ECDSA');
  }
}
