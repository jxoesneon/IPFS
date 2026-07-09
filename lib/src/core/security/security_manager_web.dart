import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import '../config/security_config.dart';
import '../crypto/encrypted_keystore.dart';
import '../metrics/metrics_collector.dart';

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

  final SecurityConfig _config;
  final MetricsCollector _metrics;

  late final EncryptedKeystore _encryptedKeystore;

  final Map<String, dynamic> _securityMetrics = {};

  // Rate limiting
  final Map<String, List<DateTime>> _requestLog = {};
  final Map<String, int> _authAttempts = {};

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
  bool shouldRateLimit(String clientId) {
    if (!_config.enableRateLimiting) return false;

    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(minutes: 1));

    _requestLog.putIfAbsent(clientId, () => []);
    final clientLog = _requestLog[clientId]!;

    // Clean up old entries
    clientLog.removeWhere((dt) => dt.isBefore(windowStart));

    if (clientLog.length >= _config.maxRequestsPerMinute) {
      _recordSecurityMetric('rate_limit', data: {'clientId': clientId});
      return true;
    }

    clientLog.add(now);
    return false;
  }

  @override
  bool trackAuthAttempt(String clientId, bool success) {
    if (success) {
      _authAttempts.remove(clientId);
      return true;
    }

    final attempts = (_authAttempts[clientId] ?? 0) + 1;
    _authAttempts[clientId] = attempts;

    if (attempts >= _config.maxAuthAttempts) {
      _recordSecurityMetric('auth_blocked', data: {'clientId': clientId});
      return false;
    }

    return true;
  }

  /// Records a security metric of the given [type].
  void _recordSecurityMetric(String type, {Map<String, dynamic>? data}) {
    final metric = {
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      ...?data,
    };

    _securityMetrics[type] = metric;
    _metrics.recordProtocolMetrics('security', metric);
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'platform': 'web',
      'keystore_unlocked': isKeystoreUnlocked,
      'active_rate_limits': _requestLog.length,
      'blocked_clients': _authAttempts.entries
          .where((e) => e.value >= _config.maxAuthAttempts)
          .length,
      'metrics': _securityMetrics,
    };
  }
}
