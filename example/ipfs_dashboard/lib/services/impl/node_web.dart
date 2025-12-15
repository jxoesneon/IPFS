import 'dart:async';
import 'dart:math';
import 'node_interface.dart';

class NodeImplementation implements INodeImplementation {
  bool _isOnline = false;
  String _mockPeerId = '';
  final Map<String, dynamic> _mockStore = {};

  @override
  bool get isOnline => _isOnline;

  @override
  String get peerId => _mockPeerId;

  @override
  Stream<Map<String, dynamic>> get bandwidthMetrics {
    // Generate fake metrics every second
    return Stream.periodic(const Duration(seconds: 1), (i) {
      return {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'totalSent': (i * 1024) + Random().nextInt(500),
        'totalReceived': (i * 2048) + Random().nextInt(1000),
        'peers': 3,
      };
    }).asBroadcastStream();
  }

  @override
  Future<List<String>> getAddresses() async {
    return ['/ip4/127.0.0.1/tcp/4001', '/ip4/192.168.1.5/tcp/4001'];
  }

  @override
  Future<void> start(Map<String, dynamic> config) async {
    // Simulate startup delay
    await Future.delayed(const Duration(milliseconds: 1500));
    _mockPeerId =
        'QmWebMock${Random().nextInt(99999)}Node${Random().nextInt(999)}';
    _isOnline = true;
  }

  @override
  Future<void> stop() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isOnline = false;
  }

  @override
  Future<String?> addFile(dynamic content) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final cid = 'QmHash${content.hashCode}MockData';
    _mockStore[cid] = content;
    return cid;
  }

  @override
  Future<dynamic> cat(String cid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockStore[cid];
  }

  @override
  Future<List<String>> getPeers() async {
    // Return fake peers for demo
    if (!_isOnline) return [];
    return [
      'QmPeerABC123MockPeerOne',
      'QmPeerXYZ789MockPeerTwo',
      'QmPeerDEF456MockPeerThree',
    ];
  }

  @override
  Future<void> connect(String multiaddr) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> disconnect(String peerIdOrAddr) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  final _mockPubSubController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<void> subscribe(String topic) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> unsubscribe(String topic) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> publish(String topic, String message) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Echo back locally
    _mockPubSubController.add({
      'topic': topic,
      'from': _mockPeerId,
      'content': message,
    });
  }

  @override
  Stream<dynamic> get pubsubEvents => _mockPubSubController.stream;
  @override
  void setGatewayMode(int modeIndex, String? customUrl) {}

  @override
  Future<void> pin(String cid) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<bool> unpin(String cid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  @override
  Future<List<String>> getPinnedCids() async {
    return _mockStore.keys.toList();
  }

  @override
  Future<List<Map<String, dynamic>>> ls(String cid) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Hacky mock: if we have the content in store, assume it's just a file (no links)
    // or return some dummy links
    return [
      {'name': 'link1', 'cid': 'QmMockChild1', 'size': 123},
      {'name': 'link2', 'cid': 'QmMockChild2', 'size': 456},
    ];
  }
}

INodeImplementation getImplementation() => NodeImplementation();
