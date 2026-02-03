abstract class INodeImplementation {
  Future<void> start(Map<String, dynamic> config);
  Future<void> stop();
  Future<String?> addFile(dynamic content);
  Future<dynamic> cat(String cid);
  String get peerId;
  bool get isOnline;
  Future<List<String>> getPeers();
  Future<void> connect(String multiaddr);
  Future<void> disconnect(String peerIdOrAddr);
  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);
  Future<void> publish(String topic, String message);
  Stream<dynamic> get pubsubEvents;
  Stream<Map<String, dynamic>> get bandwidthMetrics;
  Future<List<String>> getAddresses();
  void setGatewayMode(int modeIndex, String? customUrl);
  Future<void> pin(String cid);
  Future<bool> unpin(String cid);
  Future<List<String>> getPinnedCids();
  Future<List<Map<String, dynamic>>> ls(String cid);
}
