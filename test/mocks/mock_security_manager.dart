// test/mocks/mock_security_manager.dart
import 'dart:async';
import 'package:dart_ipfs/src/utils/private_key.dart';

/// Mock implementation of key management for testing.
///
/// Provides simple key storage and retrieval without actual
/// cryptographic operations or SecurityManager dependencies.
/// Perfect for testing IPNS and other components that require key management.
///
/// This is a standalone mock, not extending SecurityManager to avoid
/// complex constructor requirements (SecurityConfig, MetricsCollector).
class MockSecurityManager {
  final Map<String, IPFSPrivateKey> _keys = {};
  final List<String> _calls = [];

  /// Retrieves a private key by its name
  Future<IPFSPrivateKey?> getPrivateKey(String keyName) async {
    _recordCall('getPrivateKey:$keyName');
    return _keys[keyName];
  }

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

  /// Gets mock security status
  Future<Map<String, dynamic>> getStatus() async {
    _recordCall('getStatus');
    return {
      'keyCount': _keys.length,
      'keyNames': _keys.keys.toList(),
    };
  }

  // ===== Test Helper Methods =====

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
