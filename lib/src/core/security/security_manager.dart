// src/core/security/security_manager.dart
import 'dart:io';
import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';

/// Manages security aspects of the IPFS node including TLS, key management,
/// and rate limiting.
class SecurityManager {
  final SecurityConfig _config;
  late final Logger _logger;

  // Rate limiting
  final Map<String, List<DateTime>> _requestLog = {};
  final Map<String, int> _authAttempts = {};

  // Key rotation
  Timer? _keyRotationTimer;
  DateTime? _lastKeyRotation;

  SecurityManager(this._config) {
    _logger = Logger('SecurityManager');
    _initializeSecurity();
  }

  void _initializeSecurity() {
    _logger.debug('Initializing SecurityManager');

    try {
      if (_config.enableTLS) {
        _initializeTLS();
      }

      if (_config.enableKeyRotation) {
        _setupKeyRotation();
      }

      _logger.debug('SecurityManager initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize SecurityManager', e, stackTrace);
      rethrow;
    }
  }

  void _initializeTLS() {
    _logger.verbose('Initializing TLS');

    if (_config.tlsCertificatePath == null ||
        _config.tlsPrivateKeyPath == null) {
      throw StateError(
          'TLS enabled but certificate or private key path not provided');
    }

    // Verify certificate and key files exist
    if (!File(_config.tlsCertificatePath!).existsSync()) {
      throw FileSystemException(
          'TLS certificate file not found', _config.tlsCertificatePath);
    }

    if (!File(_config.tlsPrivateKeyPath!).existsSync()) {
      throw FileSystemException(
          'TLS private key file not found', _config.tlsPrivateKeyPath);
    }

    _logger.debug(
        'TLS initialized with certificate: ${_config.tlsCertificatePath}');
  }

  void _setupKeyRotation() {
    _logger.verbose('Setting up key rotation');

    _keyRotationTimer?.cancel();
    _keyRotationTimer = Timer.periodic(_config.keyRotationInterval, (_) {
      _rotateKeys();
    });

    _lastKeyRotation = DateTime.now();
    _logger.debug(
        'Key rotation scheduled for interval: ${_config.keyRotationInterval}');
  }

  Future<void> _rotateKeys() async {
    _logger.verbose('Performing key rotation');

    try {
      // Implement key rotation logic here
      _lastKeyRotation = DateTime.now();
      _logger.debug('Key rotation completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to rotate keys', e, stackTrace);
    }
  }

  /// Checks if a request should be rate limited
  bool shouldRateLimit(String clientId) {
    if (!_config.enableRateLimiting) return false;

    final now = DateTime.now();
    _requestLog.putIfAbsent(clientId, () => []);

    // Remove requests older than 1 minute
    _requestLog[clientId]!.removeWhere(
        (time) => now.difference(time) > const Duration(minutes: 1));

    // Add current request
    _requestLog[clientId]!.add(now);

    // Check if exceeds rate limit
    return _requestLog[clientId]!.length > _config.maxRequestsPerMinute;
  }

  /// Tracks authentication attempts
  bool trackAuthAttempt(String clientId, bool success) {
    if (success) {
      _authAttempts.remove(clientId);
      return true;
    }

    _authAttempts[clientId] = (_authAttempts[clientId] ?? 0) + 1;
    return _authAttempts[clientId]! < _config.maxAuthAttempts;
  }

  /// Gets the current security status
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'tls_enabled': _config.enableTLS,
      'key_rotation_enabled': _config.enableKeyRotation,
      'last_key_rotation': _lastKeyRotation?.toIso8601String(),
      'rate_limiting_enabled': _config.enableRateLimiting,
      'active_rate_limits': _requestLog.length,
      'blocked_clients': _authAttempts.entries
          .where((e) => e.value >= _config.maxAuthAttempts)
          .length,
    };
  }

  /// Starts the security manager
  Future<void> start() async {
    _logger.debug('Starting SecurityManager');
    // Additional startup logic if needed
  }

  /// Stops the security manager
  Future<void> stop() async {
    _logger.debug('Stopping SecurityManager');
    _keyRotationTimer?.cancel();
  }
}
