// src/utils/private_key.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:convert/convert.dart';

class IPFSPrivateKey implements PrivateKey {
  final AsymmetricKeyPair<ECPublicKey, ECPrivateKey> _keyPair;
  final String algorithm;

  IPFSPrivateKey(this._keyPair, this.algorithm);

  ECPublicKey get publicKey => _keyPair.publicKey;
  ECPrivateKey get privateKey => _keyPair.privateKey;

  /// Signs the given data using the private key
  Uint8List sign(Uint8List data) {
    final signer = Signer('${algorithm}/PSS');
    final params = ParametersWithRandom(
      PrivateKeyParameter(_keyPair.privateKey),
      SecureRandom('Fortuna'),
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
    final verifier = Signer('${algorithm ?? this.algorithm}/PSS');
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
    random.seed(KeyParameter(
      Uint8List.fromList(List<int>.generate(32, (_) => random.nextUint8())),
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
