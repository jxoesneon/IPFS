// lib/src/protocols/ipns/ipns_record.dart
//
// SEC-004: IPNS V2 record with Ed25519 signatures.
// Follows IPNS spec: https://specs.ipfs.tech/ipns/ipns-record/

import 'dart:convert';
import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/cbor/enhanced_cbor_handler.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/ipld/data_model.pb.dart';
import 'package:dart_ipfs/src/proto/generated/ipns.pb.dart';
import 'package:fixnum/fixnum.dart';

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
  IPNSRecord._({
    required this.value,
    required this.validity,
    required this.sequence,
    required this.ttl,
    required this.publicKey,
    Uint8List? signature,
    Uint8List? signatureV2,
    Uint8List? dataBytes,
  })  : _signature = signature,
        _signatureV2 = signatureV2,
        _dataBytes = dataBytes;

  /// Creates a record for internal use (e.g. caching or testing).
  factory IPNSRecord.internal({
    required Uint8List value,
    required DateTime validity,
    int sequence = 0,
    Duration ttl = const Duration(hours: 1),
    Uint8List? publicKey,
    Uint8List? signature,
    Uint8List? signatureV2,
  }) {
    return IPNSRecord._(
      value: value,
      validity: validity,
      sequence: sequence,
      ttl: ttl,
      publicKey: publicKey ?? Uint8List(0),
      signature: signature,
      signatureV2: signatureV2,
    );
  }

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

  /// Ed25519 signature over the V1 signable data.
  Uint8List? _signature;

  /// Ed25519 signature over the DAG-CBOR V2 data.
  Uint8List? _signatureV2;

  /// The canonical DAG-CBOR data bytes used for the V2 signature.
  Uint8List? _dataBytes;

  /// Gets the V1 signature bytes, if signed.
  Uint8List? get signature => _signature;

  /// Gets the V2 signature bytes, if signed.
  Uint8List? get signatureV2 => _signatureV2;

  /// Whether this record has been signed.
  bool get isSigned => _signature != null || _signatureV2 != null;

  /// Whether this record has expired.
  bool get isExpired => DateTime.now().isAfter(validity);

  /// The IPNS name derived from this record's public key.
  String get name => deriveIpnsName(publicKey);

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

  /// Signs the record with the given Ed25519 key pair (V1 + V2).
  Future<void> sign(SimpleKeyPair keyPair) async {
    final signer = Ed25519Signer();

    // V1 signature: value + "EOL" + validity bytes.
    final signableData = _getSignableData();
    _signature = await signer.sign(signableData, keyPair);

    // V2 signature: signature over "ipns-signature:" + canonical DAG-CBOR
    // data bytes (per Kubo/boxo IPNS implementation).
    final v2DataBytes = _buildV2DataBytes();
    final v2Signable = Uint8List.fromList([
      ...utf8.encode('ipns-signature:'),
      ...v2DataBytes,
    ]);
    _signatureV2 = await signer.sign(v2Signable, keyPair);
  }

  /// Builds the canonical DAG-CBOR data map and returns its bytes.
  Uint8List _buildV2DataBytes() {
    final dataNode = IPLDNode()
      ..kind = Kind.MAP
      ..mapValue = (IPLDMap()
        ..entries.addAll([
          MapEntry()
            ..key = 'Value'
            ..value = (IPLDNode()
              ..kind = Kind.BYTES
              ..bytesValue = value),
          MapEntry()
            ..key = 'ValidityType'
            ..value = (IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = Int64(0)),
          MapEntry()
            ..key = 'Validity'
            ..value = (IPLDNode()
              ..kind = Kind.BYTES
              ..bytesValue = Uint8List.fromList(utf8.encode(_validityString))),
          MapEntry()
            ..key = 'Sequence'
            ..value = (IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = Int64(sequence)),
          MapEntry()
            ..key = 'TTL'
            ..value = (IPLDNode()
              ..kind = Kind.INTEGER
              ..intValue = Int64(ttl.inMicroseconds * 1000)),
        ]));
    _dataBytes = EnhancedCBORHandler.encodeDagCbor(dataNode);
    return _dataBytes!;
  }

  /// Verifies the record signature.
  ///
  /// Returns `true` if:
  /// - Record has a V2 or V1 signature
  /// - Signature is valid for the public key
  /// - Record has not expired
  Future<bool> verify() async {
    // Check expiration
    if (DateTime.now().isAfter(validity)) {
      return false;
    }

    final signer = Ed25519Signer();
    final pubKey = signer.publicKeyFromBytes(publicKey);

    // Prefer V2 signature. Use the original serialized data bytes when
    // available (e.g. from a decoded record) because key ordering/encoding must
    // match exactly. Accept both raw data bytes and the "ipns-signature:"
    // prefix used by different IPNS implementations.
    if (_signatureV2 != null) {
      final v2DataBytes = _dataBytes ?? _buildV2DataBytes();
      final v2SignableRaw = v2DataBytes;
      if (await signer.verify(v2SignableRaw, _signatureV2!, pubKey)) {
        return true;
      }
      final v2SignablePrefixed = Uint8List.fromList([
        ...utf8.encode('ipns-signature:'),
        ...v2DataBytes,
      ]);
      if (await signer.verify(v2SignablePrefixed, _signatureV2!, pubKey)) {
        return true;
      }
    }

    if (_signature == null) {
      return false;
    }

    final signableData = _getSignableData();
    return await signer.verify(signableData, _signature!, pubKey);
  }

  /// Encodes the record to CBOR format for DHT storage.
  Uint8List toCBOR() {
    final cborValue = CborMap({
      CborString('Value'): CborBytes(value),
      CborString('Validity'): CborBytes(
        Uint8List.fromList(utf8.encode(validity.toUtc().toIso8601String())),
      ),
      CborString('ValidityType'): const CborSmallInt(0), // EOL (End of Life)
      CborString('Sequence'): CborSmallInt(sequence),
      CborString('TTL'): CborSmallInt(ttl.inMicroseconds),
      CborString('PublicKey'): CborBytes(publicKey),
      if (_signature != null) CborString('Signature'): CborBytes(_signature!),
      if (_signatureV2 != null) CborString('SignatureV2'): CborBytes(_signatureV2!),
    });

    return Uint8List.fromList(cbor.encode(cborValue));
  }

  /// Decodes an IPNS record from CBOR format.
  static IPNSRecord fromCBOR(Uint8List data) {
    final decoded = cbor.decode(data);
    if (decoded is! CborMap) {
      throw const FormatException('Invalid IPNS record: expected CBOR map');
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

    Uint8List? signatureV2Bytes;
    try {
      signatureV2Bytes = getBytes('SignatureV2');
    } catch (_) {
      // V2 signature is optional
    }

    return IPNSRecord._(
      value: valueBytes,
      validity: DateTime.parse(utf8.decode(validityBytes)),
      sequence: getInt('Sequence'),
      ttl: Duration(microseconds: getInt('TTL')),
      publicKey: publicKeyBytes,
      signature: signatureBytes,
      signatureV2: signatureV2Bytes,
    );
  }

  /// Encodes the record to the Kubo `IpnsEntry` protobuf format used on the
  /// DHT wire.
  Uint8List toIpnsEntry() {
    if (_signatureV2 == null) {
      throw StateError('Cannot serialize unsigned IPNS record');
    }
    final v2DataBytes = _buildV2DataBytes();
    final entry = IpnsEntry()
      ..value = value
      ..signature = _signature ?? Uint8List(0)
      ..validityType = IpnsEntry_ValidityType.EOL
      ..validity = Uint8List.fromList(utf8.encode(_validityString))
      ..sequence = Int64(sequence)
      ..ttl = Int64(ttl.inMicroseconds * 1000)
      ..data = v2DataBytes
      ..signatureV2 = _signatureV2!;
    return entry.writeToBuffer();
  }

  /// Decodes an IPNS record from the Kubo `IpnsEntry` protobuf format.
  ///
  /// If the embedded `pubKey` is empty and [name] is provided, the public key
  /// is recovered from the CIDv1 libp2p-key name.
  static IPNSRecord fromIpnsEntry(Uint8List data, {String? name}) {
    final entry = IpnsEntry.fromBuffer(data);
    Uint8List publicKey;
    if (entry.pubKey.isNotEmpty) {
      publicKey = _extractPublicKeyFromProto(Uint8List.fromList(entry.pubKey));
    } else if (name != null) {
      publicKey = _publicKeyFromName(name);
    } else {
      publicKey = Uint8List(0);
    }
    return IPNSRecord._(
      value: Uint8List.fromList(entry.value),
      validity: DateTime.parse(utf8.decode(entry.validity)),
      sequence: entry.sequence.toInt(),
      ttl: Duration(
        microseconds: (entry.ttl ~/ Int64(1000)).toInt(),
      ),
      publicKey: publicKey,
      signature: entry.signature.isNotEmpty
          ? Uint8List.fromList(entry.signature)
          : null,
      signatureV2: entry.signatureV2.isNotEmpty
          ? Uint8List.fromList(entry.signatureV2)
          : null,
      dataBytes: entry.data.isNotEmpty
          ? Uint8List.fromList(entry.data)
          : null,
    );
  }

  /// Recovers the raw Ed25519 public key bytes from a base36 CIDv1 libp2p-key
  /// IPNS name.
  static Uint8List _publicKeyFromName(String name) {
    final cidBytes = PeerId.fromBase36(name).value;
    // cidBytes = [0x01, 0x72, identityHash...]
    final identityHash = cidBytes.sublist(2);
    // identityHash = [0x00, len, protoKey...]
    final protoKey = identityHash.sublist(2);
    return _extractPublicKeyFromProto(protoKey);
  }

  /// Decodes a record, trying the Kubo protobuf format first and falling back
  /// to the internal CBOR format.
  ///
  /// Pass [name] when decoding Kubo protobuf that omits the public key.
  static IPNSRecord decode(Uint8List data, {String? name}) {
    try {
      return fromIpnsEntry(data, name: name);
    } catch (_) {
      return fromCBOR(data);
    }
  }

  /// Returns the data that gets signed.
  ///
  /// Matches Kubo/go-libp2p: the signature covers the value, the literal
  /// validity type string "EOL", and the validity (RFC3339) bytes.
  Uint8List _getSignableData() {
    return Uint8List.fromList([
      ...value,
      ...utf8.encode('EOL'),
      ...utf8.encode(_validityString),
    ]);
  }

  /// RFC3339 timestamp with nanosecond precision, matching Kubo's validity
  /// string format (the extra precision is zero-padded from microseconds).
  String get _validityString {
    final utc = validity.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    final us = utc.microsecond.toString().padLeft(6, '0');
    return '$y-$mo-${d}T$h:$mi:$s.$us' '000Z';
  }

  /// Extracts the raw Ed25519 public key from a libp2p PublicKey protobuf.
  static Uint8List _extractPublicKeyFromProto(Uint8List protoKey) {
    if (protoKey.length < 4 ||
        protoKey[0] != 0x08 ||
        protoKey[1] != 0x01 ||
        protoKey[2] != 0x12) {
      throw const FormatException('Unsupported public key protobuf');
    }
    final len = protoKey[3];
    if (protoKey.length != 4 + len) {
      throw const FormatException('Invalid public key protobuf length');
    }
    return Uint8List.fromList(protoKey.sublist(4));
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

/// Derives an IPNS name from an Ed25519 public key.
///
/// The name is the multibase base36-encoded CIDv1 `libp2p-key` of the key.
/// Kubo/IPNS expect this format: `k51qzi5uqu5...`.
String deriveIpnsName(Uint8List publicKey) {
  // libp2p PublicKey protobuf: field 1 (type) = Ed25519 (1), field 2 (data).
  final protoKey = Uint8List(4 + publicKey.length)
    ..[0] = 0x08 // field 1, wire type 0 (varint)
    ..[1] = 0x01 // Ed25519 key type
    ..[2] = 0x12 // field 2, wire type 2 (length-delimited)
    ..[3] = publicKey.length;
  protoKey.setRange(4, 4 + publicKey.length, publicKey);

  // Identity multihash: 0x00 (hash id), 0x24 (length = 36), <protoKey>
  final identityHash = Uint8List(2 + protoKey.length)
    ..[0] = 0x00
    ..[1] = protoKey.length;
  identityHash.setRange(2, 2 + protoKey.length, protoKey);

  // CIDv1 libp2p-key: 0x01 (version), 0x72 (codec), identity multihash.
  final cidBytes = Uint8List.fromList([0x01, 0x72, ...identityHash]);

  // Use PeerId's base36 encoder (it just encodes arbitrary bytes).
  return PeerId(value: cidBytes).toBase36();
}
