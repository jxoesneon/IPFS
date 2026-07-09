// lib/src/core/peer/peer_record.dart
//
// Signed peer records per libp2p RFC 0002 (Signed Envelopes) and the
// PeerRecord spec. A signed peer record binds a peer's listen addresses
// to its peer ID via an Ed25519 signature, allowing other peers to verify
// that the addresses were published by the peer itself.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../utils/logger.dart';
import 'peer_record_pb.dart';

/// The domain separation string used when signing/verifying peer records.
///
/// Per RFC 0002, this string is NOT included in the envelope structure but
/// is prepended to the signing buffer. It prevents cross-protocol signature
/// replay.
const String peerRecordDomain = 'libp2p-routing-record';

/// The payload type for PeerRecord. This is the multicodec for
/// `libp2p-peer-record` (0x0301 / `/libp2p-peer-record`).
///
/// In go-libp2p this is encoded as the uvarint-prefixed multicodec. We use
/// the raw 2-byte varint encoding of 0x0301.
final Uint8List peerRecordPayloadType = Uint8List.fromList([0x03, 0x01]);

/// A signed peer record: a [PeerRecordPb] wrapped in a signed [EnvelopePb].
///
/// Use [PeerRecordSigner.create] to build and sign a record, and
/// [PeerRecordVerifier.verify] to validate one received from a remote peer.
class SignedPeerRecord {
  /// Creates a signed peer record from its components.
  SignedPeerRecord({required this.record, required this.envelope});

  /// The inner peer record (addresses, peer ID, timestamp, seq).
  final PeerRecordPb record;

  /// The signed envelope containing the record.
  final EnvelopePb envelope;

  /// The serialized envelope bytes (suitable for the `signedPeerRecord`
  /// field of the Identify message).
  Uint8List get envelopeBytes => envelope.encode();

  @override
  String toString() =>
      'SignedPeerRecord(peerId: ${record.peerId.length} bytes, '
      'addresses: ${record.addresses.length}, seq: ${record.seq})';
}

/// Signs peer records using an Ed25519 key pair.
class PeerRecordSigner {
  /// Creates a signer from a `package:cryptography` Ed25519 key pair.
  ///
  /// [peerIdBytes] is the marshalled peer ID bytes (the bytes that go into
  /// the PeerRecord's `PeerID` field). [publicKeyBytes] is the 32-byte
  /// Ed25519 public key.
  PeerRecordSigner({
    required SimpleKeyPair keyPair,
    required Uint8List peerIdBytes,
    required Uint8List publicKeyBytes,
    Logger? logger,
  }) : _keyPair = keyPair,
       _ed25519 = Ed25519(),
       _peerIdBytes = peerIdBytes,
       _publicKeyBytes = publicKeyBytes,
       _logger = logger ?? Logger('PeerRecordSigner');

  final SimpleKeyPair _keyPair;
  final Ed25519 _ed25519;
  final Uint8List _peerIdBytes;
  final Uint8List _publicKeyBytes;
  final Logger _logger;

  int _seq = 0;

  /// The current sequence number.
  int get seq => _seq;

  /// Creates and signs a peer record for the given [addresses].
  ///
  /// [addresses] are multiaddr bytes (the string-encoded multiaddr converted
  /// to UTF-8 bytes, matching go-libp2p's representation).
  ///
  /// The sequence number is auto-incremented on each call. The timestamp is
  /// the current time in microseconds since epoch.
  Future<SignedPeerRecord> create(List<Uint8List> addresses) async {
    _seq++;
    final now = DateTime.now().microsecondsSinceEpoch;

    final record = PeerRecordPb(
      peerId: Uint8List.fromList(_peerIdBytes),
      addresses: List<Uint8List>.from(addresses),
      timestamp: now,
      seq: _seq,
    );

    final payload = record.encode();

    final signingBuffer = _buildSigningBuffer(
      domain: peerRecordDomain,
      payloadType: peerRecordPayloadType,
      payload: payload,
    );

    final signature = await _ed25519.sign(signingBuffer, keyPair: _keyPair);
    final sigBytes = Uint8List.fromList(signature.bytes);

    final publicKeyPb = PublicKeyPb(
      type: KeyType.ed25519,
      data: Uint8List.fromList(_publicKeyBytes),
    );

    final envelope = EnvelopePb(
      publicKey: publicKeyPb,
      payloadType: Uint8List.fromList(peerRecordPayloadType),
      payload: payload,
      signature: sigBytes,
    );

    _logger.debug(
      'Created signed peer record: seq=$_seq, addresses=${addresses.length}',
    );

    return SignedPeerRecord(record: record, envelope: envelope);
  }

  /// Builds the signing buffer per RFC 0002.
  ///
  /// The buffer is the concatenation of:
  /// - length of domain string (uvarint)
  /// - domain string (UTF-8)
  /// - length of payload_type (uvarint)
  /// - payload_type
  /// - length of payload (uvarint)
  /// - payload
  static Uint8List _buildSigningBuffer({
    required String domain,
    required Uint8List payloadType,
    required Uint8List payload,
  }) {
    final domainBytes = Uint8List.fromList(domain.codeUnits);
    final result = <int>[];

    result.addAll(encodeVarint(domainBytes.length));
    result.addAll(domainBytes);

    result.addAll(encodeVarint(payloadType.length));
    result.addAll(payloadType);

    result.addAll(encodeVarint(payload.length));
    result.addAll(payload);

    return Uint8List.fromList(result);
  }

  /// Exposes the signing buffer builder for verification and testing.
  static Uint8List buildSigningBuffer({
    required String domain,
    required Uint8List payloadType,
    required Uint8List payload,
  }) => _buildSigningBuffer(
    domain: domain,
    payloadType: payloadType,
    payload: payload,
  );
}

/// Verifies signed peer records received from remote peers.
class PeerRecordVerifier {
  /// Creates a verifier.
  PeerRecordVerifier({Logger? logger})
    : _logger = logger ?? Logger('PeerRecordVerifier'),
      _ed25519 = Ed25519();

  final Ed25519 _ed25519;
  final Logger _logger;

  /// Verifies a signed peer record from its serialized envelope bytes.
  ///
  /// Returns the decoded [SignedPeerRecord] if valid, or `null` if:
  /// - The signature is invalid
  /// - The public key type is not Ed25519
  /// - The payload type does not match [peerRecordPayloadType]
  /// - The envelope is malformed
  Future<SignedPeerRecord?> verify(Uint8List envelopeBytes) async {
    try {
      final envelope = EnvelopePb.decode(envelopeBytes);
      return await verifyEnvelope(envelope);
    } catch (e, st) {
      _logger.warning('Failed to decode/verify envelope: $e', e, st);
      return null;
    }
  }

  /// Verifies a signed peer record from a decoded [EnvelopePb].
  Future<SignedPeerRecord?> verifyEnvelope(EnvelopePb envelope) async {
    // Check key type
    if (envelope.publicKey.type != KeyType.ed25519) {
      _logger.warning(
        'Unsupported key type in envelope: ${envelope.publicKey.type}',
      );
      return null;
    }

    // Check payload type
    if (!_bytesEqual(envelope.payloadType, peerRecordPayloadType)) {
      _logger.warning('Unexpected payload type in envelope');
      return null;
    }

    // Reconstruct the signing buffer
    final signingBuffer = PeerRecordSigner.buildSigningBuffer(
      domain: peerRecordDomain,
      payloadType: envelope.payloadType,
      payload: envelope.payload,
    );

    // Verify signature
    final publicKey = SimplePublicKey(
      envelope.publicKey.data,
      type: KeyPairType.ed25519,
    );
    final sig = Signature(envelope.signature, publicKey: publicKey);

    bool valid;
    try {
      valid = await _ed25519.verify(signingBuffer, signature: sig);
    } catch (e) {
      _logger.warning('Signature verification threw: $e');
      valid = false;
    }

    if (!valid) {
      _logger.warning('Invalid signature in peer record envelope');
      return null;
    }

    // Decode the payload as a PeerRecord
    final record = PeerRecordPb.decode(envelope.payload);

    _logger.debug(
      'Verified peer record: seq=${record.seq}, '
      'addresses=${record.addresses.length}',
    );

    return SignedPeerRecord(record: record, envelope: envelope);
  }

  /// Verifies that the peer ID in the record matches the public key.
  ///
  /// In a full implementation this would derive the peer ID from the public
  /// key and compare. Here we accept the expected peer ID bytes and compare
  /// against the record's PeerID field.
  bool verifyPeerId(SignedPeerRecord spr, Uint8List expectedPeerIdBytes) {
    return _bytesEqual(spr.record.peerId, expectedPeerIdBytes);
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
