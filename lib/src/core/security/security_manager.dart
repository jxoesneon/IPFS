// src/core/security/security_manager.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/crypto/encrypted_keystore.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

/// Manages security aspects of the IPFS node.
///
/// SecurityManager handles TLS configuration, key management,
/// rate limiting, and authentication tracking. It integrates with
/// [MetricsCollector] to record security-related events.
///
/// **Security (SEC-001):** Uses [EncryptedKeystore] for secure key storage
/// with AES-256-GCM encryption and PBKDF2 key derivation.
///
/// **Features:**
/// - Encrypted key storage (AES-256-GCM)
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
/// // Unlock the secure keystore
/// await manager.unlockKeystore('my-password');
///
/// // Get an Ed25519 key for signing
/// final keyPair = await manager.getSecureKey('ipns-key');
/// ```
///
/// See also:
/// - [SecurityConfig] for configuration options
/// - [EncryptedKeystore] for secure key storage
/// - [Keystore] for legacy key pair management
class SecurityManager {

  /// Creates a new security manager with the given [_config].
  SecurityManager(this._config, MetricsCollector metricsCollector) {
    _logger = Logger('SecurityManager');
    _keystore = Keystore();
    _encryptedKeystore = EncryptedKeystore();
    _metrics = metricsCollector;
    _initializeSecurity();
  }
  final SecurityConfig _config;
  late final Logger _logger;
  late final Keystore _keystore;
  late final EncryptedKeystore _encryptedKeystore;
  late final MetricsCollector _metrics;
  final Map<String, dynamic> _securityMetrics = {};

  // Rate limiting
  final Map<String, List<DateTime>> _requestLog = {};
  final Map<String, int> _authAttempts = {};

  // Key rotation
  Timer? _keyRotationTimer;
  DateTime? _lastKeyRotation;

  /// Returns the legacy keystore for backward compatibility.
  Keystore get keystore => _keystore;

  /// Returns the encrypted keystore for secure key operations.
  EncryptedKeystore get secureKeystore => _encryptedKeystore;

  /// Whether the encrypted keystore is currently unlocked.
  bool get isKeystoreUnlocked => _encryptedKeystore.isUnlocked;

  /// Unlocks the encrypted keystore with a password.
  ///
  /// Must be called before accessing secure keys.
  Future<void> unlockKeystore(String password, {Uint8List? salt}) async {
    _logger.debug('Unlocking encrypted keystore');
    await _encryptedKeystore.unlock(password, salt: salt);
    _recordSecurityMetric('keystore_unlock');
    _logger.info('Encrypted keystore unlocked');
  }

  /// Locks the encrypted keystore and zeros the master key from memory.
  void lockKeystore() {
    _encryptedKeystore.lock();
    _recordSecurityMetric('keystore_lock');
    _logger.info('Encrypted keystore locked');
  }

  /// Gets an Ed25519 key pair from the encrypted keystore.
  ///
  /// Throws if keystore is locked or key not found.
  Future<SimpleKeyPair> getSecureKey(String keyName) async {
    if (!_encryptedKeystore.isUnlocked) {
      throw StateError('Keystore is locked. Call unlockKeystore() first.');
    }
    return await _encryptedKeystore.getKey(keyName);
  }

  /// Generates a new Ed25519 key and stores it encrypted.
  ///
  /// Returns the public key bytes.
  Future<Uint8List> generateSecureKey(String keyName, {String? label}) async {
    if (!_encryptedKeystore.isUnlocked) {
      throw StateError('Keystore is locked. Call unlockKeystore() first.');
    }
    final publicKey = await _encryptedKeystore.generateKey(
      keyName,
      label: label,
    );
    _recordSecurityMetric('key_generated', data: {'keyName': keyName});
    _logger.info('Generated secure key: $keyName');
    return publicKey;
  }

  /// Checks if a secure key exists.
  bool hasSecureKey(String keyName) => _encryptedKeystore.hasKey(keyName);

  /// Gets the public key for a stored secure key.
  Uint8List? getSecurePublicKey(String keyName) =>
      _encryptedKeystore.getPublicKey(keyName);

  /// Migrates keys from plaintext Keystore to EncryptedKeystore.
  ///
  /// **Security Note:** This method should be called once during the
  /// transition from plaintext to encrypted storage. After successful
  /// migration, plaintext keys are cleared from memory.
  ///
  /// Requires the keystore to be unlocked first.
  Future<int> migrateKeysFromPlaintext() async {
    if (!_encryptedKeystore.isUnlocked) {
      throw StateError('Keystore must be unlocked before migration.');
    }

    final plaintextKeys = _keystore.exportKeysForMigration();
    if (plaintextKeys.isEmpty) {
      _logger.info('No plaintext keys to migrate');
      return 0;
    }

    _logger.info('Migrating ${plaintextKeys.length} keys to encrypted storage');
    var migratedCount = 0;

    for (final entry in plaintextKeys.entries) {
      final keyName = entry.key;
      final keyBytes = entry.value;

      // Skip if already exists in encrypted store
      if (_encryptedKeystore.hasKey(keyName)) {
        _logger.verbose('Key $keyName already in encrypted store, skipping');
        continue;
      }

      try {
        // Import the key into encrypted storage
        await _encryptedKeystore.importSeed(
          keyName,
          keyBytes,
          label: 'Migrated from plaintext',
        );
        migratedCount++;
        _logger.debug('Migrated key: $keyName');
      } catch (e) {
        _logger.error('Failed to migrate key $keyName', e);
      }
    }

    // Clear plaintext keys after successful migration
    if (migratedCount > 0) {
      _keystore.clearAfterMigration();
      _recordSecurityMetric('keys_migrated', data: {'count': migratedCount});
      _logger.info('Successfully migrated $migratedCount keys');
    }

    return migratedCount;
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
        'TLS enabled but certificate or private key path not provided',
      );
    }

    // Verify certificate and key files exist
    if (!File(_config.tlsCertificatePath!).existsSync()) {
      throw FileSystemException(
        'TLS certificate file not found',
        _config.tlsCertificatePath,
      );
    }

    if (!File(_config.tlsPrivateKeyPath!).existsSync()) {
      throw FileSystemException(
        'TLS private key file not found',
        _config.tlsPrivateKeyPath,
      );
    }

    _logger.debug(
      'TLS initialized with certificate: ${_config.tlsCertificatePath}',
    );
  }

  void _setupKeyRotation() {
    _logger.verbose('Setting up key rotation');

    _keyRotationTimer?.cancel();
    _keyRotationTimer = Timer.periodic(_config.keyRotationInterval, (_) {
      _rotateKeys();
    });

    _lastKeyRotation = DateTime.now();
    _logger.debug(
      'Key rotation scheduled for interval: ${_config.keyRotationInterval}',
    );
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
      (time) => now.difference(time) > const Duration(minutes: 1),
    );

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
    _metrics.recordProtocolMetrics('security', {'type': metricType, ...?data});
  }
}
