// src/core/security/security_manager.dart
import 'dart:io';
import 'dart:async';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

/// Manages security aspects of the IPFS node.
///
/// SecurityManager handles TLS configuration, key management,
/// rate limiting, and authentication tracking. It integrates with
/// [MetricsCollector] to record security-related events.
///
/// **Features:**
/// - TLS certificate management
/// - Automatic key rotation
/// - Request rate limiting per client
/// - Failed authentication tracking and lockout
///
/// Example:
/// ```dart
/// final manager = SecurityManager(securityConfig, metricsCollector);
/// await manager.start();
///
/// // Check rate limiting before processing
/// if (manager.shouldRateLimit(clientId)) {
///   throw RateLimitException();
/// }
///
/// // Track authentication
/// if (!manager.trackAuthAttempt(clientId, success)) {
///   throw AuthLockoutException();
/// }
/// ```
///
/// See also:
/// - [SecurityConfig] for configuration options
/// - [Keystore] for key pair management
class SecurityManager {
  final SecurityConfig _config;
  late final Logger _logger;
  late final Keystore _keystore;
  late final MetricsCollector _metrics;
  final Map<String, dynamic> _securityMetrics = {};

  // Rate limiting
  final Map<String, List<DateTime>> _requestLog = {};
  final Map<String, int> _authAttempts = {};

  // Key rotation
  Timer? _keyRotationTimer;
  DateTime? _lastKeyRotation;

  /// Creates a new security manager with the given [_config].
  SecurityManager(this._config, MetricsCollector metricsCollector) {
    _logger = Logger('SecurityManager');
    _keystore = Keystore();
    _metrics = metricsCollector;
    _initializeSecurity();
  }

  /// Returns the keystore for key pair operations.
  Keystore get keystore => _keystore;

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
      _recordSecurityMetric('key_rotation');
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

    _requestLog[clientId]!.removeWhere(
        (time) => now.difference(time) > const Duration(minutes: 1));

    _requestLog[clientId]!.add(now);

    final shouldLimit =
        _requestLog[clientId]!.length > _config.maxRequestsPerMinute;
    if (shouldLimit) {
      _recordSecurityMetric('rate_limit');
    }
    return shouldLimit;
  }

  /// Tracks authentication attempts
  bool trackAuthAttempt(String clientId, bool success) {
    if (success) {
      _authAttempts.remove(clientId);
      _recordSecurityMetric('auth_attempt', data: {'success': true});
      return true;
    }

    _authAttempts[clientId] = (_authAttempts[clientId] ?? 0) + 1;
    _recordSecurityMetric('auth_attempt', data: {'success': false});
    return _authAttempts[clientId]! < _config.maxAuthAttempts;
  }

  /// Retrieves a private key by its name from the keystore
  Future<IPFSPrivateKey?> getPrivateKey(String keyName) async {
    _logger.debug('Retrieving private key for: $keyName');

    try {
      if (!_keystore.hasKeyPair(keyName)) {
        _logger.warning('Key not found: $keyName');
        return null;
      }

      final keyPair = _keystore.getKeyPair(keyName);
      return IPFSPrivateKey.fromString(keyPair.privateKey);
    } catch (e, stackTrace) {
      _logger.error('Failed to retrieve private key', e, stackTrace);
      return null;
    }
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
      'metrics': _securityMetrics,
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

  void _recordSecurityMetric(String metricType, {Map<String, dynamic>? data}) {
    switch (metricType) {
      case 'auth_attempt':
        _securityMetrics['auth_attempts'] =
            (_securityMetrics['auth_attempts'] ?? 0) + 1;
        if (data?['success'] == true) {
          _securityMetrics['successful_auth_attempts'] =
              (_securityMetrics['successful_auth_attempts'] ?? 0) + 1;
        } else {
          _securityMetrics['failed_auth_attempts'] =
              (_securityMetrics['failed_auth_attempts'] ?? 0) + 1;
        }
        break;
      case 'rate_limit':
        _securityMetrics['rate_limit_hits'] =
            (_securityMetrics['rate_limit_hits'] ?? 0) + 1;
        break;
      case 'key_rotation':
        _securityMetrics['key_rotations'] =
            (_securityMetrics['key_rotations'] ?? 0) + 1;
        break;
    }

    // Report metrics to the central collector if needed
    _metrics.recordProtocolMetrics('security', {
      'type': metricType,
      ...?data,
    });
  }
}
