import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart'
    show V_PeerInfo;
import 'package:dart_ipfs/src/utils/base58.dart';

/// Interface for DHT handler implementations.
abstract class IDHTHandler {
  /// Finds peer information for a given peer ID.
  Future<List<V_PeerInfo>> findPeer(PeerId id);

  /// Announces that this node provides content for a CID.
  Future<void> provide(CID cid);

  /// Finds providers for a given CID.
  Future<List<V_PeerInfo>> findProviders(CID cid);

  /// Stores a value in the DHT.
  Future<void> putValue(Key key, Value value);

  /// Retrieves a value from the DHT.
  Future<Value> getValue(Key key);

  /// Handles updates to the routing table.
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer);

  /// Handles a request to provide content.
  Future<void> handleProvideRequest(CID cid, PeerId provider);

  /// Starts the DHT handler.
  Future<void> start() async {}

  /// Stops the DHT handler.
  Future<void> stop() async {}
}

/// Represents a key in the DHT
class Key {
  /// Creates a key from raw bytes.
  const Key(this.bytes);

  /// Creates a Key from a string by encoding it to UTF-8 bytes.
  factory Key.fromString(String str) {
    return Key(Uint8List.fromList(utf8.encode(str)));
  }

  /// Creates a Key from raw bytes.
  factory Key.fromBytes(Uint8List bytes) {
    return Key(bytes);
  }

  /// The raw byte content of this key.
  final Uint8List bytes;

  @override
  String toString() {
    return Base58().encode(bytes);
  }
}

/// Represents a value stored in the DHT
class Value {
  /// Creates a value from raw bytes.
  const Value(this.bytes);

  /// Creates a Value from a string by encoding it to UTF-8 bytes.
  factory Value.fromString(String str) {
    return Value(Uint8List.fromList(utf8.encode(str)));
  }

  /// Creates a Value from raw bytes.
  factory Value.fromBytes(Uint8List bytes) {
    return Value(bytes);
  }

  /// The raw byte content of this value.
  final Uint8List bytes;

  @override
  String toString() {
    return utf8.decode(bytes);
  }
}

