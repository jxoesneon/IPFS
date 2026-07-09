import 'dart:convert';
import 'dart:typed_data';

import 'package:ipfs_libp2p/core/crypto/ed25519.dart' as libp2p;
import 'package:ipfs_libp2p/core/crypto/keys.dart' as libp2p;
import 'package:ipfs_libp2p/core/peer/peer_id.dart' as libp2p;
// The X.509 parser and libp2p TLS extension types are not exported from
// quic_lib's public barrel files, so we import the source files directly.
// This is intentional: the public API does not expose parseX509 or
// Libp2pPublicKey, which are required for spec-compliant peer ID derivation.
// ignore: implementation_imports
import 'package:quic_lib/src/crypto/tls/x509_parser.dart' as quic_tls;
// ignore: implementation_imports
import 'package:quic_lib/src/libp2p/libp2p_tls_extension.dart' as quic_ext;

/// The prefix used in the libp2p TLS handshake signed message.
///
/// Per the libp2p TLS specification, the host identity key signs the
/// concatenation of the UTF-8 string `libp2p-tls-handshake:` and the
/// DER-encoded SubjectPublicKeyInfo of the ephemeral certificate key.
const String libp2pTlsHandshakePrefix = 'libp2p-tls-handshake:';

/// The reason a libp2p TLS certificate verification failed.
enum Libp2pTlsFailureReason {
  /// The certificate did not contain the libp2p TLS extension.
  noExtension,

  /// The embedded key type is not supported by this verifier.
  unsupportedKeyType,

  /// The signature in the libp2p TLS extension did not verify.
  invalidSignature,

  /// The derived peer ID did not match the expected peer ID.
  peerIdMismatch,

  /// The certificate bytes could not be parsed as a valid X.509 DER document.
  parseError,
}

/// The outcome of verifying a peer's libp2p TLS 1.3 certificate.
class Libp2pTlsVerificationResult {
  /// Whether the certificate is valid and the peer identity was established.
  final bool valid;

  /// The libp2p [PeerId] derived from the certificate's embedded public key.
  ///
  /// Only set when [valid] is `true`.
  final libp2p.PeerId? peerId;

  /// The peer's public key extracted from the libp2p TLS extension.
  ///
  /// Only set when [valid] is `true`.
  final libp2p.PublicKey? publicKey;

  /// The reason verification failed, when [valid] is `false`.
  final Libp2pTlsFailureReason? failureReason;

  /// The expected peer ID when verification failed due to a mismatch.
  final libp2p.PeerId? expectedPeerId;

  /// A human-readable description of the failure, when [valid] is `false`.
  final String? failureDetail;

  /// Creates a successful verification result.
  const Libp2pTlsVerificationResult.ok(
    this.peerId,
    this.publicKey,
  )   : valid = true,
        failureReason = null,
        expectedPeerId = null,
        failureDetail = null;

  /// Creates a failed verification result.
  const Libp2pTlsVerificationResult.failed(
    this.failureReason,
    this.failureDetail, {
    this.expectedPeerId,
  })  : valid = false,
        peerId = null,
        publicKey = null;

  @override
  String toString() {
    if (valid) {
      return 'Libp2pTlsVerificationResult(valid: true, peerId: $peerId)';
    }
    return 'Libp2pTlsVerificationResult(valid: false, reason: '
        '$failureReason, detail: $failureDetail)';
  }
}

/// Verifies a peer's libp2p TLS 1.3 certificate extension.
///
/// The libp2p TLS specification (https://github.com/libp2p/specs/blob/master/tls/tls.md)
/// requires each peer to present a self-signed X.509 certificate containing a
/// custom extension (OID `1.3.6.1.4.1.53594.1.1`). The extension embeds a
/// protobuf `SignedKey` carrying:
///
/// * the peer's long-term public key, and
/// * a signature over `libp2p-tls-handshake:` || SubjectPublicKeyInfo DER
///   produced by the peer's long-term identity private key.
///
/// The verifier:
/// 1. Parses the DER-encoded X.509 certificate.
/// 2. Extracts the libp2p TLS extension.
/// 3. Reconstructs the signed message and verifies the signature using the
///    public key embedded in the extension.
/// 4. Derives the libp2p [PeerId] from the embedded public key using the
///    *correct* libp2p derivation (protobuf-marshaled public key wrapped in an
///    identity multihash for small keys such as Ed25519, or a sha2-256
///    multihash for larger keys). This matches the peer IDs used by Kubo and
///    Helia.
/// 5. When an [expectedPeerId] is supplied, confirms the derived peer ID
///    matches it.
class Libp2pTlsHandshakeVerifier {
  /// Creates a verifier.
  const Libp2pTlsHandshakeVerifier();

  /// Verifies [certBytes] (raw DER-encoded X.509) and derives the peer
  /// identity.
  ///
  /// When [expectedPeerId] is provided, the derived peer ID must match it;
  /// otherwise a result with [Libp2pTlsFailureReason.peerIdMismatch] is
  /// returned.
  Future<Libp2pTlsVerificationResult> verify(
    List<int> certBytes, {
    libp2p.PeerId? expectedPeerId,
  }) async {
    final quic_tls.X509Certificate x509;
    try {
      x509 = quic_tls.parseX509(certBytes);
    } catch (e) {
      return Libp2pTlsVerificationResult.failed(
        Libp2pTlsFailureReason.parseError,
        'Failed to parse X.509 certificate: $e',
      );
    }

    final quic_ext.Libp2pExtension? ext;
    try {
      ext = quic_tls.parseLibp2pExtension(x509);
    } catch (e) {
      return Libp2pTlsVerificationResult.failed(
        Libp2pTlsFailureReason.parseError,
        'Failed to parse libp2p TLS extension: $e',
      );
    }
    if (ext == null) {
      return Libp2pTlsVerificationResult.failed(
        Libp2pTlsFailureReason.noExtension,
        'Certificate does not contain the libp2p TLS extension '
        '(OID ${quic_ext.Libp2pExtension.oid}).',
      );
    }

    final signedKey = ext.signedKey;
    final publicKeyData = Uint8List.fromList(signedKey.publicKey.data);
    final keyType = signedKey.publicKey.type;

    // Build the libp2p public key object from the raw key bytes.
    final libp2p.PublicKey libp2pPublicKey;
    switch (keyType) {
      case quic_ext.Libp2pKeyType.ed25519:
        if (publicKeyData.length != 32) {
          return Libp2pTlsVerificationResult.failed(
            Libp2pTlsFailureReason.invalidSignature,
            'Ed25519 public key must be 32 bytes, got ${publicKeyData.length}.',
          );
        }
        libp2pPublicKey = libp2p.Ed25519PublicKey.fromRawBytes(publicKeyData);
      case quic_ext.Libp2pKeyType.rsa:
      case quic_ext.Libp2pKeyType.secp256k1:
      case quic_ext.Libp2pKeyType.ecdsa:
        // RSA, secp256k1, and ECDSA identity keys are not yet supported by
        // this verifier because the dart_ipfs_quic transport currently only
        // generates and consumes Ed25519 identity keys (matching the
        // quic_lib Libp2pCertificateGenerator). Supporting additional key
        // types requires the corresponding ipfs_libp2p PublicKey
        // implementation and is tracked as a follow-up.
        return Libp2pTlsVerificationResult.failed(
          Libp2pTlsFailureReason.unsupportedKeyType,
          'Unsupported libp2p key type: $keyType. Only Ed25519 is supported.',
        );
    }

    // Reconstruct the signed message: "libp2p-tls-handshake:" || SPKI DER.
    final spkiDer = Uint8List.fromList(x509.subjectPublicKeyInfo);
    final handshakeMessage = Uint8List.fromList([
      ...utf8.encode(libp2pTlsHandshakePrefix),
      ...spkiDer,
    ]);

    final signature = Uint8List.fromList(signedKey.signature);
    final bool signatureValid;
    try {
      signatureValid =
          await libp2pPublicKey.verify(handshakeMessage, signature);
    } catch (e) {
      return Libp2pTlsVerificationResult.failed(
        Libp2pTlsFailureReason.invalidSignature,
        'Signature verification threw: $e',
      );
    }
    if (!signatureValid) {
      return Libp2pTlsVerificationResult.failed(
        Libp2pTlsFailureReason.invalidSignature,
        'The libp2p TLS extension signature is not valid for the embedded '
        'public key.',
      );
    }

    // Derive the PeerId using the libp2p-spec-compliant derivation. This uses
    // the protobuf-marshaled public key and an identity multihash for Ed25519
    // keys (<= 42 bytes marshaled), matching Kubo/Helia peer IDs.
    final derivedPeerId = libp2p.PeerId.fromPublicKey(libp2pPublicKey);

    if (expectedPeerId != null && derivedPeerId != expectedPeerId) {
      return Libp2pTlsVerificationResult.failed(
        Libp2pTlsFailureReason.peerIdMismatch,
        'Derived peer ID ($derivedPeerId) does not match the expected peer '
        'ID ($expectedPeerId).',
        expectedPeerId: expectedPeerId,
      );
    }

    return Libp2pTlsVerificationResult.ok(derivedPeerId, libp2pPublicKey);
  }
}

/// Exception raised when a peer's certificate-derived identity does not match
/// the expected peer ID.
class PeerIdMismatchException implements Exception {
  /// The expected peer ID (e.g. from the dialed multiaddr).
  final libp2p.PeerId expectedPeerId;

  /// The peer ID derived from the peer's certificate.
  final libp2p.PeerId? actualPeerId;

  /// A human-readable description of the mismatch.
  final String detail;

  /// Creates a [PeerIdMismatchException].
  PeerIdMismatchException(
    this.expectedPeerId,
    this.actualPeerId,
    this.detail,
  );

  @override
  String toString() =>
      'PeerIdMismatchException: expected $expectedPeerId, got $actualPeerId. '
      '$detail';
}

/// Exception raised when the peer's TLS certificate cannot be verified.
class PeerCertificateVerificationException implements Exception {
  /// The reason verification failed.
  final Libp2pTlsFailureReason reason;

  /// A human-readable description of the failure.
  final String detail;

  /// Creates a [PeerCertificateVerificationException].
  PeerCertificateVerificationException(this.reason, this.detail);

  @override
  String toString() => 'PeerCertificateVerificationException($reason): $detail';
}
