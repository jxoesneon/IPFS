// lib/src/protocols/identify/identify_pb.dart
//
// Manual protobuf codec for the libp2p Identify message.
//
// Implements the wire format for the Identify protobuf used by the
// /ipfs/id/1.0.0 and /ipfs/id/push/1.0.0 protocols.
//
// ```protobuf
// message Identify {
//   optional bytes publicKey = 1;
//   repeated bytes listenAddrs = 2;
//   repeated string protocols = 3;
//   optional bytes observedAddr = 4;
//   optional string protocolVersion = 5;
//   optional string agentVersion = 6;
//   optional bytes signedPeerRecord = 8;
// }
// ```

import 'dart:convert';
import 'dart:typed_data';

import '../../core/peer/peer_record_pb.dart';

/// Wire type constants (re-declared locally to keep this file self-contained).
const int _wireTypeVarint = 0;
const int _wireTypeLengthDelimited = 2;

/// The libp2p Identify message.
class IdentifyPb {
  /// Creates an Identify message.
  IdentifyPb({
    this.publicKey,
    List<Uint8List>? listenAddrs,
    List<String>? protocols,
    this.observedAddr,
    this.protocolVersion,
    this.agentVersion,
    this.signedPeerRecord,
  }) : listenAddrs = listenAddrs ?? [],
       protocols = protocols ?? [];

  /// The public key of the peer (marshalled protobuf PublicKey).
  final Uint8List? publicKey;

  /// The listen addresses of the peer (multiaddr bytes).
  final List<Uint8List> listenAddrs;

  /// The protocols supported by the peer.
  final List<String> protocols;

  /// The observed address of the remote peer (multiaddr bytes).
  final Uint8List? observedAddr;

  /// The protocol version string (e.g. "ipfs/0.1.0").
  final String? protocolVersion;

  /// The agent version string (e.g. "dart_ipfs/1.11.5").
  final String? agentVersion;

  /// The signed peer record envelope bytes.
  final Uint8List? signedPeerRecord;

  /// Encodes this Identify message to protobuf bytes.
  Uint8List encode() {
    final result = <int>[];

    if (publicKey != null) {
      result.addAll(_encodeBytes(1, publicKey!));
    }
    for (final addr in listenAddrs) {
      result.addAll(_encodeBytes(2, addr));
    }
    for (final proto in protocols) {
      result.addAll(_encodeString(3, proto));
    }
    if (observedAddr != null) {
      result.addAll(_encodeBytes(4, observedAddr!));
    }
    if (protocolVersion != null) {
      result.addAll(_encodeString(5, protocolVersion!));
    }
    if (agentVersion != null) {
      result.addAll(_encodeString(6, agentVersion!));
    }
    if (signedPeerRecord != null) {
      result.addAll(_encodeBytes(8, signedPeerRecord!));
    }

    return Uint8List.fromList(result);
  }

  /// Decodes an Identify message from protobuf bytes.
  static IdentifyPb decode(Uint8List bytes) {
    Uint8List? publicKey;
    final listenAddrs = <Uint8List>[];
    final protocols = <String>[];
    Uint8List? observedAddr;
    String? protocolVersion;
    String? agentVersion;
    Uint8List? signedPeerRecord;

    var offset = 0;
    while (offset < bytes.length) {
      final (tag, tagLen) = decodeVarint(bytes, offset);
      offset += tagLen;
      final wireType = tag & 0x07;
      final fieldNumber = tag >> 3;

      if (wireType == _wireTypeVarint) {
        final (_, valLen) = decodeVarint(bytes, offset);
        offset += valLen;
      } else if (wireType == _wireTypeLengthDelimited) {
        final (length, lenSize) = decodeVarint(bytes, offset);
        offset += lenSize;
        final payload = bytes.sublist(offset, offset + length);
        offset += length;

        switch (fieldNumber) {
          case 1:
            publicKey = Uint8List.fromList(payload);
            break;
          case 2:
            listenAddrs.add(Uint8List.fromList(payload));
            break;
          case 3:
            protocols.add(utf8.decode(payload, allowMalformed: true));
            break;
          case 4:
            observedAddr = Uint8List.fromList(payload);
            break;
          case 5:
            protocolVersion = utf8.decode(payload, allowMalformed: true);
            break;
          case 6:
            agentVersion = utf8.decode(payload, allowMalformed: true);
            break;
          case 8:
            signedPeerRecord = Uint8List.fromList(payload);
            break;
        }
      } else {
        throw FormatException(
          'Unsupported wire type $wireType for field $fieldNumber',
        );
      }
    }

    return IdentifyPb(
      publicKey: publicKey,
      listenAddrs: listenAddrs,
      protocols: protocols,
      observedAddr: observedAddr,
      protocolVersion: protocolVersion,
      agentVersion: agentVersion,
      signedPeerRecord: signedPeerRecord,
    );
  }

  @override
  String toString() =>
      'IdentifyPb(protocolVersion: $protocolVersion, agentVersion: $agentVersion, '
      'protocols: $protocols, listenAddrs: ${listenAddrs.length}, '
      'hasSignedPeerRecord: ${signedPeerRecord != null})';

  @override
  bool operator ==(Object other) =>
      other is IdentifyPb &&
      _optBytesEq(publicKey, other.publicKey) &&
      _listListEq(listenAddrs, other.listenAddrs) &&
      _listStrEq(protocols, other.protocols) &&
      _optBytesEq(observedAddr, other.observedAddr) &&
      protocolVersion == other.protocolVersion &&
      agentVersion == other.agentVersion &&
      _optBytesEq(signedPeerRecord, other.signedPeerRecord);

  @override
  int get hashCode => Object.hash(
    protocolVersion,
    agentVersion,
    Object.hashAll(protocols),
    listenAddrs.length,
    publicKey != null,
    observedAddr != null,
    signedPeerRecord != null,
  );
}

// --- Encoding helpers ---

List<int> _encodeBytes(int fieldNumber, Uint8List value) {
  final tag = encodeVarint((fieldNumber << 3) | _wireTypeLengthDelimited);
  final length = encodeVarint(value.length);
  return [...tag, ...length, ...value];
}

List<int> _encodeString(int fieldNumber, String value) {
  return _encodeBytes(fieldNumber, Uint8List.fromList(utf8.encode(value)));
}

// --- Comparison helpers ---

bool _optBytesEq(Uint8List? a, Uint8List? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _listListEq(List<Uint8List> a, List<Uint8List> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_optBytesEq(a[i], b[i])) return false;
  }
  return true;
}

bool _listStrEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
