// test/mocks/mock_security_manager.dart
import 'dart:async';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';

/// Mock implementation of key management for testing.
class MockSecurityManager implements SecurityManager {
  final Map<String, IPFSPrivateKey> _keys = {};
  final List<String> _calls = [];

  // Implement SecurityManager interface members
  @override
  Keystore get keystore => Keystore(); // Return a dummy or mock keystore if needed

  @override
  Future<IPFSPrivateKey?> getPrivateKey(String keyName) async {
    _recordCall('getPrivateKey:$keyName');
    return _keys[keyName];
  }

  @override
  Future<void> start() async {
    _recordCall('start');
  }

  @override
  Future<void> stop() async {
    _recordCall('stop');
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    _recordCall('getStatus');
    return {'keyCount': _keys.length, 'keyNames': _keys.keys.toList()};
  }

  @override
  bool shouldRateLimit(String clientId) => false;

  @override
  bool trackAuthAttempt(String clientId, bool success) => true;

  // Test helper methods (not part of SecurityManager interface)

  /// Stores a private key with the given name
  Future<void> storePrivateKey(String keyName, IPFSPrivateKey key) async {
    _recordCall('storePrivateKey:$keyName');
    _keys[keyName] = key;
  }

  /// Checks if a private key exists
  Future<bool> hasPrivateKey(String keyName) async {
    _recordCall('hasPrivateKey:$keyName');
    return _keys.containsKey(keyName);
  }

  /// Lists all stored key names
  Future<List<String>> listKeys() async {
    _recordCall('listKeys');
    return _keys.keys.toList();
  }

  /// Deletes a private key
  Future<void> deletePrivateKey(String keyName) async {
    _recordCall('deletePrivateKey:$keyName');
    _keys.remove(keyName);
  }

  /// Set up a key for testing
  void setupKey(String keyName, IPFSPrivateKey key) {
    _keys[keyName] = key;
  }

  /// Check if a key was requested
  bool wasKeyRequested(String keyName) {
    return _calls.any((c) => c.contains('getPrivateKey:$keyName'));
  }

  /// Check if a method was called
  bool wasCalled(String method) {
    return _calls.any((c) => c.startsWith(method));
  }

  /// Get all recorded calls
  List<String> getCalls() => List.unmodifiable(_calls);

  /// Get call count for a specific method
  int getCallCount(String method) {
    return _calls.where((c) => c.startsWith(method)).length;
  }

  /// Reset all state
  void reset() {
    _keys.clear();
    _calls.clear();
  }

  void _recordCall(String call) {
    _calls.add(call);
  }
}
