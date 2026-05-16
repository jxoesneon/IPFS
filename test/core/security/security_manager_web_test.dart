import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/security_config.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/security_manager_web.dart';
import 'package:test/test.dart';

void main() {
  group('SecurityManagerWeb', () {
    late SecurityManagerWeb securityManager;
    late IPFSConfig config;
    late MetricsCollector metrics;

    setUp(() {
      config = IPFSConfig();
      metrics = MetricsCollector(config);
      securityManager = SecurityManagerWeb(config.security, metrics);
    });

    test('should start locked', () {
      expect(securityManager.isKeystoreUnlocked, isFalse);
    });

    test('should unlock with password', () async {
      await securityManager.unlockKeystore('password');
      expect(securityManager.isKeystoreUnlocked, isTrue);
    });

    test('should generate and retrieve secure keys', () async {
      await securityManager.unlockKeystore('password');

      final keyName = 'test-key';
      final pubKey = await securityManager.generateSecureKey(keyName);

      expect(pubKey, isNotNull);
      expect(pubKey.length, 32);
      expect(securityManager.hasSecureKey(keyName), isTrue);

      final retrievedPubKey = securityManager.getSecurePublicKey(keyName);
      expect(retrievedPubKey, equals(pubKey));

      final keyPair = await securityManager.getSecureKey(keyName);
      final extractedPub = await keyPair.extractPublicKey();
      expect(extractedPub.bytes, equals(pubKey));
    });

    test('should lock and clear keys', () async {
      await securityManager.unlockKeystore('password');
      await securityManager.generateSecureKey('test-key');

      securityManager.lockKeystore();
      expect(securityManager.isKeystoreUnlocked, isFalse);

      expect(
        () => securityManager.getSecureKey('test-key'),
        throwsA(isA<StateError>()),
      );
    });

    test('unlockKeystore throws on empty password', () async {
      expect(() => securityManager.unlockKeystore(''), throwsArgumentError);
    });

    test('generateSecureKey throws on empty key name', () async {
      await securityManager.unlockKeystore('password');
      expect(() => securityManager.generateSecureKey(''), throwsArgumentError);
    });

    test('getSecureKey throws on empty key name', () async {
      await securityManager.unlockKeystore('password');
      expect(() => securityManager.getSecureKey(''), throwsArgumentError);
    });

    test('generateSecureKey accepts label parameter', () async {
      await securityManager.unlockKeystore('password');
      final pubKey = await securityManager.generateSecureKey(
        'test-key',
        label: 'my-label',
      );
      expect(pubKey, isNotNull);
    });

    test('start method is a no-op', () async {
      await securityManager.start();
      expect(securityManager.isKeystoreUnlocked, isFalse);
    });

    test('stop method locks keystore', () async {
      await securityManager.unlockKeystore('password');
      await securityManager.generateSecureKey('test-key');

      await securityManager.stop();
      expect(securityManager.isKeystoreUnlocked, isFalse);
    });

    test('should rate limit requests', () {
      final securityConfig = SecurityConfig(
        enableRateLimiting: true,
        maxRequestsPerMinute: 2,
      );
      securityManager = SecurityManagerWeb(securityConfig, metrics);

      final clientId = 'test-client';

      expect(securityManager.shouldRateLimit(clientId), isFalse);
      expect(securityManager.shouldRateLimit(clientId), isFalse);
      expect(securityManager.shouldRateLimit(clientId), isTrue);
    });

    test('should respect enableRateLimiting flag', () {
      final securityConfig = SecurityConfig(
        enableRateLimiting: false,
        maxRequestsPerMinute: 1,
      );
      securityManager = SecurityManagerWeb(securityConfig, metrics);

      final clientId = 'test-client';

      expect(securityManager.shouldRateLimit(clientId), isFalse);
      expect(securityManager.shouldRateLimit(clientId), isFalse);
    });

    test('should track auth attempts', () {
      final securityConfig = SecurityConfig(maxAuthAttempts: 3);
      securityManager = SecurityManagerWeb(securityConfig, metrics);
      final clientId = 'test-client';

      expect(securityManager.trackAuthAttempt(clientId, false), isTrue);
      expect(securityManager.trackAuthAttempt(clientId, false), isTrue);
      expect(securityManager.trackAuthAttempt(clientId, false), isFalse);

      expect(securityManager.trackAuthAttempt(clientId, true), isTrue);
      expect(securityManager.trackAuthAttempt(clientId, false), isTrue);
    });

    test('should return correct status', () async {
      await securityManager.unlockKeystore('password');

      final securityConfig = SecurityConfig(
        enableRateLimiting: true,
        maxRequestsPerMinute: 1,
        maxAuthAttempts: 3,
      );
      securityManager = SecurityManagerWeb(securityConfig, metrics);
      await securityManager.unlockKeystore('password');

      securityManager.shouldRateLimit('client-1');
      securityManager.shouldRateLimit('client-1'); // Blocked

      securityManager.trackAuthAttempt('client-2', false);
      securityManager.trackAuthAttempt('client-2', false);
      securityManager.trackAuthAttempt('client-2', false); // Blocked

      final status = await securityManager.getStatus();

      expect(status['platform'], equals('web'));
      expect(status['keystore_unlocked'], isTrue);
      expect(status['active_rate_limits'], equals(1));
      expect(status['blocked_clients'], equals(1));
      expect(status['metrics'], isNotEmpty);
      expect(status['metrics']['rate_limit'], isNotNull);
      expect(status['metrics']['auth_blocked'], isNotNull);
    });
  });
}
