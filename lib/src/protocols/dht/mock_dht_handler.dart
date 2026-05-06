import 'dart:async';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';

/// A mock DHT handler for environments where DHT is not available (e.g. Web).
class MockDHTHandler implements IDHTHandler {
  final Map<String, Value> _storage = {};

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    _storage.clear();
  }

  @override
  Future<List<V_PeerInfo>> findPeer(PeerId id) async {
    return [];
  }

  @override
  Future<void> provide(CID cid) async {}

  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async {
    return [];
  }

  @override
  Future<void> putValue(Key key, Value value) async {
    _storage[key.toString()] = value;
  }

  @override
  Future<Value> getValue(Key key) async {
    final value = _storage[key.toString()];
    if (value == null) {
      throw Exception('Value not found for key: ${key.toString()}');
    }
    return value;
  }

  @override
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer) async {}

  @override
  Future<void> handleProvideRequest(CID cid, PeerId provider) async {}
}
