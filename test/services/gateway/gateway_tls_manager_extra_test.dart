// test/services/gateway/gateway_tls_manager_extra_test.dart
import 'dart:io';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/services/gateway/acme_persistence.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_tls_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class _FakeProvider extends Fake implements AutoTlsProvider {
  _FakeProvider({this.context, this.expiry});

  final SecurityContext? context;
  final DateTime? expiry;
  var disposed = false;
  var _state = AutoTlsState.idle;

  @override
  AutoTlsState get state => _state;

  @override
  Future<SecurityContext> obtainCertificate(GatewayConfig config) async {
    _state = AutoTlsState.active;
    if (context == null) throw StateError('no context');
    return context!;
  }

  @override
  Future<DateTime?> certificateExpiry() async => expiry;

  @override
  Future<void> dispose() async {
    disposed = true;
    _state = AutoTlsState.idle;
  }
}

class _FakePersistence extends Fake implements AcmePersistence {
  _FakePersistence({this.validCertificate = false, this.needsRenew = true});

  final bool validCertificate;
  final bool needsRenew;
  var savedAccountKey = false;
  var savedCertificate = false;

  @override
  Future<bool> hasValidCertificate() async => validCertificate;

  @override
  Future<bool> needsRenewal() async => needsRenew;

  @override
  Future<String?> loadCertificate() async => null;

  @override
  Future<String?> loadPrivateKey() async => null;

  @override
  Future<Map<String, dynamic>?> loadMetadata() async => null;

  @override
  Future<void> saveAccountKeyPem(String pem) async {
    savedAccountKey = true;
  }

  @override
  Future<void> saveCertificate({
    required String certificatePem,
    required String privateKeyPem,
    required DateTime notAfter,
    required List<String> domains,
  }) async {
    savedCertificate = true;
  }
}

void main() {
  group('GatewayTlsManager manager methods', () {
    test('markActive, markInactive, dispose and getters', () async {
      final context = SecurityContext();
      final provider = _FakeProvider(context: context, expiry: DateTime(2026));
      final manager = GatewayTlsManager(
        const GatewayConfig(autoTls: true, autoTlsAcceptTos: true),
        provider: provider,
      );
      await manager.loadSecurityContext();
      expect(manager.isContextLoaded, isTrue);
      expect(manager.isActive, isTrue);
      expect(manager.certificateExpiry, equals(DateTime(2026)));
      expect(manager.autoTlsState, equals(AutoTlsState.active));
      expect(manager.activeAutoTlsProvider, isNull);

      manager.markInactive();
      expect(manager.isActive, isFalse);

      manager.markActive();
      expect(manager.isActive, isTrue);

      await manager.dispose();
      expect(provider.disposed, isTrue);
      expect(manager.isContextLoaded, isFalse);
      expect(manager.isActive, isFalse);
    });

    test('markActive without context throws', () {
      final manager = GatewayTlsManager(const GatewayConfig());
      expect(manager.markActive, throwsA(isA<StateError>()));
    });

    test('autoTLS state defaults to idle when no provider', () {
      final manager = GatewayTlsManager(const GatewayConfig());
      expect(manager.autoTlsState, equals(AutoTlsState.idle));
      expect(manager.activeAutoTlsProvider, isNull);
    });
  });

  group('LetsEncryptAutoTlsProvider', () {
    test('initial state and dispose', () {
      final provider = LetsEncryptAutoTlsProvider();
      expect(provider.state, equals(AutoTlsState.idle));
      expect(provider.pendingChallenges, isEmpty);
      provider.dispose();
    });

    test('obtainCertificate with missing ToS throws', () async {
      final provider = LetsEncryptAutoTlsProvider();
      final config = GatewayConfig(
        autoTls: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: 'a@example.com',
      );
      expect(
        () => provider.obtainCertificate(config),
        throwsA(isA<StateError>()),
      );
      expect(provider.state, equals(AutoTlsState.idle));
    });

    test('obtainCertificate with missing domain throws', () async {
      final provider = LetsEncryptAutoTlsProvider();
      final config = GatewayConfig(
        autoTls: true,
        autoTlsAcceptTos: true,
        autoTlsEmail: 'a@example.com',
      );
      expect(
        () => provider.obtainCertificate(config),
        throwsA(isA<StateError>()),
      );
    });

    test('obtainCertificate with missing email throws', () async {
      final provider = LetsEncryptAutoTlsProvider();
      final config = GatewayConfig(
        autoTls: true,
        autoTlsAcceptTos: true,
        autoTlsDomain: 'example.com',
      );
      expect(
        () => provider.obtainCertificate(config),
        throwsA(isA<StateError>()),
      );
    });

    test('obtainCertificate falls back to ACME when no valid cert', () async {
      final persistence = _FakePersistence(
        validCertificate: false,
        needsRenew: true,
      );
      final provider = LetsEncryptAutoTlsProvider(
        staging: true,
        persistence: persistence,
      );
      final config = GatewayConfig(
        autoTls: true,
        autoTlsAcceptTos: true,
        autoTlsDomain: 'example.com',
        autoTlsEmail: 'a@example.com',
        autoTlsProvider: 'zerossl',
      );
      // The provider will attempt to contact the staging ACME directory and
      // fail because there is no server. This still exercises the directory
      // URL selection and the certificate acquisition path.
      await expectLater(
        provider.obtainCertificate(config),
        throwsA(isA<Exception>()),
      );
      expect(provider.state, equals(AutoTlsState.idle));
    });
  });
}
