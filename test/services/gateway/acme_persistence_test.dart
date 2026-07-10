// test/services/gateway/acme_persistence_test.dart
import 'dart:io';

import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/services/gateway/acme_persistence.dart';

void main() {
  group('AcmePersistence', () {
    late Directory tempDir;
    late GatewayConfig config;
    late AcmePersistence persistence;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('acme_persistence_test');
      config = GatewayConfig(
        autoTlsCertificatePath: '${tempDir.path}/cert.pem',
        autoTlsPrivateKeyPath: '${tempDir.path}/key.pem',
        autoTlsAccountKeyPath: '${tempDir.path}/account.pem',
        autoTlsRenewalThresholdDays: 30,
      );
      persistence = AcmePersistence(config, baseDirectory: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } on PathAccessException {
          // Windows sometimes keeps the directory locked briefly; leaving the
          // temporary directory for system cleanup is acceptable.
        }
      }
    });

    test('save and load certificate roundtrip', () async {
      final notAfter = DateTime.now().add(const Duration(days: 90));
      await persistence.saveCertificate(
        certificatePem: 'CERT',
        privateKeyPem: 'KEY',
        notAfter: notAfter,
        domains: ['example.com'],
      );
      expect(await persistence.loadCertificate(), equals('CERT'));
      expect(await persistence.loadPrivateKey(), equals('KEY'));
      final metadata = await persistence.loadMetadata();
      expect(metadata, isNotNull);
      expect(metadata!['domains'], equals(['example.com']));
      expect(DateTime.parse(metadata['notAfter'] as String), equals(notAfter));
    });

    test('hasValidCertificate returns true for non-expired cert', () async {
      final notAfter = DateTime.now().add(const Duration(days: 90));
      await persistence.saveCertificate(
        certificatePem: 'CERT',
        privateKeyPem: 'KEY',
        notAfter: notAfter,
        domains: ['example.com'],
      );
      expect(await persistence.hasValidCertificate(), isTrue);
    });

    test('hasValidCertificate returns false when expired', () async {
      final notAfter = DateTime.now().subtract(const Duration(days: 1));
      await persistence.saveCertificate(
        certificatePem: 'CERT',
        privateKeyPem: 'KEY',
        notAfter: notAfter,
        domains: ['example.com'],
      );
      expect(await persistence.hasValidCertificate(), isFalse);
    });

    test('needsRenewal returns false when far from expiry', () async {
      final notAfter = DateTime.now().add(const Duration(days: 90));
      await persistence.saveCertificate(
        certificatePem: 'CERT',
        privateKeyPem: 'KEY',
        notAfter: notAfter,
        domains: ['example.com'],
      );
      expect(await persistence.needsRenewal(), isFalse);
    });

    test('needsRenewal returns true within threshold', () async {
      final notAfter = DateTime.now().add(const Duration(days: 15));
      await persistence.saveCertificate(
        certificatePem: 'CERT',
        privateKeyPem: 'KEY',
        notAfter: notAfter,
        domains: ['example.com'],
      );
      expect(await persistence.needsRenewal(), isTrue);
    });

    test('needsRenewal returns true when metadata missing', () async {
      expect(await persistence.needsRenewal(), isTrue);
    });

    test('load returns null for missing files', () async {
      expect(await persistence.loadCertificate(), isNull);
      expect(await persistence.loadPrivateKey(), isNull);
      expect(await persistence.loadMetadata(), isNull);
    });

    test('saveAccountKeyPem and loadAccountKeyPem roundtrip', () async {
      await persistence.saveAccountKeyPem('ACCOUNT_KEY');
      expect(await persistence.loadAccountKeyPem(), equals('ACCOUNT_KEY'));
    });

    test('loadAccountKey returns null and saveAccountKey throws', () async {
      expect(await persistence.loadAccountKey(), isNull);
      expect(
        () => persistence.saveAccountKey(
          pc.RSAPrivateKey(BigInt.zero, BigInt.zero, BigInt.zero, BigInt.zero),
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('deleteAll removes files and directory', () async {
      final notAfter = DateTime.now().add(const Duration(days: 90));
      await persistence.saveCertificate(
        certificatePem: 'CERT',
        privateKeyPem: 'KEY',
        notAfter: notAfter,
        domains: ['example.com'],
      );
      await persistence.saveAccountKeyPem('ACCOUNT_KEY');
      await persistence.deleteAll();
      expect(await persistence.loadCertificate(), isNull);
      expect(await persistence.loadPrivateKey(), isNull);
      expect(await persistence.loadMetadata(), isNull);
      expect(await persistence.loadAccountKeyPem(), isNull);
      expect(Directory('${tempDir.path}').existsSync(), isFalse);
    });

    test('loadCertificate returns null when file is not readable', () async {
      final certFile = File('${tempDir.path}/certificate.pem')
        ..createSync(recursive: true);
      certFile.writeAsStringSync('CERT');
      // Make the path a directory to force a read failure.
      await certFile.delete();
      Directory('${tempDir.path}/certificate.pem').createSync();
      expect(await persistence.loadCertificate(), isNull);
    });

    test('loadPrivateKey returns null when file is not readable', () async {
      Directory('${tempDir.path}/private_key.pem').createSync(recursive: true);
      expect(await persistence.loadPrivateKey(), isNull);
    });

    test('loadMetadata returns null when JSON is invalid', () async {
      final metadataFile = File('${tempDir.path}/metadata.json')
        ..createSync(recursive: true);
      metadataFile.writeAsStringSync('{invalid json');
      expect(await persistence.loadMetadata(), isNull);
    });

    test('loadAccountKeyPem returns null when file is not readable', () async {
      Directory('${tempDir.path}/account_key.pem').createSync(recursive: true);
      expect(await persistence.loadAccountKeyPem(), isNull);
    });

    test('deleteAll ignores directory deletion errors', () async {
      final notAfter = DateTime.now().add(const Duration(days: 90));
      await persistence.saveCertificate(
        certificatePem: 'CERT',
        privateKeyPem: 'KEY',
        notAfter: notAfter,
        domains: ['example.com'],
      );
      // Create an extra file in the directory so it is not empty.
      File('${tempDir.path}/extra.txt').writeAsStringSync('keep');
      await persistence.deleteAll();
      expect(await persistence.loadCertificate(), isNull);
      expect(await persistence.loadPrivateKey(), isNull);
      expect(await persistence.loadMetadata(), isNull);
      expect(await persistence.loadAccountKeyPem(), isNull);
      // Directory should still exist because it was not empty.
      expect(Directory('${tempDir.path}').existsSync(), isTrue);
    });
  });
}
