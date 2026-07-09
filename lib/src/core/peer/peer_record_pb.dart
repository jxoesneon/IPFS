// lib/src/core/peer/peer_record_pb.dart
//
// Manual protobuf codec for libp2p signed peer records.
//
// Implements the wire format for:
// - PeerRecord (libp2p core/peer/pb/peer_record.proto)
// - Envelope (libp2p core/record/pb/envelope.proto)
// - PublicKey (libp2p core/crypto/pb/crypto.proto)
//
// These messages are encoded/decoded by hand rather than via protoc-generated
// code so that the identify protocol can populate the `signedPeerRecord` field
// without a build-time protobuf toolchain dependency.

import 'dart:convert';
import 'dart:typed_data';

/// Wire type constants for protobuf encoding.
const int _wireTypeVarint = 0;
const int _wireTypeLengthDelimited = 2;

/// KeyType values from libp2p crypto protobuf.
enum KeyType {
  /// RSA key type.
  rsa(0),

  /// Ed25519 key type.
  ed25519(1),

  /// Secp256k1 key type.
  secp256k1(2),

  /// ECDSA key type.
  ecdsa(3);

  const KeyType(this.value);

  /// The protobuf integer value for this key type.
  final int value;

  /// Converts an integer value back to a [KeyType].
  static KeyType fromValue(int v) {
    for (final kt in KeyType.values) {
      if (kt.value == v) return kt;
    }
    throw ArgumentError('Unknown KeyType value: $v');
  }
}

/// Encodes an unsigned varint into a list of bytes.
List<int> encodeVarint(int value) {
  final result = <int>[];
  var v = value;
  while (v >= 0x80) {
    result.add((v & 0x7F) | 0x80);
    v >>= 7;
  }
  result.add(v);
  return result;
}

/// Decodes a varint starting at [offset] in [data].
/// Returns a record of (value, bytesConsumed).
(int, int) decodeVarint(Uint8List data, int offset) {
  var result = 0;
  var shift = 0;
  var pos = offset;
  while (pos < data.length) {
    final byte = data[pos];
    result |= (byte & 0x7F) << shift;
    pos++;
    if ((byte & 0x80) == 0) {
      return (result, pos - offset);
    }
    shift += 7;
    if (shift > 63) {
      throw FormatException('Varint too long at offset $offset');
    }
  }
  throw FormatException('Truncated varint at offset $offset');
}

/// Encodes a field tag (field number + wire type).
int _makeTag(int fieldNumber, int wireType) => (fieldNumber << 3) | wireType;

/// Encodes a length-delimited field (bytes or string).
List<int> _encodeLengthDelimited(int fieldNumber, List<int> payload) {
  final tag = encodeVarint(_makeTag(fieldNumber, _wireTypeLengthDelimited));
  final length = encodeVarint(payload.length);
  return [...tag, ...length, ...payload];
}

/// Encodes a varint field.
List<int> _encodeVarintField(int fieldNumber, int value) {
  final tag = encodeVarint(_makeTag(fieldNumber, _wireTypeVarint));
  return [...tag, ...encodeVarint(value)];
}

/// A field read from a protobuf message.
class _PbField {
  _PbField(this.fieldNumber, this.wireType, this.value);

  final int fieldNumber;
  final int wireType;

  /// For varint: the integer value. For length-delimited: Uint8List.
  final dynamic value;
}

/// Parses all fields from a protobuf message byte buffer.
List<_PbField> _parseFields(Uint8List data) {
  final fields = <_PbField>[];
  var offset = 0;
  while (offset < data.length) {
    final (tag, tagLen) = decodeVarint(data, offset);
    offset += tagLen;
    final wireType = tag & 0x07;
    final fieldNumber = tag >> 3;

    if (wireType == _wireTypeVarint) {
      final (value, valLen) = decodeVarint(data, offset);
      offset += valLen;
      fields.add(_PbField(fieldNumber, wireType, value));
    } else if (wireType == _wireTypeLengthDelimited) {
      final (length, lenSize) = decodeVarint(data, offset);
      offset += lenSize;
      final payload = data.sublist(offset, offset + length);
      offset += length;
      fields.add(_PbField(fieldNumber, wireType, Uint8List.fromList(payload)));
    } else {
      throw FormatException(
        'Unsupported wire type $wireType for field $fieldNumber',
      );
    }
  }
  return fields;
}

/// ---------------------------------------------------------------------------
/// PublicKey message (libp2p core/crypto/pb/crypto.proto)
/// ---------------------------------------------------------------------------

/// A libp2p public key in protobuf form.
///
/// ```protobuf
/// message PublicKey {
///   KeyType Type = 1;
///   bytes Data = 2;
/// }
/// ```
class PublicKeyPb {
  /// Creates a public key protobuf message.
  PublicKeyPb({required this.type, required this.data});

  /// The key type.
  final KeyType type;

  /// The raw key bytes.
  final Uint8List data;

  /// Encodes this public key to protobuf bytes.
  Uint8List encode() {
    final typeField = _encodeVarintField(1, type.value);
    final dataField = _encodeLengthDelimited(2, data);
    return Uint8List.fromList([...typeField, ...dataField]);
  }

  /// Decodes a public key from protobuf bytes.
  static PublicKeyPb decode(Uint8List bytes) {
    var type = KeyType.ed25519;
    var data = Uint8List(0);
    for (final f in _parseFields(bytes)) {
      if (f.fieldNumber == 1 && f.wireType == _wireTypeVarint) {
        type = KeyType.fromValue(f.value as int);
      } else if (f.fieldNumber == 2 && f.wireType == _wireTypeLengthDelimited) {
        data = f.value as Uint8List;
      }
    }
    return PublicKeyPb(type: type, data: data);
  }

  @override
  String toString() => 'PublicKeyPb(type: $type, dataLength: ${data.length})';

  @override
  bool operator ==(Object other) =>
      other is PublicKeyPb &&
      type == other.type &&
      _listEquals(data, other.data);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(data));
}

/// ---------------------------------------------------------------------------
/// PeerRecord message (libp2p core/peer/pb/peer_record.proto)
/// ---------------------------------------------------------------------------

/// A libp2p peer record in protobuf form.
///
/// ```protobuf
/// message PeerRecord {
///   bytes PeerID = 1;
///   repeated bytes addresses = 2;
///   uint64 timestamp = 3;
///   uint64 seq = 4;
/// }
/// ```
class PeerRecordPb {
  /// Creates a peer record protobuf message.
  PeerRecordPb({
    required this.peerId,
    required this.addresses,
    required this.timestamp,
    required this.seq,
  });

  /// The peer ID bytes (marshalled peer id).
  final Uint8List peerId;

  /// The list of multiaddr bytes.
  final List<Uint8List> addresses;

  /// Unix timestamp in microseconds (per go-libp2p).
  final int timestamp;

  /// Sequence number, incremented on each update.
  final int seq;

  /// Encodes this peer record to protobuf bytes.
  Uint8List encode() {
    final result = <int>[];
    result.addAll(_encodeLengthDelimited(1, peerId));
    for (final addr in addresses) {
      result.addAll(_encodeLengthDelimited(2, addr));
    }
    result.addAll(_encodeVarintField(3, timestamp));
    result.addAll(_encodeVarintField(4, seq));
    return Uint8List.fromList(result);
  }

  /// Decodes a peer record from protobuf bytes.
  static PeerRecordPb decode(Uint8List bytes) {
    var peerId = Uint8List(0);
    final addresses = <Uint8List>[];
    var timestamp = 0;
    var seq = 0;
    for (final f in _parseFields(bytes)) {
      if (f.fieldNumber == 1 && f.wireType == _wireTypeLengthDelimited) {
        peerId = f.value as Uint8List;
      } else if (f.fieldNumber == 2 && f.wireType == _wireTypeLengthDelimited) {
        addresses.add(f.value as Uint8List);
      } else if (f.fieldNumber == 3 && f.wireType == _wireTypeVarint) {
        timestamp = f.value as int;
      } else if (f.fieldNumber == 4 && f.wireType == _wireTypeVarint) {
        seq = f.value as int;
      }
    }
    return PeerRecordPb(
      peerId: peerId,
      addresses: addresses,
      timestamp: timestamp,
      seq: seq,
    );
  }

  @override
  String toString() =>
      'PeerRecordPb(peerId: ${utf8.decode(peerId, allowMalformed: true)}, '
      'addresses: ${addresses.length}, timestamp: $timestamp, seq: $seq)';

  @override
  bool operator ==(Object other) =>
      other is PeerRecordPb &&
      _listEquals(peerId, other.peerId) &&
      _listListEquals(addresses, other.addresses) &&
      timestamp == other.timestamp &&
      seq == other.seq;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(peerId),
    Object.hashAll(addresses),
    timestamp,
    seq,
  );
}

/// ---------------------------------------------------------------------------
/// Envelope message (libp2p core/record/pb/envelope.proto)
/// ---------------------------------------------------------------------------

/// A signed envelope containing a peer record.
///
/// ```protobuf
/// message Envelope {
///   PublicKey public_key = 1;
///   bytes payload_type = 2;
///   bytes payload = 3;
///   bytes signature = 5;
/// }
/// ```
class EnvelopePb {
  /// Creates a signed envelope.
  EnvelopePb({
    required this.publicKey,
    required this.payloadType,
    required this.payload,
    required this.signature,
  });

  /// The public key of the signer.
  final PublicKeyPb publicKey;

  /// The payload type (multicodec-prefixed).
  final Uint8List payloadType;

  /// The serialized PeerRecord payload.
  final Uint8List payload;

  /// The Ed25519 signature over the signing buffer.
  final Uint8List signature;

  /// Encodes this envelope to protobuf bytes.
  Uint8List encode() {
    final result = <int>[];
    result.addAll(_encodeLengthDelimited(1, publicKey.encode()));
    result.addAll(_encodeLengthDelimited(2, payloadType));
    result.addAll(_encodeLengthDelimited(3, payload));
    result.addAll(_encodeLengthDelimited(5, signature));
    return Uint8List.fromList(result);
  }

  /// Decodes an envelope from protobuf bytes.
  static EnvelopePb decode(Uint8List bytes) {
    var publicKey = PublicKeyPb(type: KeyType.ed25519, data: Uint8List(0));
    var payloadType = Uint8List(0);
    var payload = Uint8List(0);
    var signature = Uint8List(0);
    for (final f in _parseFields(bytes)) {
      if (f.fieldNumber == 1 && f.wireType == _wireTypeLengthDelimited) {
        publicKey = PublicKeyPb.decode(f.value as Uint8List);
      } else if (f.fieldNumber == 2 && f.wireType == _wireTypeLengthDelimited) {
        payloadType = f.value as Uint8List;
      } else if (f.fieldNumber == 3 && f.wireType == _wireTypeLengthDelimited) {
        payload = f.value as Uint8List;
      } else if (f.fieldNumber == 5 && f.wireType == _wireTypeLengthDelimited) {
        signature = f.value as Uint8List;
      }
    }
    return EnvelopePb(
      publicKey: publicKey,
      payloadType: payloadType,
      payload: payload,
      signature: signature,
    );
  }

  @override
  String toString() =>
      'EnvelopePb(publicKey: $publicKey, payloadTypeLength: ${payloadType.length}, '
      'payloadLength: ${payload.length}, signatureLength: ${signature.length})';

  @override
  bool operator ==(Object other) =>
      other is EnvelopePb &&
      publicKey == other.publicKey &&
      _listEquals(payloadType, other.payloadType) &&
      _listEquals(payload, other.payload) &&
      _listEquals(signature, other.signature);

  @override
  int get hashCode => Object.hash(
    publicKey,
    Object.hashAll(payloadType),
    Object.hashAll(payload),
    Object.hashAll(signature),
  );
}

/// Compares two byte lists for equality.
bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Compares two lists of byte lists for equality.
bool _listListEquals(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_listEquals(a[i], b[i])) return false;
  }
  return true;
}
