// lib/src/protocols/gossipsub/gossipsub_rpc.dart
//
// Minimal hand-rolled codec for the libp2p pubsub (gossipsub) wire protocol,
// matching the proto2 schema used by go-libp2p-pubsub and js-libp2p pubsub:
//
//   message RPC {
//     repeated SubOpts subscriptions = 1;
//     repeated Message publish = 2;
//     optional ControlMessage control = 3;
//   }
//   message RPC.SubOpts {
//     optional bool subscribe = 1;
//     optional string topicid = 2;
//   }
//   message Message {
//     optional bytes from = 1;
//     optional bytes data = 2;
//     optional bytes seqno = 3;
//     optional string topic = 4;
//     optional bytes signature = 5;
//     optional bytes key = 6;
//   }
//   message ControlMessage {
//     repeated ControlIHave ihave = 1;
//     repeated ControlIWant iwant = 2;
//     repeated ControlGraft graft = 3;
//     repeated ControlPrune prune = 4;
//     repeated ControlIDontWant idontwant = 5;
//   }
//
// Implemented by hand rather than generated so the decoder can enforce
// explicit bounds on every remote-controlled field (message counts, field
// lengths, total RPC size) at decode time.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Protocol ID for gossipsub v1.1 (the version spoken by Kubo and Helia).
const String kMeshsubProtocolV11 = '/meshsub/1.1.0';

/// Protocol ID for gossipsub v1.0; wire-compatible with v1.1 for the
/// subscription/publish/control subset implemented here.
const String kMeshsubProtocolV10 = '/meshsub/1.0.0';

/// All gossipsub protocol IDs this node accepts inbound streams for.
const List<String> kMeshsubProtocolIds = <String>[
  kMeshsubProtocolV11,
  kMeshsubProtocolV10,
];

/// Domain-separation prefix for pubsub message signatures, per the libp2p
/// pubsub specification: `sign(priv, "libp2p-pubsub:" || marshal(msg))` where
/// the marshalled message excludes the `signature` and `key` fields.
const String kGossipSubSignPrefix = 'libp2p-pubsub:';

/// A topic subscription announcement carried in an RPC envelope.
class GossipSubSubOpts {
  /// Creates a [GossipSubSubOpts].
  GossipSubSubOpts({this.subscribe, this.topicId});

  /// Whether the peer is subscribing (`true`) or unsubscribing (`false`).
  bool? subscribe;

  /// The topic being subscribed or unsubscribed.
  String? topicId;
}

/// A published message in the gossipsub wire format.
class GossipSubMessage {
  /// Creates a [GossipSubMessage].
  GossipSubMessage({
    this.from,
    this.data,
    this.seqno,
    this.topic,
    this.signature,
    this.key,
  });

  /// The author's peer ID, as raw multihash bytes.
  Uint8List? from;

  /// The opaque message payload.
  Uint8List? data;

  /// The author's sequence number (a 64-bit big-endian counter).
  Uint8List? seqno;

  /// The topic this message was published to.
  String? topic;

  /// The author's signature over [gossipSubSigningPayload] of this message.
  Uint8List? signature;

  /// The author's protobuf-marshalled public key, present when the peer ID
  /// does not embed the key itself (non-identity multihash peer IDs).
  Uint8List? key;
}

/// IHAVE control record: advertises message IDs the peer holds for a topic.
class GossipSubIHave {
  /// Creates a [GossipSubIHave].
  GossipSubIHave({this.topicId, List<Uint8List>? messageIds})
    : messageIds = messageIds ?? <Uint8List>[];

  /// The topic the advertised messages belong to.
  String? topicId;

  /// Advertised message IDs as raw bytes (they are arbitrary binary values,
  /// not guaranteed to be valid UTF-8).
  final List<Uint8List> messageIds;
}

/// IWANT control record: requests full messages by ID.
class GossipSubIWant {
  /// Creates a [GossipSubIWant].
  GossipSubIWant({List<Uint8List>? messageIds})
    : messageIds = messageIds ?? <Uint8List>[];

  /// Requested message IDs as raw bytes.
  final List<Uint8List> messageIds;
}

/// GRAFT control record: asks to join the sender's mesh for a topic.
class GossipSubGraft {
  /// Creates a [GossipSubGraft].
  GossipSubGraft({this.topicId});

  /// The topic being grafted.
  String? topicId;
}

/// PRUNE control record: removes the sender from a topic mesh.
class GossipSubPrune {
  /// Creates a [GossipSubPrune].
  GossipSubPrune({this.topicId, this.backoff});

  /// The topic being pruned.
  String? topicId;

  /// Suggested backoff in seconds before re-grafting (informational).
  int? backoff;
}

/// IDONTWANT control record (gossipsub v1.1): asks the receiver not to send
/// the listed message IDs again.
class GossipSubIDontWant {
  /// Creates a [GossipSubIDontWant].
  GossipSubIDontWant({List<Uint8List>? messageIds})
    : messageIds = messageIds ?? <Uint8List>[];

  /// Message IDs the sender does not want to receive, as raw bytes.
  final List<Uint8List> messageIds;
}

/// The gossipsub control message payload.
class GossipSubControl {
  /// Creates a [GossipSubControl].
  GossipSubControl({
    List<GossipSubIHave>? ihave,
    List<GossipSubIWant>? iwant,
    List<GossipSubGraft>? graft,
    List<GossipSubPrune>? prune,
    List<GossipSubIDontWant>? idontwant,
  }) : ihave = ihave ?? <GossipSubIHave>[],
       iwant = iwant ?? <GossipSubIWant>[],
       graft = graft ?? <GossipSubGraft>[],
       prune = prune ?? <GossipSubPrune>[],
       idontwant = idontwant ?? <GossipSubIDontWant>[];

  /// IHAVE records.
  final List<GossipSubIHave> ihave;

  /// IWANT records.
  final List<GossipSubIWant> iwant;

  /// GRAFT records.
  final List<GossipSubGraft> graft;

  /// PRUNE records.
  final List<GossipSubPrune> prune;

  /// IDONTWANT records.
  final List<GossipSubIDontWant> idontwant;

  /// Whether this control message carries no records at all.
  bool get isEmpty =>
      ihave.isEmpty &&
      iwant.isEmpty &&
      graft.isEmpty &&
      prune.isEmpty &&
      idontwant.isEmpty;
}

/// A gossipsub RPC envelope: the top-level frame exchanged on a
/// `/meshsub/1.x.0` stream (length-prefixed on the wire by the transport).
class GossipSubRpc {
  /// Creates a [GossipSubRpc].
  GossipSubRpc({
    List<GossipSubSubOpts>? subscriptions,
    List<GossipSubMessage>? publish,
    this.control,
  }) : subscriptions = subscriptions ?? <GossipSubSubOpts>[],
       publish = publish ?? <GossipSubMessage>[];

  /// Subscription announcements.
  final List<GossipSubSubOpts> subscriptions;

  /// Published messages.
  final List<GossipSubMessage> publish;

  /// Optional control payload.
  GossipSubControl? control;
}

/// Encoder/decoder for [GossipSubRpc] frames.
///
/// All remote-controlled sizes are bounded at decode time; exceeding any
/// bound raises a [FormatException] so callers can drop the frame.
abstract final class GossipSubRpcCodec {
  /// Maximum size of a single RPC frame (matches go-libp2p-pubsub's
  /// DefaultMaxMessageSize of 1 MiB).
  static const int maxRpcSize = 1 << 20;

  /// Maximum subscription announcements per RPC.
  static const int maxSubscriptions = 512;

  /// Maximum published messages per RPC.
  static const int maxPublishMessages = 256;

  /// Maximum control records of each kind per RPC.
  static const int maxControlRecords = 256;

  /// Maximum message IDs per IHAVE/IWANT/IDONTWANT record.
  static const int maxMessageIdsPerRecord = 512;

  /// Maximum length of a topic ID string in bytes.
  static const int maxTopicBytes = 4096;

  /// Maximum length of a message ID in bytes.
  static const int maxMessageIdBytes = 256;

  /// Maximum length of the `from` peer ID field.
  static const int maxPeerIdBytes = 1024;

  /// Maximum length of the signing public key field.
  static const int maxKeyBytes = 4096;

  /// Maximum length of the signature field.
  static const int maxSignatureBytes = 1024;

  /// Maximum length of the seqno field.
  static const int maxSeqnoBytes = 64;

  /// Encodes [rpc] into its protobuf wire representation.
  static Uint8List encode(GossipSubRpc rpc) {
    final builder = BytesBuilder(copy: false);
    for (final sub in rpc.subscriptions) {
      _lengthDelimited(builder, 1, _encodeSubOpts(sub));
    }
    for (final msg in rpc.publish) {
      _lengthDelimited(builder, 2, encodeMessage(msg));
    }
    final control = rpc.control;
    if (control != null && !control.isEmpty) {
      _lengthDelimited(builder, 3, _encodeControl(control));
    }
    return builder.takeBytes();
  }

  /// Encodes a single [GossipSubMessage] in protobuf wire format.
  ///
  /// When [includeSignature] or [includeKey] is `false` the corresponding
  /// fields are omitted; this is the canonical form covered by the
  /// signature per the pubsub spec.
  static Uint8List encodeMessage(
    GossipSubMessage msg, {
    bool includeSignature = true,
    bool includeKey = true,
  }) {
    final builder = BytesBuilder(copy: false);
    _bytesField(builder, 1, msg.from);
    _bytesField(builder, 2, msg.data);
    _bytesField(builder, 3, msg.seqno);
    _stringField(builder, 4, msg.topic);
    if (includeSignature) _bytesField(builder, 5, msg.signature);
    if (includeKey) _bytesField(builder, 6, msg.key);
    return builder.takeBytes();
  }

  /// Decodes [bytes] into a [GossipSubRpc].
  ///
  /// Throws [FormatException] when the frame is malformed or exceeds any
  /// of the bounds on this class. Unknown fields are skipped.
  static GossipSubRpc decode(Uint8List bytes) {
    if (bytes.length > maxRpcSize) {
      throw FormatException(
        'gossipsub RPC exceeds maximum size '
        '(${bytes.length} > $maxRpcSize bytes)',
      );
    }
    final rpc = GossipSubRpc();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          if (rpc.subscriptions.length >= maxSubscriptions) {
            throw const FormatException(
              'too many subscriptions in gossipsub RPC',
            );
          }
          rpc.subscriptions.add(_decodeSubOpts(reader.readField(wireType)));
        case 2:
          if (rpc.publish.length >= maxPublishMessages) {
            throw const FormatException('too many messages in gossipsub RPC');
          }
          rpc.publish.add(decodeMessage(reader.readField(wireType)));
        case 3:
          rpc.control = _decodeControl(reader.readField(wireType));
        default:
          reader.skipField(wireType);
      }
    }
    return rpc;
  }

  /// Decodes a single [GossipSubMessage] from [bytes].
  ///
  /// Throws [FormatException] on malformed input; unknown fields are skipped.
  static GossipSubMessage decodeMessage(Uint8List bytes) {
    final msg = GossipSubMessage();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          msg.from = _boundedBytes(reader, wireType, maxPeerIdBytes, 'from');
        case 2:
          msg.data = reader.readField(wireType);
        case 3:
          msg.seqno = _boundedBytes(reader, wireType, maxSeqnoBytes, 'seqno');
        case 4:
          msg.topic = _boundedString(reader, wireType, maxTopicBytes, 'topic');
        case 5:
          msg.signature = _boundedBytes(
            reader,
            wireType,
            maxSignatureBytes,
            'signature',
          );
        case 6:
          msg.key = _boundedBytes(reader, wireType, maxKeyBytes, 'key');
        default:
          reader.skipField(wireType);
      }
    }
    return msg;
  }

  // ---- SubOpts ----

  static Uint8List _encodeSubOpts(GossipSubSubOpts sub) {
    final builder = BytesBuilder(copy: false);
    final subscribe = sub.subscribe;
    if (subscribe != null) {
      _varintField(builder, 1, subscribe ? 1 : 0);
    }
    _stringField(builder, 2, sub.topicId);
    return builder.takeBytes();
  }

  static GossipSubSubOpts _decodeSubOpts(Uint8List bytes) {
    final sub = GossipSubSubOpts();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          sub.subscribe = reader.readVarintField(wireType) != 0;
        case 2:
          sub.topicId = _boundedString(
            reader,
            wireType,
            maxTopicBytes,
            'topicid',
          );
        default:
          reader.skipField(wireType);
      }
    }
    return sub;
  }

  // ---- ControlMessage ----

  static Uint8List _encodeControl(GossipSubControl control) {
    final builder = BytesBuilder(copy: false);
    for (final ihave in control.ihave) {
      final inner = BytesBuilder(copy: false);
      _stringField(inner, 1, ihave.topicId);
      for (final id in ihave.messageIds) {
        _bytesField(inner, 2, id);
      }
      _lengthDelimited(builder, 1, inner.takeBytes());
    }
    for (final iwant in control.iwant) {
      final inner = BytesBuilder(copy: false);
      for (final id in iwant.messageIds) {
        _bytesField(inner, 1, id);
      }
      _lengthDelimited(builder, 2, inner.takeBytes());
    }
    for (final graft in control.graft) {
      final inner = BytesBuilder(copy: false);
      _stringField(inner, 1, graft.topicId);
      _lengthDelimited(builder, 3, inner.takeBytes());
    }
    for (final prune in control.prune) {
      final inner = BytesBuilder(copy: false);
      _stringField(inner, 1, prune.topicId);
      final backoff = prune.backoff;
      if (backoff != null) {
        _varintField(inner, 3, backoff);
      }
      _lengthDelimited(builder, 4, inner.takeBytes());
    }
    for (final idontwant in control.idontwant) {
      final inner = BytesBuilder(copy: false);
      for (final id in idontwant.messageIds) {
        _bytesField(inner, 1, id);
      }
      _lengthDelimited(builder, 5, inner.takeBytes());
    }
    return builder.takeBytes();
  }

  static GossipSubControl _decodeControl(Uint8List bytes) {
    final control = GossipSubControl();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          if (control.ihave.length >= maxControlRecords) {
            throw const FormatException(
              'too many IHAVE records in gossipsub RPC',
            );
          }
          control.ihave.add(_decodeIHave(reader.readField(wireType)));
        case 2:
          if (control.iwant.length >= maxControlRecords) {
            throw const FormatException(
              'too many IWANT records in gossipsub RPC',
            );
          }
          control.iwant.add(_decodeIWant(reader.readField(wireType)));
        case 3:
          if (control.graft.length >= maxControlRecords) {
            throw const FormatException(
              'too many GRAFT records in gossipsub RPC',
            );
          }
          control.graft.add(_decodeGraft(reader.readField(wireType)));
        case 4:
          if (control.prune.length >= maxControlRecords) {
            throw const FormatException(
              'too many PRUNE records in gossipsub RPC',
            );
          }
          control.prune.add(_decodePrune(reader.readField(wireType)));
        case 5:
          if (control.idontwant.length >= maxControlRecords) {
            throw const FormatException(
              'too many IDONTWANT records in gossipsub RPC',
            );
          }
          control.idontwant.add(_decodeIDontWant(reader.readField(wireType)));
        default:
          reader.skipField(wireType);
      }
    }
    return control;
  }

  static GossipSubIHave _decodeIHave(Uint8List bytes) {
    final ihave = GossipSubIHave();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          ihave.topicId = _boundedString(
            reader,
            wireType,
            maxTopicBytes,
            'topicID',
          );
        case 2:
          ihave.messageIds.add(
            _boundedMessageId(reader, wireType, ihave.messageIds.length),
          );
        default:
          reader.skipField(wireType);
      }
    }
    return ihave;
  }

  static GossipSubIWant _decodeIWant(Uint8List bytes) {
    final iwant = GossipSubIWant();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          iwant.messageIds.add(
            _boundedMessageId(reader, wireType, iwant.messageIds.length),
          );
        default:
          reader.skipField(wireType);
      }
    }
    return iwant;
  }

  static GossipSubGraft _decodeGraft(Uint8List bytes) {
    final graft = GossipSubGraft();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      if (field == 1) {
        graft.topicId = _boundedString(
          reader,
          wireType,
          maxTopicBytes,
          'topicID',
        );
      } else {
        reader.skipField(wireType);
      }
    }
    return graft;
  }

  static GossipSubPrune _decodePrune(Uint8List bytes) {
    final prune = GossipSubPrune();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          prune.topicId = _boundedString(
            reader,
            wireType,
            maxTopicBytes,
            'topicID',
          );
        case 2:
          // PeerInfo records (alternative peers with signed records) are
          // not consumed; skip them.
          reader.skipField(wireType);
        case 3:
          prune.backoff = reader.readVarintField(wireType);
        default:
          reader.skipField(wireType);
      }
    }
    return prune;
  }

  static GossipSubIDontWant _decodeIDontWant(Uint8List bytes) {
    final idontwant = GossipSubIDontWant();
    final reader = _WireReader(bytes);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      if (field == 1) {
        idontwant.messageIds.add(
          _boundedMessageId(reader, wireType, idontwant.messageIds.length),
        );
      } else {
        reader.skipField(wireType);
      }
    }
    return idontwant;
  }

  // ---- Field-level helpers ----

  static Uint8List _boundedBytes(
    _WireReader reader,
    int wireType,
    int maxBytes,
    String name,
  ) {
    final value = reader.readField(wireType);
    if (value.length > maxBytes) {
      throw FormatException(
        'gossipsub field $name exceeds bound '
        '(${value.length} > $maxBytes bytes)',
      );
    }
    return value;
  }

  static Uint8List _boundedMessageId(
    _WireReader reader,
    int wireType,
    int count,
  ) {
    if (count >= maxMessageIdsPerRecord) {
      throw const FormatException(
        'too many message IDs in gossipsub control record',
      );
    }
    return _boundedBytes(reader, wireType, maxMessageIdBytes, 'messageID');
  }

  static String _boundedString(
    _WireReader reader,
    int wireType,
    int maxBytes,
    String name,
  ) {
    final raw = _boundedBytes(reader, wireType, maxBytes, name);
    // utf8.decode is strict by default: malformed UTF-8 in a proto `string`
    // field makes the frame invalid, matching go-protobuf behavior.
    return utf8.decode(raw);
  }

  static void _varintField(BytesBuilder builder, int field, int value) {
    _tag(builder, field, 0);
    _writeVarint(builder, value);
  }

  static void _bytesField(BytesBuilder builder, int field, Uint8List? value) {
    if (value == null) return;
    _lengthDelimited(builder, field, value);
  }

  static void _stringField(BytesBuilder builder, int field, String? value) {
    if (value == null) return;
    _lengthDelimited(builder, field, Uint8List.fromList(utf8.encode(value)));
  }

  static void _lengthDelimited(
    BytesBuilder builder,
    int field,
    Uint8List value,
  ) {
    _tag(builder, field, 2);
    _writeVarint(builder, value.length);
    builder.add(value);
  }

  static void _tag(BytesBuilder builder, int field, int wireType) {
    _writeVarint(builder, (field << 3) | wireType);
  }

  static void _writeVarint(BytesBuilder builder, int value) {
    var v = value;
    while (v > 0x7f) {
      builder.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    builder.addByte(v);
  }
}

/// Returns the canonical signature payload for [msg] per the libp2p pubsub
/// spec: `"libp2p-pubsub:" || marshal(Message)` with the `signature` and
/// `key` fields omitted.
Uint8List gossipSubSigningPayload(GossipSubMessage msg) {
  final body = GossipSubRpcCodec.encodeMessage(
    msg,
    includeSignature: false,
    includeKey: false,
  );
  final prefix = utf8.encode(kGossipSubSignPrefix);
  final payload = Uint8List(prefix.length + body.length);
  payload.setRange(0, prefix.length, prefix);
  payload.setRange(prefix.length, payload.length, body);
  return payload;
}

/// Returns the default gossipsub message ID for [msg]: `from || seqno`
/// (go-libp2p-pubsub's DefaultMsgIdFn). Peers with a custom ID function
/// will compute different IDs; this matches the interoperable default.
Uint8List gossipSubDefaultMessageId(GossipSubMessage msg) {
  final from = msg.from ?? Uint8List(0);
  final seqno = msg.seqno ?? Uint8List(0);
  final id = Uint8List(from.length + seqno.length);
  id.setRange(0, from.length, from);
  id.setRange(from.length, id.length, seqno);
  return id;
}

/// Marshals a 32-byte Ed25519 public key into the libp2p `PublicKey` protobuf
/// encoding used in the message `key` field: `{key_type: Ed25519(1), data}`.
Uint8List marshalGossipSubEd25519PublicKey(Uint8List publicKey) {
  if (publicKey.length != 32) {
    throw ArgumentError(
      'Ed25519 public key must be 32 bytes, got ${publicKey.length}',
    );
  }
  return Uint8List.fromList(<int>[0x08, 0x01, 0x12, 0x20, ...publicKey]);
}

/// Unmarshals a libp2p `PublicKey` protobuf blob, returning the raw 32-byte
/// Ed25519 key, or `null` when the blob is not a valid Ed25519 key.
Uint8List? unmarshalGossipSubPublicKey(Uint8List marshalled) {
  try {
    int? keyType;
    Uint8List? data;
    final reader = _WireReader(marshalled);
    while (!reader.isDone) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wireType = tag & 0x7;
      switch (field) {
        case 1:
          keyType = reader.readVarintField(wireType);
        case 2:
          data = reader.readField(wireType);
        default:
          reader.skipField(wireType);
      }
    }
    if (keyType == 1 && data != null && data.length == 32) {
      return data;
    }
    return null;
  } on FormatException {
    return null;
  }
}

/// Extracts the Ed25519 public key embedded in an identity-multihash peer ID
/// (`0x00 <len> <marshalled PublicKey>`), or `null` when [peerId] is not an
/// identity multihash containing an Ed25519 key.
Uint8List? gossipSubPeerIdPublicKey(Uint8List peerId) {
  if (peerId.length >= 2 && peerId[0] == 0x00) {
    final length = peerId[1];
    if (peerId.length == 2 + length) {
      return unmarshalGossipSubPublicKey(Uint8List.fromList(peerId.sublist(2)));
    }
  }
  return null;
}

/// Returns `true` when [peerId] is the peer ID derived from [publicKey],
/// supporting both identity multihashes (key embedded inline) and SHA-256
/// multihashes (`0x12 0x20 sha256(marshalled key)`, the `Qm...` form).
bool gossipSubPeerIdMatchesKey(Uint8List peerId, Uint8List publicKey) {
  final embedded = gossipSubPeerIdPublicKey(peerId);
  if (embedded != null) {
    return _bytesEqual(embedded, publicKey);
  }
  if (peerId.length == 34 && peerId[0] == 0x12 && peerId[1] == 0x20) {
    final digest = crypto.sha256
        .convert(marshalGossipSubEd25519PublicKey(publicKey))
        .bytes;
    return _bytesEqual(Uint8List.fromList(digest), peerId.sublist(2));
  }
  return false;
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Bounds-checked protobuf wire reader over a single message buffer.
class _WireReader {
  _WireReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  /// Whether the buffer has been fully consumed.
  bool get isDone => _offset >= _bytes.length;

  /// Reads a protobuf varint (up to 63 bits).
  ///
  /// Throws [FormatException] on truncation or when the encoding would
  /// exceed 63 bits — every field decoded through this reader (lengths,
  /// counts, backoffs, enum values) fits comfortably below that bound.
  int readVarint() {
    var value = 0;
    var shift = 0;
    while (true) {
      if (_offset >= _bytes.length) {
        throw const FormatException('truncated varint in gossipsub frame');
      }
      if (shift >= 63) {
        throw const FormatException(
          'varint exceeds 63 bits in gossipsub frame',
        );
      }
      final byte = _bytes[_offset++];
      value |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return value;
      shift += 7;
    }
  }

  /// Reads a varint field that must have wire type 0.
  int readVarintField(int wireType) {
    if (wireType != 0) {
      throw FormatException('expected varint field, got wire type $wireType');
    }
    return readVarint();
  }

  /// Reads a length-delimited field that must have wire type 2.
  Uint8List readField(int wireType) {
    if (wireType != 2) {
      throw FormatException(
        'expected length-delimited field, got wire type $wireType',
      );
    }
    return readLengthDelimited();
  }

  /// Reads `varint length || bytes`.
  Uint8List readLengthDelimited() {
    final length = readVarint();
    if (length > _bytes.length - _offset) {
      throw const FormatException(
        'length-delimited field exceeds frame bounds',
      );
    }
    final value = Uint8List.fromList(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }

  /// Skips a field of the given wire type without interpreting it.
  ///
  /// Supports wire types 0 (varint), 1 (64-bit), 2 (length-delimited) and
  /// 5 (32-bit); anything else is rejected as malformed.
  void skipField(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
      case 1:
        _skip(8);
      case 2:
        readLengthDelimited();
      case 5:
        _skip(4);
      default:
        throw FormatException('unsupported wire type $wireType');
    }
  }

  void _skip(int bytes) {
    if (bytes > _bytes.length - _offset) {
      throw const FormatException('fixed-width field exceeds frame bounds');
    }
    _offset += bytes;
  }
}
