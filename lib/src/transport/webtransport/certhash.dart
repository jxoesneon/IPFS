import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Helper for managing and validating certificate hashes.
class CertHash {
  /// The hex-encoded SHA-256 hash of the certificate.
  final String hash;

  /// The multihash representation of the certificate hash.
  final String multihash;

  /// Creates a new [CertHash].
  CertHash(this.hash, this.multihash);

  /// Generates a [CertHash] from a DER-encoded certificate.
  static Future<CertHash> fromCertificate(Uint8List der) async {
    final sha256Hash = sha256.convert(der);
    final hashBytes = Uint8List.fromList(sha256Hash.bytes);

    // Multihash: sha2-256 (0x12) + length (0x20) + digest
    final mhBytes = Uint8List(2 + hashBytes.length);
    mhBytes[0] = 0x12;
    mhBytes[1] = 0x20;
    mhBytes.setRange(2, 2 + hashBytes.length, hashBytes);

    final mhStr = String.fromCharCodes(mhBytes);

    return CertHash(sha256Hash.toString(), mhStr);
  }

  /// Validates a certificate hash from a MultiAddr.
  static bool validate(Uint8List der, String expectedMultihash) {
    final sha256Hash = sha256.convert(der);
    final hashBytes = Uint8List.fromList(sha256Hash.bytes);

    final mhBytes = Uint8List(2 + hashBytes.length);
    mhBytes[0] = 0x12;
    mhBytes[1] = 0x20;
    mhBytes.setRange(2, 2 + hashBytes.length, hashBytes);

    final mhStr = String.fromCharCodes(mhBytes);

    return mhStr == expectedMultihash;
  }
}
