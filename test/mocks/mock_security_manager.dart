// test/mocks/mock_security_manager.dart
import 'dart:async';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

/// Mock implementation of SecurityManager for testing.
///
/// Provides simple key storage and retrieval without actual
/// cryptographic operations. Perfect for testing IPNS and other
/// components that require key management.
class MockSecurityManager extends SecurityManager {
  final Map<String, PrivateKey> _keys = {};
  final List<String> _calls = [];

  MockSecurityManager() : super(null);

  @override
  Future<PrivateKey?> getPrivateKey(String keyName) async {
    _recordCall('getPrivateKey:$keyName');
    return _keys[keyName];
  }

  @override
  Future<void> storePrivateKey(String keyName, PrivateKey key) async {
    _recordCall('storePrivateKey:$keyName');
    _keys[keyName] = key;
  }

  @override
  Future<bool> hasPrivateKey(String keyName) async {
    _recordCall('hasPrivateKey:$keyName');
    return _keys.containsKey(keyName);
  }

  @override
  Future<List<String>> listKeys() async {
    _recordCall('listKeys');
    return _keys.keys.toList();
  }

  @override
  Future<void> deletePrivateKey(String keyName) async {
    _recordCall('deletePrivateKey:$keyName');
    _keys.remove(keyName);
  }

  // =====  Test Configuration Methods =====

  /// Set up a key for testing
  void setupKey(String keyName, PrivateKey key) {
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

  /// Reset all state
  void reset() {
    _keys.clear();
    _calls.clear();
  }

  void _recordCall(String call) {
    _calls.add(call);
  }
}
