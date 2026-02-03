import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' hide KeyPair;
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager.dart';
import 'package:dart_ipfs/src/utils/keystore.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';

class MockMetricsCollector implements MetricsCollector {
  final Map<String, dynamic> recordedMetrics = {};
  final List<Map<String, dynamic>> metricHistory = [];

  @override
  void recordProtocolMetrics(String protocol, Map<String, dynamic> metrics) {
    recordedMetrics[protocol] = metrics;
    metricHistory.add({'protocol': protocol, 'metrics': metrics});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Logger.root.level = Level.OFF;

  group('SecurityManager', () {
    late SecurityConfig config;
    late MockMetricsCollector mockMetrics;
    late SecurityManager securityManager;
    final validSeed = Uint8List(32)..fillRange(0, 32, 1);
    final validPrivKeyBase64 = base64Url.encode(validSeed);
    final testSalt = Uint8List(16)..fillRange(0, 16, 0);

    setUp(() {
      config = SecurityConfig(
        enableRateLimiting: true,
        maxRequestsPerMinute: 2, // Low limit for testing
        maxAuthAttempts: 2,
        enableKeyRotation: false,
      );
      mockMetrics = MockMetricsCollector();
      securityManager = SecurityManager(config, mockMetrics);
    });

    tearDown(() async {
      await securityManager.stop();
    });

    test('should initialize with locked keystore', () {
      expect(securityManager.isKeystoreUnlocked, isFalse);
    });

    test('secureKeystore getter', () {
      expect(securityManager.secureKeystore, isNotNull);
    });

    test('should unlock keystore with password', () async {
      await securityManager.unlockKeystore('password123', salt: testSalt);
      expect(securityManager.isKeystoreUnlocked, isTrue);
    });

    test('should lock keystore', () async {
      await securityManager.unlockKeystore('password123', salt: testSalt);
      securityManager.lockKeystore();
      expect(securityManager.isKeystoreUnlocked, isFalse);
    });

    test('should enforce rate limiting', () {
      final clientId = 'client1';

      // First 2 requests should be allowed
      expect(securityManager.shouldRateLimit(clientId), isFalse);
      expect(securityManager.shouldRateLimit(clientId), isFalse);

      // 3rd request should be limited
      expect(securityManager.shouldRateLimit(clientId), isTrue);

      // Check metrics
      expect(mockMetrics.recordedMetrics['security'], isNotNull);
      expect(
        mockMetrics.recordedMetrics['security']['type'],
        equals('rate_limit'),
      );
    });

    test('should track auth attempts', () {
      final clientId = 'client2';

      // First failure
      expect(
        securityManager.trackAuthAttempt(clientId, false),
        isTrue,
      ); // Allowed to retry

      // Second failure
      expect(
        securityManager.trackAuthAttempt(clientId, false),
        isFalse,
      ); // Blocked

      // Successful auth should reset
      securityManager.trackAuthAttempt('client3', false);
      expect(securityManager.trackAuthAttempt('client3', true), isTrue);
    });

    test('should generate secure key when unlocked', () async {
      await securityManager.unlockKeystore('secure_password', salt: testSalt);
      final keyName = 'test_key';

      final publicKey = await securityManager.generateSecureKey(keyName);

      expect(publicKey, isNotNull);
      expect(publicKey.length, equals(32)); // Ed25519 public key size
      expect(securityManager.hasSecureKey(keyName), isTrue);
      expect(securityManager.getSecurePublicKey(keyName), equals(publicKey));
    });

    test('getSecureKey - success', () async {
      await securityManager.unlockKeystore('pwd', salt: testSalt);
      await securityManager.generateSecureKey('test_key');

      final keyPair = await securityManager.getSecureKey('test_key');
      expect(keyPair, isNotNull);
    });

    test('should throw error when accessing keys while locked', () async {
      final keyName = 'test_key_locked';

      expect(
        () => securityManager.generateSecureKey(keyName),
        throwsStateError,
      );

      expect(() => securityManager.getSecureKey(keyName), throwsStateError);
    });

    test('migrateKeysFromPlaintext - success', () async {
      // Add a key to legacy keystore with 32-byte "private key" string
      securityManager.keystore.addKeyPair(
        'legacy_key',
        KeyPair('pub', validPrivKeyBase64),
      );

      await securityManager.unlockKeystore('temp_pwd', salt: testSalt);
      final count = await securityManager.migrateKeysFromPlaintext();

      expect(count, equals(1));
      expect(securityManager.hasSecureKey('legacy_key'), isTrue);
      expect(
        securityManager.keystore.hasKeyPair('legacy_key'),
        isFalse,
      ); // Cleared
    });

    test('migrateKeysFromPlaintext - empty', () async {
      await securityManager.unlockKeystore('temp_pwd', salt: testSalt);
      final count = await securityManager.migrateKeysFromPlaintext();
      expect(count, equals(0));
    });

    test('migrateKeysFromPlaintext - skip existing', () async {
      await securityManager.unlockKeystore('temp_pwd', salt: testSalt);
      await securityManager.generateSecureKey('existing_key');

      securityManager.keystore.addKeyPair(
        'existing_key',
        KeyPair('pub', validPrivKeyBase64),
      );

      final count = await securityManager.migrateKeysFromPlaintext();
      expect(count, equals(0));
    });

    test('migrateKeysFromPlaintext - locked error', () async {
      expect(
        () => securityManager.migrateKeysFromPlaintext(),
        throwsStateError,
      );
    });

    test('TLS initialization error - missing paths', () {
      final tlsConfig = SecurityConfig(enableTLS: true);
      expect(() => SecurityManager(tlsConfig, mockMetrics), throwsStateError);
    });

    test('TLS initialization error - missing cert', () {
      final tlsConfig = SecurityConfig(
        enableTLS: true,
        tlsCertificatePath: 'non_existent_cert',
        tlsPrivateKeyPath: 'non_existent_key',
      );
      expect(
        () => SecurityManager(tlsConfig, mockMetrics),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('TLS initialization error - cert exists but key missing', () {
      final tempDir = Directory.systemTemp.createTempSync();
      final certFile = File('${tempDir.path}/cert')..createSync();

      final tlsConfig = SecurityConfig(
        enableTLS: true,
        tlsCertificatePath: certFile.path,
        tlsPrivateKeyPath: 'non_existent_key',
      );

      try {
        expect(
          () => SecurityManager(tlsConfig, mockMetrics),
          throwsA(
            predicate(
              (e) =>
                  e is FileSystemException && e.message.contains('private key'),
            ),
          ),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Key rotation execution', () async {
      final rotationConfig = SecurityConfig(
        enableKeyRotation: true,
        keyRotationInterval: Duration(milliseconds: 10),
      );
      final manager = SecurityManager(rotationConfig, mockMetrics);
      await manager.start();

      // Wait for at least one rotation
      await Future.delayed(Duration(milliseconds: 30));

      final status = await manager.getStatus();
      expect(status['key_rotation_enabled'], isTrue);
      // Depending on timing, metrics might have been recorded

      await manager.stop();
    });

    test('getPrivateKey - key not found fallback', () async {
      final key = await securityManager.getPrivateKey('non_existent');
      expect(key, isNull);
    });

    test('getPrivateKey fallback - secure key', () async {
      await securityManager.unlockKeystore('pwd', salt: testSalt);
      await securityManager.generateSecureKey('secure_key');

      final key = await securityManager.getPrivateKey('secure_key');
      expect(key, isNotNull);
    });

    test('getPrivateKey fallback - plaintext key', () async {
      securityManager.keystore.addKeyPair(
        'legacy_key',
        KeyPair('pub', validPrivKeyBase64),
      );

      final key = await securityManager.getPrivateKey('legacy_key');
      expect(key, isNotNull);
    });

    test('getPrivateKey fallback - locked warning', () async {
      await securityManager.unlockKeystore('pwd', salt: testSalt);
      await securityManager.generateSecureKey('secure_key');
      securityManager.lockKeystore();

      final key = await securityManager.getPrivateKey('secure_key');
      expect(key, isNull);
    });

    test('getStatus reporting', () async {
      final status = await securityManager.getStatus();
      expect(status, contains('tls_enabled'));
      expect(status, contains('metrics'));
      expect(status, contains('active_rate_limits'));
      expect(status, contains('blocked_clients'));
    });
  });
}
