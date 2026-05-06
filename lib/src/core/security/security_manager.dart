// src/core/security/security_manager.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/crypto/encrypted_keystore.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

import 'security_manager_interface.dart';

/// Manages security aspects of the IPFS node.
class SecurityManager implements ISecurityManager {
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

  /// Whether the encrypted keystore is currently unlocked.
  @override
  bool get isKeystoreUnlocked => _encryptedKeystore.isUnlocked;

  /// Unlocks the encrypted keystore with a [password].
  @override
  Future<void> unlockKeystore(String password, {Uint8List? salt}) async {
    if (password.isEmpty) {
      throw ArgumentError('Keystore password cannot be empty');
    }
    _logger.debug('Unlocking encrypted keystore');
    try {
      await _encryptedKeystore.unlock(password, salt: salt);
      _recordSecurityMetric('keystore_unlock');
      _logger.info('Encrypted keystore unlocked');
    } catch (e, stackTrace) {
      _logger.error('Failed to unlock keystore', e, stackTrace);
      rethrow;
    }
  }

  /// Locks the encrypted keystore and zeros the master key from memory.
  @override
  void lockKeystore() {
    _encryptedKeystore.lock();
    _recordSecurityMetric('keystore_lock');
    _logger.info('Encrypted keystore locked');
  }

  /// Gets an Ed25519 key pair from the encrypted keystore by [keyName].
  @override
  Future<SimpleKeyPair> getSecureKey(String keyName) async {
    if (keyName.isEmpty) {
      throw ArgumentError('Key name cannot be empty');
    }
    if (!_encryptedKeystore.isUnlocked) {
      throw StateError('Keystore is locked. Call unlockKeystore() first.');
    }
    return await _encryptedKeystore.getKey(keyName);
  }

  /// Generates a new Ed25519 key and stores it encrypted.
  @override
  Future<Uint8List> generateSecureKey(String keyName, {String? label}) async {
    if (keyName.isEmpty) {
      throw ArgumentError('Key name cannot be empty');
    }
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

  /// Checks if a secure key with [keyName] exists.
  @override
  bool hasSecureKey(String keyName) => _encryptedKeystore.hasKey(keyName);

  /// Gets the public key for a stored secure key.
  @override
  Uint8List? getSecurePublicKey(String keyName) =>
      _encryptedKeystore.getPublicKey(keyName);

  /// Migrates keys from plaintext Keystore to EncryptedKeystore.
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

      if (_encryptedKeystore.hasKey(keyName)) {
        continue;
      }

      try {
        await _encryptedKeystore.importSeed(
          keyName,
          keyBytes,
          label: 'Migrated from plaintext',
        );
        migratedCount++;
      } catch (e) {
        _logger.error('Failed to migrate key $keyName', e);
      }
    }

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
      unawaited(_rotateKeys());
    });

    _lastKeyRotation = DateTime.now();
  }

  Future<void> _rotateKeys() async {
    _logger.verbose('Performing key rotation');

    try {
      _lastKeyRotation = DateTime.now();
      _recordSecurityMetric('key_rotation');
      _logger.debug('Key rotation completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to rotate keys', e, stackTrace);
    }
  }

  /// Checks if a request from [clientId] should be rate limited.
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

  /// Tracks authentication attempts for [clientId].
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

  /// Retrieves a private key by its [keyName] from the keystore.
  Future<IPFSPrivateKey?> getPrivateKey(String keyName) async {
    if (keyName.isEmpty) return null;
    _logger.debug('Retrieving private key for: $keyName');

    try {
      if (_encryptedKeystore.hasKey(keyName)) {
        if (!_encryptedKeystore.isUnlocked) {
          _logger.warning(
            'Encrypted key requested but keystore is locked: $keyName',
          );
          return null;
        }
        final keyPair = await _encryptedKeystore.getKey(keyName);
        final seed = await keyPair.extractSeedAndZero();
        return IPFSPrivateKey.fromBytes(seed);
      }

      if (_keystore.hasKeyPair(keyName)) {
        final keyPair = _keystore.getKeyPair(keyName);
        return IPFSPrivateKey.fromString(keyPair.privateKey);
      }

      _logger.warning('Key not found in any keystore: $keyName');
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to retrieve private key for $keyName',
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Gets the current security status and metrics.
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
      'keystore_unlocked': isKeystoreUnlocked,
    };
  }

  @override
  Future<void> start() async {
    _logger.debug('Starting SecurityManager');
    if (_config.enableKeyRotation && _keyRotationTimer == null) {
      _setupKeyRotation();
    }
  }

  @override
  Future<void> stop() async {
    _logger.debug('Stopping SecurityManager');
    _keyRotationTimer?.cancel();
    _keyRotationTimer = null;
    lockKeystore();
  }

  void _recordSecurityMetric(String metricType, {Map<String, dynamic>? data}) {
    // Record metrics
    _metrics.recordProtocolMetrics('security', {'type': metricType, ...?data});
  }
}
