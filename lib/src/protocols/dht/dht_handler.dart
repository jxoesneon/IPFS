// Change from DHTHandler to IDHTHandler to indicate it's an interface
abstract class IDHTHandler {
  // Required operations
  Future<List<PeerInfo>> findPeer(PeerID id);
  Future<void> provide(CID cid);
  Future<List<PeerInfo>> findProviders(CID cid);
  Future<void> putValue(Key key, Value value);
  Future<Value> getValue(Key key);

  // Required behaviors
  Future<void> handleRoutingTableUpdate(PeerInfo peer);
  Future<void> handleProvideRequest(CID cid, PeerID provider);
}
