import 'dart:async';
import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/protocols/dht/Interface_dht_handler.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

/// Represents an IPNS record with all required fields according to the IPNS spec
class IPNSRecord {
  final Uint8List value; // The target CID or path
  final Uint8List signature; // Record signature
  final int sequence; // Monotonically increasing sequence number
  final int validity; // Record validity in milliseconds
  final DateTime expiry; // Record expiry timestamp
  final String publicKey; // Public key that signed this record

  IPNSRecord({
    required this.value,
    required this.signature,
    required this.sequence,
    required this.validity,
    required this.expiry,
    required this.publicKey,
  });

  /// Serializes the record for network transmission
  Uint8List serialize() {
    // Combine all fields in a standardized format
    final buffer = BytesBuilder();
    buffer.add(value);
    buffer.add(signature);
    buffer.add(Uint8List.fromList([sequence]));
    buffer.add(Uint8List.fromList(validity.toString().codeUnits));
    buffer.add(
        Uint8List.fromList(expiry.millisecondsSinceEpoch.toString().codeUnits));
    buffer.add(Uint8List.fromList(publicKey.codeUnits));
    return buffer.toBytes();
  }

  /// Creates an IPNSRecord from serialized data
  factory IPNSRecord.fromBytes(Uint8List bytes) {
    // Implement deserialization logic
    // This is a simplified version - real implementation would need proper field separation
    return IPNSRecord(
      value: bytes.sublist(0, 32),
      signature: bytes.sublist(32, 96),
      sequence: bytes[96],
      validity: 24 * 60 * 60 * 1000, // 24 hours in milliseconds
      expiry: DateTime.now().add(Duration(hours: 24)),
      publicKey: Base58().encode(bytes.sublist(97)),
    );
  }
}

/// Handles IPNS (InterPlanetary Name System) operations
class IPNSHandler {
  final DHTHandler _dhtHandler;
  final Keystore _keystore;
  static const int DEFAULT_RECORD_LIFETIME = 24 * 60 * 60 * 1000; // 24 hours

  IPNSHandler(this._dhtHandler, this._keystore);

  /// Creates a new IPNS record pointing to the given CID
  Future<IPNSRecord> createRecord(CID target, PrivateKey key) async {
    final sequence = await _getLatestSequence(key.publicKey) + 1;
    final validity = DEFAULT_RECORD_LIFETIME;
    final expiry = DateTime.now().add(Duration(milliseconds: validity));

    // Create the record value (target CID)
    final value = Uint8List.fromList(target.encode().codeUnits);

    // Create the record data to be signed
    final dataToSign = _createSigningData(value, sequence, validity, expiry);

    // Sign the record
    final signature = key.sign(dataToSign);

    return IPNSRecord(
      value: value,
      signature: signature,
      sequence: sequence,
      validity: validity,
      expiry: expiry,
      publicKey: key.publicKey,
    );
  }

  /// Publishes an IPNS record to the network
  Future<void> publishRecord(IPNSRecord record) async {
    if (!await validateRecord(record)) {
      throw Exception('Invalid IPNS record');
    }

    // Convert record to DHT key-value pair
    final key = Key.fromString('/ipns/${record.publicKey}');
    final value = Value(record.serialize());

    // Publish to DHT
    await _dhtHandler.putValue(key, value);
  }

  /// Resolves an IPNS name to its current value
  Future<IPNSRecord> resolveRecord(String name) async {
    // Create DHT key from IPNS name
    final key = Key.fromString('/ipns/$name');

    try {
      // Get record from DHT
      final value = await _dhtHandler.getValue(key);
      final record = IPNSRecord.fromBytes(value.bytes);

      // Validate the retrieved record
      if (!await validateRecord(record)) {
        throw Exception('Retrieved invalid IPNS record');
      }

      return record;
    } catch (e) {
      throw Exception('Failed to resolve IPNS record: $e');
    }
  }

  /// Validates an IPNS record according to the spec
  Future<bool> validateRecord(IPNSRecord record) async {
    // Check if record has expired
    if (DateTime.now().isAfter(record.expiry)) {
      return false;
    }

    // Verify the record signature
    final dataToVerify = _createSigningData(
      record.value,
      record.sequence,
      record.validity,
      record.expiry,
    );

    try {
      return await _keystore.verifySignature(
        record.publicKey,
        dataToVerify,
        record.signature,
      );
    } catch (e) {
      return false;
    }
  }

  /// Creates the data to be signed/verified for a record
  Uint8List _createSigningData(
    Uint8List value,
    int sequence,
    int validity,
    DateTime expiry,
  ) {
    final buffer = BytesBuilder();
    buffer.add(value);
    buffer.add(Uint8List.fromList([sequence]));
    buffer.add(Uint8List.fromList(validity.toString().codeUnits));
    buffer.add(
        Uint8List.fromList(expiry.millisecondsSinceEpoch.toString().codeUnits));
    return buffer.toBytes();
  }

  /// Gets the latest sequence number for a public key
  Future<int> _getLatestSequence(String publicKey) async {
    try {
      final key = Key.fromString('/ipns/$publicKey');
      final value = await _dhtHandler.getValue(key);
      final record = IPNSRecord.fromBytes(value.bytes);
      return record.sequence;
    } catch (e) {
      return 0; // Return 0 if no previous record exists
    }
  }
}
