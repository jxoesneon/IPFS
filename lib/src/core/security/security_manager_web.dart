import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/crypto/encrypted_keystore.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';

import 'security_manager_interface.dart';

/// Web-compatible implementation of SecurityManager.
///
/// This implementation relies on [EncryptedKeystore] for key management
/// but skips file-system based TLS initialization.
class SecurityManagerWeb implements ISecurityManager {
  /// Creates a new security manager for web.
  SecurityManagerWeb(this._config, this._metrics) {
    _encryptedKeystore = EncryptedKeystore();
  }

  // ignore: unused_field
  final SecurityConfig _config;
  // ignore: unused_field
  final MetricsCollector _metrics;

  late final EncryptedKeystore _encryptedKeystore;

  @override
  bool get isKeystoreUnlocked => _encryptedKeystore.isUnlocked;

  @override
  Future<void> unlockKeystore(String password, {Uint8List? salt}) async {
    if (password.isEmpty) {
      throw ArgumentError('Keystore password cannot be empty');
    }
    await _encryptedKeystore.unlock(password, salt: salt);
  }

  @override
  void lockKeystore() {
    _encryptedKeystore.lock();
  }

  @override
  Future<SimpleKeyPair> getSecureKey(String keyName) async {
    if (keyName.isEmpty) {
      throw ArgumentError('Key name cannot be empty');
    }
    if (!_encryptedKeystore.isUnlocked) {
      throw StateError('Keystore is locked. Call unlockKeystore() first.');
    }
    return _encryptedKeystore.getKey(keyName);
  }

  @override
  Future<Uint8List> generateSecureKey(String keyName, {String? label}) async {
    if (keyName.isEmpty) {
      throw ArgumentError('Key name cannot be empty');
    }
    if (!_encryptedKeystore.isUnlocked) {
      throw StateError('Keystore is locked. Call unlockKeystore() first.');
    }
    return _encryptedKeystore.generateKey(keyName, label: label);
  }

  @override
  bool hasSecureKey(String keyName) => _encryptedKeystore.hasKey(keyName);

  @override
  Uint8List? getSecurePublicKey(String keyName) =>
      _encryptedKeystore.getPublicKey(keyName);

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    lockKeystore();
  }

  @override
  bool shouldRateLimit(String clientId) => false;

  @override
  bool trackAuthAttempt(String clientId, bool success) => true;

  @override
  Future<Map<String, dynamic>> getStatus() async {
    return {'keystore_unlocked': isKeystoreUnlocked, 'platform': 'web'};
  }
}
