// test/mocks/mock_dht_handler.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart'
    show V_PeerInfo;
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:p2plib/p2plib.dart' as p2p;

/// Mock implementation of IDHTHandler for testing.
///
/// Provides configurable behavior for DHT operations:
/// - Storage (putValue/getValue)
/// - Provider records (provide/findProviders)
/// - Peer discovery (findPeer)
/// - Error simulation
/// - Call tracking for verification
class MockDHTHandler implements IDHTHandler {
  final Map<String, Value> _storage = {};
  final Map<String, List<V_PeerInfo>> _providers = {};
  final Map<String, List<V_PeerInfo>> _peers = {};
  final List<String> _calls = [];

  bool _isRunning = false;

  // Configurable behaviors
  Duration? simulatedDelay;
  Exception? nextError;
  bool throwOnNextCall = false;

  // ===== IDHTHandler Interface Implementation =====

  @override
  Future<void> putValue(Key key, Value value) async {
    _checkAndThrow('putValue');
    _ensureRunning();
    await _simulateDelay();

    _storage[key.toString()] = value;
    _recordCall('putValue:${key.toString()}');
  }

  @override
  Future<Value> getValue(Key key) async {
    _checkAndThrow('getValue');
    _ensureRunning();
    await _simulateDelay();

    _recordCall('getValue:${key.toString()}');

    if (!_storage.containsKey(key.toString())) {
      throw Exception('Key not found: ${key.toString()}');
    }

    return _storage[key.toString()]!;
  }

  @override
  Future<void> provide(CID cid) async {
    _checkAndThrow('provide');
    _ensureRunning();
    await _simulateDelay();

    _recordCall('provide:${cid.toString()}');

    // Store as provider
    _providers.putIfAbsent(cid.toString(), () => []).add(_createMockPeerInfo());
  }

  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async {
    _checkAndThrow('findProviders');
    _ensureRunning();
    await _simulateDelay();

    _recordCall('findProviders:${cid.toString()}');
    return _providers[cid.toString()] ?? [];
  }

  @override
  Future<List<V_PeerInfo>> findPeer(p2p.PeerId id) async {
    _checkAndThrow('findPeer');
    _ensureRunning();
    await _simulateDelay();

    _recordCall('findPeer:${id.toString()}');
    return _peers[id.toString()] ?? [];
  }

  @override
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer) async {
    _checkAndThrow('handleRoutingTableUpdate');
    await _simulateDelay();

    _recordCall('handleRoutingTableUpdate:${peer.peerId}');
    // Just track the call
  }

  @override
  Future<void> handleProvideRequest(CID cid, p2p.PeerId provider) async {
    _checkAndThrow('handleProvideRequest');
    await _simulateDelay();

    _recordCall(
      'handleProvideRequest:${cid.toString()}:${provider.toString()}',
    );
    // Just track the call
  }

  // ===== Test Configuration Methods =====

  /// Start the mock DHT (for lifecycle testing)
  @override
  Future<void> start() async {
    _checkAndThrow('start');
    await _simulateDelay();
    _isRunning = true;
    _recordCall('start');
  }

  /// Stop the mock DHT (for lifecycle testing)
  @override
  Future<void> stop() async {
    _checkAndThrow('stop');
    await _simulateDelay();
    _isRunning = false;
    _recordCall('stop');
  }

  /// Get mock status (for testing)
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'storage_size': _storage.length,
      'providers_count': _providers.length,
    };
  }

  /// Set up a stored value for testing
  void setupValue(Key key, Value value) {
    _storage[key.toString()] = value;
  }

  /// Set up providers for a CID
  void setupProviders(CID cid, List<V_PeerInfo> providers) {
    _providers[cid.toString()] = List.from(providers);
  }

  /// Set up peer information
  void setupPeerInfo(p2p.PeerId peerId, List<V_PeerInfo> info) {
    _peers[peerId.toString()] = info;
  }

  /// Configure simulated delay for all operations
  void setSimulatedDelay(Duration delay) {
    simulatedDelay = delay;
  }

  /// Make the next call throw an error
  void throwOnNext(Exception error) {
    nextError = error;
    throwOnNextCall = true;
  }

  /// Check if a specific method was called
  bool wasCalled(String method) {
    return _calls.any((c) => c.startsWith(method));
  }

  /// Get all recorded calls
  List<String> getCalls() => List.unmodifiable(_calls);

  /// Get call count for a specific method
  int getCallCount(String method) {
    return _calls.where((c) => c.startsWith(method)).length;
  }

  /// Check if a value exists in storage
  bool hasStoredValue(Key key) {
    return _storage.containsKey(key.toString());
  }

  /// Get a stored value (test helper)
  Value? getStoredValue(Key key) {
    return _storage[key.toString()];
  }

  /// Reset all state and configuration
  void reset() {
    _storage.clear();
    _providers.clear();
    _peers.clear();
    _calls.clear();
    _isRunning = false;
    simulatedDelay = null;
    nextError = null;
    throwOnNextCall = false;
  }

  // ===== Private Helpers =====

  void _recordCall(String call) {
    _calls.add(call);
  }

  void _ensureRunning() {
    if (!_isRunning) {
      throw StateError('DHT handler is not running');
    }
  }

  Future<void> _simulateDelay() async {
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }
  }

  void _checkAndThrow(String method) {
    if (throwOnNextCall && nextError != null) {
      throwOnNextCall = false;
      final error = nextError!;
      nextError = null;
      throw error;
    }
  }

  V_PeerInfo _createMockPeerInfo() {
    return V_PeerInfo()
      ..peerId = [1, 2, 3, 4, 5]; // List<int> for peer ID bytes
    // Note: addresses field also uses List<int>, skipping for mock simplicity
  }
}
