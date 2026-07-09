import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs_quic/src/libp2p_tls_extension.dart';
import 'package:ipfs_libp2p/core/crypto/ed25519.dart' as libp2p;
import 'package:ipfs_libp2p/core/peer/peer_id.dart' as libp2p;
import 'package:quic_lib/quic_lib.dart' as quic_lib;
// ignore: implementation_imports
import 'package:quic_lib/src/libp2p/libp2p_tls_extension.dart' as quic_ext;
import 'package:test/test.dart';

/// Builds a minimal DER-encoded X.509 certificate embedding an optional
/// libp2p TLS extension value.
///
/// This helper constructs a syntactically valid (but cryptographically
/// meaningless) self-signed certificate so that [parseX509] can extract the
/// extensions map. It is used only by tests that need to exercise edge cases
/// (missing extension, unsupported key type, tampered signature) without
/// depending on additional packages.
Uint8List _buildMinimalCert(
    {Uint8List? libp2pExtensionValue,
    String extensionOid = '1.3.6.1.4.1.53594.1.1'}) {
  final der = _DerBuilder();

  // SubjectPublicKeyInfo: ecPublicKey + prime256v1 with a dummy 65-byte point.
  final spki = der.sequence([
    der.sequence([
      der.oid([1, 2, 840, 10045, 2, 1]),
      der.oid([1, 2, 840, 10045, 3, 1, 7]),
    ]),
    der.bitString(Uint8List(65)),
  ]);

  // Extensions [3] EXPLICIT.
  final extensions = <_DerNode>[];
  if (libp2pExtensionValue != null) {
    extensions.add(der.sequence([
      der.oid(_parseOidString(extensionOid)),
      der.octetString(libp2pExtensionValue),
    ]));
  }
  final extensionsNode = der.explicitTag(0xA3, [der.sequence(extensions)]);

  // TBSCertificate.
  final tbs = der.sequence([
    der.explicitTag(0xA0, [der.integer(BigInt.two)]),
    der.integer(BigInt.one),
    der.sequence([
      der.oid([1, 2, 840, 10045, 4, 3, 2]),
      der.nullNode()
    ]),
    der.sequence([]),
    der.sequence([
      der.utcTime(DateTime(2025, 1, 1)),
      der.utcTime(DateTime(2026, 1, 1)),
    ]),
    der.sequence([]),
    spki,
    extensionsNode,
  ]);

  // Outer certificate: tbs, signatureAlgorithm, signatureValue.
  final cert = der.sequence([
    tbs,
    der.sequence([
      der.oid([1, 2, 840, 10045, 4, 3, 2]),
      der.nullNode()
    ]),
    der.bitString(Uint8List(64)),
  ]);
  return cert.encode();
}

List<int> _parseOidString(String oid) {
  return oid.split('.').map(int.parse).toList();
}

/// Minimal DER tree builder used only by [_buildMinimalCert].
class _DerBuilder {
  _DerNode sequence(List<_DerNode> children) =>
      _ConstructedNode(0x30, children);
  _DerNode explicitTag(int tag, List<_DerNode> children) =>
      _ConstructedNode(tag, children);
  _DerNode integer(BigInt value) => _IntegerNode(value);
  _DerNode oid(List<int> arcs) => _OidNode(arcs);
  _DerNode octetString(Uint8List data) => _LeafNode(0x04, data);
  _DerNode bitString(Uint8List data) => _LeafNode(0x03, _withZeroUnused(data));
  _DerNode nullNode() => _LeafNode(0x05, Uint8List(0));
  _DerNode utcTime(DateTime time) =>
      _LeafNode(0x17, Uint8List.fromList(utf8.encode(_formatUtc(time))));

  static Uint8List _withZeroUnused(Uint8List data) {
    final out = Uint8List(data.length + 1);
    out[0] = 0; // 0 unused bits
    out.setRange(1, out.length, data);
    return out;
  }

  static String _formatUtc(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final year = t.year >= 2000 ? t.year - 2000 : t.year - 1900;
    return '${two(year)}${two(t.month)}${two(t.day)}'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }
}

abstract class _DerNode {
  Uint8List encode();
}

class _LeafNode extends _DerNode {
  final int tag;
  final Uint8List value;
  _LeafNode(this.tag, this.value);

  @override
  Uint8List encode() {
    final lenBytes = _encodeLength(value.length);
    final out = Uint8List(1 + lenBytes.length + value.length);
    out[0] = tag;
    out.setRange(1, 1 + lenBytes.length, lenBytes);
    out.setRange(1 + lenBytes.length, out.length, value);
    return out;
  }
}

class _ConstructedNode extends _DerNode {
  final int tag;
  final List<_DerNode> children;
  _ConstructedNode(this.tag, this.children);

  @override
  Uint8List encode() {
    final body = <int>[];
    for (final c in children) {
      body.addAll(c.encode());
    }
    final lenBytes = _encodeLength(body.length);
    final out = Uint8List(1 + lenBytes.length + body.length);
    out[0] = tag;
    out.setRange(1, 1 + lenBytes.length, lenBytes);
    out.setRange(1 + lenBytes.length, out.length, body);
    return out;
  }
}

class _IntegerNode extends _DerNode {
  final BigInt value;
  _IntegerNode(this.value);

  @override
  Uint8List encode() {
    final bytes = <int>[];
    var v = value;
    if (v == BigInt.zero) {
      bytes.add(0);
    } else {
      while (v > BigInt.zero) {
        bytes.insert(0, (v & BigInt.from(0xFF)).toInt());
        v = v >> 8;
      }
      if (bytes.first & 0x80 != 0) {
        bytes.insert(0, 0);
      }
    }
    final lenBytes = _encodeLength(bytes.length);
    final out = Uint8List(1 + lenBytes.length + bytes.length);
    out[0] = 0x02;
    out.setRange(1, 1 + lenBytes.length, lenBytes);
    out.setRange(1 + lenBytes.length, out.length, bytes);
    return out;
  }
}

class _OidNode extends _DerNode {
  final List<int> arcs;
  _OidNode(this.arcs);

  @override
  Uint8List encode() {
    final bytes = <int>[];
    if (arcs.isNotEmpty) {
      bytes.add(arcs[0] * 40 + (arcs.length > 1 ? arcs[1] : 0));
    }
    for (var i = 2; i < arcs.length; i++) {
      bytes.addAll(_encodeArc(arcs[i]));
    }
    final lenBytes = _encodeLength(bytes.length);
    final out = Uint8List(1 + lenBytes.length + bytes.length);
    out[0] = 0x06;
    out.setRange(1, 1 + lenBytes.length, lenBytes);
    out.setRange(1 + lenBytes.length, out.length, bytes);
    return out;
  }
}

List<int> _encodeArc(int value) {
  if (value == 0) return [0];
  final bytes = <int>[];
  var v = value;
  while (v > 0) {
    bytes.insert(0, (v & 0x7F) | 0x80);
    v >>= 7;
  }
  bytes[bytes.length - 1] &= 0x7F;
  return bytes;
}

Uint8List _encodeLength(int length) {
  if (length < 128) return Uint8List.fromList([length]);
  final bytes = <int>[];
  var v = length;
  while (v > 0) {
    bytes.insert(0, v & 0xFF);
    v >>= 8;
  }
  return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
}

Future<({quic_lib.SecretKey privateKey, List<int> publicKeyBytes})>
    _generateEd25519KeyPair() async {
  final backend = quic_lib.DefaultCryptoBackend();
  final keyPair = await backend.ed25519GenerateKeyPair();
  final privateKey = await keyPair.secretKey;
  final publicKey = await keyPair.publicKey;
  return (privateKey: privateKey, publicKeyBytes: publicKey.bytes);
}

Future<Uint8List> _generateLibp2pCert(
  quic_lib.SecretKey privateKey,
  List<int> publicKeyBytes,
) async {
  final generator = quic_lib.Libp2pCertificateGenerator(
    quic_lib.DefaultCryptoBackend(),
  );
  final chain = await generator.generate(
    hostIdentityPrivateKey: privateKey,
    hostPublicKeyBytes: publicKeyBytes,
  );
  return Uint8List.fromList(chain.certs.first.rawBytes);
}

void main() {
  group('Libp2pTlsHandshakeVerifier', () {
    late Libp2pTlsHandshakeVerifier verifier;

    setUp(() {
      verifier = const Libp2pTlsHandshakeVerifier();
    });

    test('verifies a valid libp2p certificate and derives the peer ID',
        () async {
      final kp = await _generateEd25519KeyPair();
      final certBytes =
          await _generateLibp2pCert(kp.privateKey, kp.publicKeyBytes);

      final result = await verifier.verify(certBytes);

      expect(result.valid, isTrue);
      expect(result.peerId, isNotNull);
      expect(result.publicKey, isNotNull);
      expect(result.failureReason, isNull);
    });

    test(
        'derived peer ID matches libp2p PeerId.fromPublicKey (identity multihash)',
        () async {
      final kp = await _generateEd25519KeyPair();
      final certBytes =
          await _generateLibp2pCert(kp.privateKey, kp.publicKeyBytes);

      final expectedPeerId = libp2p.PeerId.fromPublicKey(
        libp2p.Ed25519PublicKey.fromRawBytes(
          Uint8List.fromList(kp.publicKeyBytes),
        ),
      );

      final result = await verifier.verify(
        certBytes,
        expectedPeerId: expectedPeerId,
      );

      expect(result.valid, isTrue);
      expect(result.peerId, equals(expectedPeerId));
    });

    test('fails with peerIdMismatch when expected peer ID differs', () async {
      final kp = await _generateEd25519KeyPair();
      final certBytes =
          await _generateLibp2pCert(kp.privateKey, kp.publicKeyBytes);

      // Build a different peer ID.
      final otherKp = await _generateEd25519KeyPair();
      final wrongPeerId = libp2p.PeerId.fromPublicKey(
        libp2p.Ed25519PublicKey.fromRawBytes(
          Uint8List.fromList(otherKp.publicKeyBytes),
        ),
      );

      final result = await verifier.verify(
        certBytes,
        expectedPeerId: wrongPeerId,
      );

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.peerIdMismatch);
      expect(result.expectedPeerId, equals(wrongPeerId));
    });

    test('fails with noExtension when certificate lacks the libp2p extension',
        () async {
      final certBytes = _buildMinimalCert(libp2pExtensionValue: null);

      final result = await verifier.verify(certBytes);

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.noExtension);
    });

    test('fails with noExtension for an unrelated extension OID', () async {
      // Build a cert with an extension under a different OID.
      final dummyExt = Uint8List.fromList([0x01, 0x02, 0x03]);
      final certBytes = _buildMinimalCert(
        libp2pExtensionValue: dummyExt,
        extensionOid: '1.2.3.4.5.6.7.8.9',
      );

      final result = await verifier.verify(certBytes);

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.noExtension);
    });

    test('fails with invalidSignature when the extension signature is tampered',
        () async {
      final kp = await _generateEd25519KeyPair();
      final certBytes =
          await _generateLibp2pCert(kp.privateKey, kp.publicKeyBytes);

      // Corrupt the embedded public key so signature verification fails.
      final tampered = _corruptEmbeddedPublicKey(certBytes, kp.publicKeyBytes);
      expect(tampered, isNotNull, reason: 'public key bytes should be found');

      final result = await verifier.verify(tampered!);

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.invalidSignature);
    });

    test('fails with parseError for empty bytes', () async {
      final result = await verifier.verify(<int>[]);

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.parseError);
    });

    test('fails with parseError for non-DER garbage', () async {
      final result = await verifier.verify(
        Uint8List.fromList([0xFF, 0xEE, 0xDD, 0xCC]),
      );

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.parseError);
    });

    test('fails with unsupportedKeyType for a non-Ed25519 extension', () async {
      // Build a SignedKey with an RSA key type (value 0) and embed it.
      final rsaPublicKey = quic_ext.Libp2pPublicKey(
        type: quic_ext.Libp2pKeyType.rsa,
        data: Uint8List.fromList(List<int>.filled(32, 0x41)),
      );
      final signedKey = quic_ext.SignedKey(
        publicKey: rsaPublicKey,
        signature: Uint8List(64),
      );
      final extBytes =
          quic_ext.Libp2pExtension(signedKey: signedKey).serialize();
      final certBytes = _buildMinimalCert(
        libp2pExtensionValue: Uint8List.fromList(extBytes),
      );

      final result = await verifier.verify(certBytes);

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.unsupportedKeyType);
    });

    test('fails with invalidSignature when Ed25519 public key is not 32 bytes',
        () async {
      final badPublicKey = quic_ext.Libp2pPublicKey(
        type: quic_ext.Libp2pKeyType.ed25519,
        data: Uint8List.fromList(List<int>.filled(31, 0x42)),
      );
      final signedKey = quic_ext.SignedKey(
        publicKey: badPublicKey,
        signature: Uint8List(64),
      );
      final extBytes =
          quic_ext.Libp2pExtension(signedKey: signedKey).serialize();
      final certBytes = _buildMinimalCert(
        libp2pExtensionValue: Uint8List.fromList(extBytes),
      );

      final result = await verifier.verify(certBytes);

      expect(result.valid, isFalse);
      expect(result.failureReason, Libp2pTlsFailureReason.invalidSignature);
    });

    test('result toString is informative for both outcomes', () async {
      final okResult = const Libp2pTlsVerificationResult.ok(null, null);
      expect(okResult.toString(), contains('valid: true'));

      final failResult = const Libp2pTlsVerificationResult.failed(
        Libp2pTlsFailureReason.parseError,
        'bad',
      );
      expect(failResult.toString(), contains('valid: false'));
      expect(failResult.toString(), contains('parseError'));
    });
  });

  group('PeerIdMismatchException', () {
    test('carries expected and actual peer IDs', () {
      final expected = libp2p.PeerId.fromMultihash(
        Uint8List.fromList([0x12, 0x20, ...List<int>.filled(32, 1)]),
      );
      final actual = libp2p.PeerId.fromMultihash(
        Uint8List.fromList([0x12, 0x20, ...List<int>.filled(32, 2)]),
      );
      final exc = PeerIdMismatchException(expected, actual, 'detail');
      expect(exc.expectedPeerId, equals(expected));
      expect(exc.actualPeerId, equals(actual));
      expect(exc.detail, 'detail');
      expect(exc.toString(), contains('PeerIdMismatchException'));
    });
  });

  group('PeerCertificateVerificationException', () {
    test('carries reason and detail', () {
      final exc = PeerCertificateVerificationException(
        Libp2pTlsFailureReason.noExtension,
        'missing',
      );
      expect(exc.reason, Libp2pTlsFailureReason.noExtension);
      expect(exc.detail, 'missing');
      expect(exc.toString(), contains('noExtension'));
      expect(exc.toString(), contains('missing'));
    });
  });
}

/// Finds the first occurrence of [publicKeyBytes] inside [certBytes] and
/// flips the first byte, returning a new list. Returns `null` when the public
/// key bytes are not found.
Uint8List? _corruptEmbeddedPublicKey(
    Uint8List certBytes, List<int> publicKeyBytes) {
  final needle = Uint8List.fromList(publicKeyBytes);
  for (var i = 0; i + needle.length <= certBytes.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (certBytes[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      final out = Uint8List.fromList(certBytes);
      out[i] = (out[i] ^ 0x01) & 0xFF;
      return out;
    }
  }
  return null;
}
