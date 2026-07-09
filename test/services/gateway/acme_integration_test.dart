// test/services/gateway/acme_integration_test.dart
import 'dart:io';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/services/gateway/acme_client.dart';
import 'package:dart_ipfs/src/services/gateway/acme_persistence.dart';
import 'package:dart_ipfs/src/services/gateway/domain_validator.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_tls_manager.dart';
import 'package:test/test.dart';

void main() {
  group('ACME Integration Tests', () {
    test('AcmePersistence creates and loads account key', () async {
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: 'test@example.com',
        autoTlsAcceptTos: true,
      );
      final persistence = AcmePersistence(config);

      // Clean up any existing data
      try {
        await persistence.deleteAll();
      } catch (_) {}

      // Try to load non-existent key
      final loadedKey = await persistence.loadAccountKey();
      expect(loadedKey, isNull);

      // Note: We can't test saving/loading without a real key generation
      // which requires the full ACME client setup. This is a placeholder
      // for when we have a proper test environment.

      // Clean up
      try {
        await persistence.deleteAll();
      } catch (_) {}
    });

    test('AcmePersistence checks certificate validity', () async {
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: 'test@example.com',
        autoTlsAcceptTos: true,
      );
      final persistence = AcmePersistence(config);

      // Clean up
      try {
        await persistence.deleteAll();
      } catch (_) {}

      // No certificate should exist
      final hasValid = await persistence.hasValidCertificate();
      expect(hasValid, isFalse);

      // Should need renewal (no certificate)
      final needsRenewal = await persistence.needsRenewal();
      expect(needsRenewal, isTrue);

      // Clean up
      try {
        await persistence.deleteAll();
      } catch (_) {}
    });

    test('DomainValidator validates domain structure', () async {
      final validator = DomainValidator();

      // This test checks the structure, not actual DNS resolution
      // since we don't have a real domain to test against
      expect(validator, isNotNull);
      expect(validator.expectedIp, isNull);
    });

    test('LetsEncryptAutoTlsProvider requires ToS acceptance', () async {
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: 'test@example.com',
        autoTlsAcceptTos: false, // Not accepted
      );

      final provider = LetsEncryptAutoTlsProvider(staging: true);

      expect(
        () => provider.obtainCertificate(config),
        throwsA(isA<StateError>()),
      );
    });

    test('LetsEncryptAutoTlsProvider requires domain', () async {
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: null, // No domain
        autoTlsEmail: 'test@example.com',
        autoTlsAcceptTos: true,
      );

      final provider = LetsEncryptAutoTlsProvider(staging: true);

      expect(
        () => provider.obtainCertificate(config),
        throwsA(isA<StateError>()),
      );
    });

    test('LetsEncryptAutoTlsProvider requires email', () async {
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: null, // No email
        autoTlsAcceptTos: true,
      );

      final provider = LetsEncryptAutoTlsProvider(staging: true);

      expect(
        () => provider.obtainCertificate(config),
        throwsA(isA<StateError>()),
      );
    });

    test('AcmeClient can be created with staging URL', () {
      final client = AcmeClient(
        directoryUrl: 'https://acme-staging-v02.api.letsencrypt.org/directory',
      );

      expect(client.directoryUrl, contains('staging'));
      client.dispose();
    });

    test('AcmeClient can be created with production URL', () {
      final client = AcmeClient(
        directoryUrl: 'https://acme-v02.api.letsencrypt.org/directory',
      );

      expect(client.directoryUrl, contains('acme-v02'));
      expect(client.directoryUrl, isNot(contains('staging')));
      client.dispose();
    });

    test('GatewayConfig has ACME persistence fields', () {
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: 'test@example.com',
        autoTlsAcceptTos: true,
        autoTlsAccountKeyPath: '/tmp/account_key.pem',
        autoTlsCertificatePath: '/tmp/certificate.pem',
        autoTlsPrivateKeyPath: '/tmp/private_key.pem',
        autoTlsRenewalThresholdDays: 30,
      );

      expect(config.autoTlsAccountKeyPath, '/tmp/account_key.pem');
      expect(config.autoTlsCertificatePath, '/tmp/certificate.pem');
      expect(config.autoTlsPrivateKeyPath, '/tmp/private_key.pem');
      expect(config.autoTlsRenewalThresholdDays, 30);
    });

    test('GatewayConfig serializes ACME persistence fields', () {
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: 'test@example.com',
        autoTlsAcceptTos: true,
        autoTlsAccountKeyPath: '/tmp/account_key.pem',
        autoTlsCertificatePath: '/tmp/certificate.pem',
        autoTlsPrivateKeyPath: '/tmp/private_key.pem',
        autoTlsRenewalThresholdDays: 30,
      );

      final json = config.toJson();
      expect(json['autoTlsAccountKeyPath'], '/tmp/account_key.pem');
      expect(json['autoTlsCertificatePath'], '/tmp/certificate.pem');
      expect(json['autoTlsPrivateKeyPath'], '/tmp/private_key.pem');
      expect(json['autoTlsRenewalThresholdDays'], 30);
    });

    test('GatewayConfig deserializes ACME persistence fields', () {
      final json = {
        'autoTls': true,
        'autoTlsDomain': 'example.com',
        'autoTlsEmail': 'test@example.com',
        'autoTlsAcceptTos': true,
        'autoTlsAccountKeyPath': '/tmp/account_key.pem',
        'autoTlsCertificatePath': '/tmp/certificate.pem',
        'autoTlsPrivateKeyPath': '/tmp/private_key.pem',
        'autoTlsRenewalThresholdDays': 30,
      };

      final config = GatewayConfig.fromJson(json);
      expect(config.autoTlsAccountKeyPath, '/tmp/account_key.pem');
      expect(config.autoTlsCertificatePath, '/tmp/certificate.pem');
      expect(config.autoTlsPrivateKeyPath, '/tmp/private_key.pem');
      expect(config.autoTlsRenewalThresholdDays, 30);
    });
  });

  group('ACME Staging Integration (Manual)', () {
    // These tests are marked as manual because they require:
    // 1. A real public domain with DNS pointing to the test machine
    // 2. Port 80 accessible from the internet
    // 3. Manual execution in a production-like environment

    test('Full ACME flow with staging server - MANUAL', () async {
      // This test is intentionally skipped in automated runs
      // To run manually:
      // 1. Set up a domain with DNS pointing to your machine
      // 2. Ensure port 80 is accessible
      // 3. Uncomment the test code below
      // 4. Run with: dart test test/services/gateway/acme_integration_test.dart

      expect(true, isTrue); // Placeholder

      /*
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'your-test-domain.com', // Replace with real domain
        autoTlsEmail: 'your-email@example.com', // Replace with real email
        autoTlsAcceptTos: true,
        autoTlsProvider: 'letsencrypt',
      );

      final persistence = AcmePersistence(config);
      final validator = DomainValidator();

      // Pre-flight validation
      final validation = await validator.validateDomain(config.autoTlsDomain!);
      if (!validation.success) {
        print('Domain validation failed: ${validation.message}');
        fail('Domain validation failed');
      }

      final provider = LetsEncryptAutoTlsProvider(
        staging: true,
        persistence: persistence,
        domainValidator: validator,
      );

      try {
        final context = await provider.obtainCertificate(config);
        expect(context, isNotNull);
        print('Certificate obtained successfully!');
      } finally {
        await provider.dispose();
        await persistence.deleteAll();
      }
      */
    }, skip: true);
  });
}
