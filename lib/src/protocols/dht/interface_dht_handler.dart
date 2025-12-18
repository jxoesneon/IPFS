import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart'
    show V_PeerInfo;
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;

// Change from DHTHandler to IDHTHandler to indicate it's an interface
abstract class IDHTHandler {
  // Required operations
  Future<List<V_PeerInfo>> findPeer(p2p.PeerId id);
  Future<void> provide(CID cid);
  Future<List<V_PeerInfo>> findProviders(CID cid);
  Future<void> putValue(Key key, Value value);
  Future<Value> getValue(Key key);

  // Required behaviors
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer);
  Future<void> handleProvideRequest(CID cid, p2p.PeerId provider);

  // Lifecycle
  Future<void> start() async {}
  Future<void> stop() async {}
}

/// Represents a key in the DHT
class Key {

  const Key(this.bytes);

  /// Creates a Key from a string by encoding it to UTF-8 bytes
  factory Key.fromString(String str) {
    return Key(Uint8List.fromList(utf8.encode(str)));
  }

  /// Creates a Key from raw bytes
  factory Key.fromBytes(Uint8List bytes) {
    return Key(bytes);
  }
  final Uint8List bytes;

  @override
  String toString() {
    return Base58().encode(bytes);
  }
}

/// Represents a value stored in the DHT
class Value {

  const Value(this.bytes);

  /// Creates a Value from a string by encoding it to UTF-8 bytes
  factory Value.fromString(String str) {
    return Value(Uint8List.fromList(utf8.encode(str)));
  }

  /// Creates a Value from raw bytes
  factory Value.fromBytes(Uint8List bytes) {
    return Value(bytes);
  }
  final Uint8List bytes;

  @override
  String toString() {
    return utf8.decode(bytes);
  }
}
