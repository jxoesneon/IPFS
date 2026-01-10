import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
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
  });
}
