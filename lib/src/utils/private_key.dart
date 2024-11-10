import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PrivateKey {
  final String _privateKeyStr;
  final String publicKey;

  PrivateKey(this._privateKeyStr, this.publicKey);

  /// Signs the provided data using the private key
  Uint8List sign(Uint8List data) {
    // Create an HMAC using SHA-256 and the private key
    final hmac = Hmac(sha256, utf8.encode(_privateKeyStr));
    final digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Creates a new key pair
  static PrivateKey generate() {
    // Generate a random private key (in a real implementation, use a proper crypto library)
    final privateKeyBytes =
        List<int>.generate(32, (i) => i); // Placeholder implementation
    final privateKeyStr = base64.encode(privateKeyBytes);

    // Derive public key from private key (simplified for example)
    final publicKeyBytes = sha256.convert(privateKeyBytes).bytes;
    final publicKey = base64.encode(publicKeyBytes);

    return PrivateKey(privateKeyStr, publicKey);
  }
}
