// lib/src/protocols/ipns/ipns_record.dart
//
// SEC-004: IPNS V2 record with Ed25519 signatures.
// Follows IPNS spec: https://specs.ipfs.tech/ipns/ipns-record/

import 'dart:convert';
import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';

/// IPNS V2 Record with Ed25519 signature.
///
/// An IPNS record links a name (derived from public key) to a content path.
/// Records are signed to prevent tampering and include sequence numbers
/// to handle updates.
///
/// **Security Features (SEC-004):**
/// - Ed25519 signatures over CBOR-encoded data
/// - Sequence number for replay attack prevention
/// - Expiration time (validity) for temporal bounds
///
/// Example:
/// ```dart
/// final record = await IPNSRecord.create(
///   value: cid,
///   keyPair: keyPair,
///   sequence: 1,
/// );
/// final isValid = await record.verify();
/// ```
class IPNSRecord {
  /// The value this IPNS name points to (typically /ipfs/CID).
  final Uint8List value;

  /// When this record expires (RFC3339 format internally).
  final DateTime validity;

  /// Monotonically increasing sequence number.
  /// Higher sequence = newer record.
  final int sequence;

  /// Time-to-live suggestion for caches.
  final Duration ttl;

  /// The Ed25519 public key of the record owner.
  final Uint8List publicKey;

  /// Ed25519 signature over the signable data.
  Uint8List? _signature;

  /// Gets the signature bytes, if signed.
  Uint8List? get signature => _signature;

  /// Whether this record has been signed.
  bool get isSigned => _signature != null;

  IPNSRecord._({
    required this.value,
    required this.validity,
    required this.sequence,
    required this.ttl,
    required this.publicKey,
    Uint8List? signature,
  }) : _signature = signature;

  /// Creates and signs a new IPNS record.
  ///
  /// [value] - The CID this name points to
  /// [keyPair] - Ed25519 key pair for signing
  /// [sequence] - Sequence number (must be higher than previous)
  /// [validity] - How long until this record expires (default 24h)
  /// [ttl] - Cache TTL suggestion (default 1h)
  static Future<IPNSRecord> create({
    required CID value,
    required SimpleKeyPair keyPair,
    required int sequence,
    Duration validity = const Duration(hours: 24),
    Duration ttl = const Duration(hours: 1),
  }) async {
    final signer = Ed25519Signer();
    final publicKey = await signer.extractPublicKeyBytes(keyPair);

    // Value is /ipfs/<CID>
    final valueBytes = Uint8List.fromList(
      utf8.encode('/ipfs/${value.encode()}'),
    );

    final record = IPNSRecord._(
      value: valueBytes,
      validity: DateTime.now().add(validity),
      sequence: sequence,
      ttl: ttl,
      publicKey: publicKey,
    );

    // Sign the record
    await record.sign(keyPair);

    return record;
  }

  /// Signs the record with the given Ed25519 key pair.
  Future<void> sign(SimpleKeyPair keyPair) async {
    final signer = Ed25519Signer();
    final signableData = _getSignableData();
    _signature = await signer.sign(signableData, keyPair);
  }

  /// Verifies the record signature.
  ///
  /// Returns `true` if:
  /// - Record has a signature
  /// - Signature is valid for the public key
  /// - Record has not expired
  Future<bool> verify() async {
    if (_signature == null) {
      return false;
    }

    // Check expiration
    if (DateTime.now().isAfter(validity)) {
      return false;
    }

    // Verify signature
    final signer = Ed25519Signer();
    final signableData = _getSignableData();
    final pubKey = signer.publicKeyFromBytes(publicKey);

    return await signer.verify(signableData, _signature!, pubKey);
  }

  /// Encodes the record to CBOR format for DHT storage.
  Uint8List toCBOR() {
    final cborValue = CborMap({
      CborString('Value'): CborBytes(value),
      CborString('Validity'): CborBytes(
        Uint8List.fromList(utf8.encode(validity.toUtc().toIso8601String())),
      ),
      CborString('ValidityType'): CborSmallInt(0), // EOL (End of Life)
      CborString('Sequence'): CborSmallInt(sequence),
      CborString('TTL'): CborSmallInt(ttl.inMicroseconds),
      CborString('PublicKey'): CborBytes(publicKey),
      if (_signature != null) CborString('Signature'): CborBytes(_signature!),
    });

    return Uint8List.fromList(cbor.encode(cborValue));
  }

  /// Decodes an IPNS record from CBOR format.
  static IPNSRecord fromCBOR(Uint8List data) {
    final decoded = cbor.decode(data);
    if (decoded is! CborMap) {
      throw FormatException('Invalid IPNS record: expected CBOR map');
    }

    final map = decoded;

    Uint8List getBytes(String key) {
      final value = map[CborString(key)];
      if (value is CborBytes) {
        return Uint8List.fromList(value.bytes);
      }
      throw FormatException('Missing or invalid field: $key');
    }

    int getInt(String key, {int defaultValue = 0}) {
      final value = map[CborString(key)];
      if (value is CborSmallInt) {
        return value.value;
      }
      if (value is CborInt) {
        return value.toInt();
      }
      return defaultValue;
    }

    final valueBytes = getBytes('Value');
    final validityBytes = getBytes('Validity');
    final publicKeyBytes = getBytes('PublicKey');

    Uint8List? signatureBytes;
    try {
      signatureBytes = getBytes('Signature');
    } catch (_) {
      // Signature is optional
    }

    return IPNSRecord._(
      value: valueBytes,
      validity: DateTime.parse(utf8.decode(validityBytes)),
      sequence: getInt('Sequence'),
      ttl: Duration(microseconds: getInt('TTL')),
      publicKey: publicKeyBytes,
      signature: signatureBytes,
    );
  }

  /// Returns the data that gets signed.
  /// Format: "ipns-signature:" + CBOR(data without signature)
  Uint8List _getSignableData() {
    // Create CBOR without signature
    final cborValue = CborMap({
      CborString('Value'): CborBytes(value),
      CborString('Validity'): CborBytes(
        Uint8List.fromList(utf8.encode(validity.toUtc().toIso8601String())),
      ),
      CborString('ValidityType'): CborSmallInt(0),
      CborString('Sequence'): CborSmallInt(sequence),
      CborString('TTL'): CborSmallInt(ttl.inMicroseconds),
    });

    final cborBytes = cbor.encode(cborValue);
    final prefix = utf8.encode('ipns-signature:');

    return Uint8List.fromList([...prefix, ...cborBytes]);
  }

  /// Parses the value as a CID.
  CID? get valueCID {
    try {
      final valueStr = utf8.decode(value);
      if (valueStr.startsWith('/ipfs/')) {
        return CID.decode(valueStr.substring(6));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Human-readable representation.
  @override
  String toString() {
    return 'IPNSRecord(value: ${utf8.decode(value)}, '
        'seq: $sequence, '
        'valid: ${validity.toIso8601String()}, '
        'signed: $isSigned)';
  }
}
