// test/services/gateway/gateway_tls_manager_extra_test.dart
import 'dart:io';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/services/gateway/acme_client.dart';
import 'package:dart_ipfs/src/services/gateway/acme_persistence.dart';
import 'package:dart_ipfs/src/services/gateway/gateway_tls_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

/// Self-signed test certificate (CN=test.local, not a live credential).
const _testCertPem = '''
-----BEGIN CERTIFICATE-----
MIIDCzCCAfOgAwIBAgIUGW7MmMLf1TQOU0Gwd4Z1Fgnf3PswDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAwwKdGVzdC5sb2NhbDAeFw0yNjA5MTkxNTE1MjBaFw0zNjA5
MTYxNTE1MjBaMBUxEzARBgNVBAMMCnRlc3QubG9jYWwwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDU0E36l0z1yAShc2ne61Kx2E7hTheFa88Dr30mC863
9e2vAL4+CidHlzUUFPJ6g/a+6TTCznFw6SFj61Fnyh28Zpj/ISub/sA7xpJhnRsA
V/5Of/rzoom13i+SFCRd2NdEKoM2FnKruRRxVPkAJvwEQLgs1qG7mnrjeVyaEqWo
QlkQLd2/por9i6GyvmYlzn2xoAE97AE5Jhe4+Wch5T/EXSVMbzas6Q6T4XY13Xgp
VQ4rZdbac8PnVn+xsEmM8Uxs7QXFzk2oH9QJAAgseSN8TrYT9g8Omd30Rrrlw4qC
avjM5N8tXUkHwDTDvt8pMds2HCE8fePVz85e1UuVs37XAgMBAAGjUzBRMB0GA1Ud
DgQWBBS5wp9nGt1tV6zrszeDSYkOf3Pv7TAfBgNVHSMEGDAWgBS5wp9nGt1tV6zr
szeDSYkOf3Pv7TAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQAm
GATA4E8yiaedn7EajhxpTXTe9v/d2Mn26/P/hic397mDEK1UG3vjk4//W4iJvwPu
yq8o78NkqXFKO9CvMESGJ7G0tayOXjtYbD1ukhiy+bSSmaA4l34CUzkdwctt/37D
NJiPVMx93PwCC8XiDNk8wgZa5jbEzPUhROSfAuiMIFG9LH3DrX+j9eycDZ010nZw
UmxU4ANv8xbW8gemF7c9Yskx4xJko7c0dJwLZKpy/Dku5f5miR65TI9VAOCU8lJj
Tjc06PsUZhZPaTRgvRuoXK9ckASR0i0OGpV2WR4b60f4zVG3EHNmuytr0DQmDYUS
oBm2nYAUkCxBSrqBT1Lf
-----END CERTIFICATE-----
''';

/// Private key matching [_testCertPem] (throwaway test fixture).
const _testKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDU0E36l0z1yASh
c2ne61Kx2E7hTheFa88Dr30mC8639e2vAL4+CidHlzUUFPJ6g/a+6TTCznFw6SFj
61Fnyh28Zpj/ISub/sA7xpJhnRsAV/5Of/rzoom13i+SFCRd2NdEKoM2FnKruRRx
VPkAJvwEQLgs1qG7mnrjeVyaEqWoQlkQLd2/por9i6GyvmYlzn2xoAE97AE5Jhe4
+Wch5T/EXSVMbzas6Q6T4XY13XgpVQ4rZdbac8PnVn+xsEmM8Uxs7QXFzk2oH9QJ
AAgseSN8TrYT9g8Omd30Rrrlw4qCavjM5N8tXUkHwDTDvt8pMds2HCE8fePVz85e
1UuVs37XAgMBAAECggEAAjIQO+PhUR2xsbx0SbMB9N4obvnUeeSTPtjBT8fXI1Vl
RBhGiNlSPAWlmvDmhFIhjFxGgRLw+PCTDvKTfrGx7JNFERVNDs+dW01R0lyGCzDd
NmWVfAQfzbjvotaUOgD4cBzMb53ANJQBth5qLEx+7nM78zMCExXQQJ6sUG9qJdf2
sm71eBfkVR4BENXQzxvaZG6yevHLaBIXh8Y3WS6/h47KZUALwnWrdxYISIvrOB/K
5pSC9rTySq2F+ExlaBOfb50OOwUk9Slt0pmEWSk+PbMskgyCdJkfOhNeXNQtN4sC
4IAOaKFuCwVu9HSgjLhonH22gTnxP9Tx4TqeFsrlEQKBgQD5wNnlyJd3PQ1aVH11
EsDzHk8/kzafeiq4ZUx5omLj56msnr6zMi1jZ/slxrcccsJBbDnfhoeSF5SSbHNG
1xVzPISRwj7Hq3hjQ7bLo7GgdCVhX9+Jk9RjfAd0zlj2i9Gg/L1IroKMfvoSpi70
QeSV0S9x4sKW6IPYR+ztbMiwOwKBgQDaIu6ip2++GpRFSJDKDefEUi79udmyntzU
Zb5SvhJeuYtnzTnMfRHFVqWunlNTkbDnT6zSA4l5sLrdygWXQTTVL+tDeJCXikOq
nQxzAFOggqcvFbefxAfuE7YylKmqIWxa4Chno7e/vvBLtIN4tI6L4aWH0eoE7Cm9
79js/4B+FQKBgDnD5yIEkTPdBRedbx8C5WnV2tKDhCDCqtrXYybG7kR0MoRgew8L
TgAt7qLAIV4NFOz40THn9bdOiOiM+OSrnqR2nNrxqH+aI1AiO0dCZzULaBHrkNJL
RNZ1u2vCxkTP9f5cNpN2+W7xd3mUwktwaiRUq7qVjhhFUylVCXGotYo9AoGAZFHE
ZdGTNl6K6gIhdItIl6UkL1QVpmwhKx1PlkYLtLyoPCjJ+B1c2uCqedAeikRqkza1
SDCQPQLmLbIHODSo05KiI/mCpe7Uh9aKLylrTFpKAQF/3V4ON5OhK0nrbW7JolGM
w30ruGdbo7V08UI4fGRd+ES112W1HMD9hqFKurECgYEAvDSUiCqcLPvdxtdfcOma
HB9mlqOogqkNgodxmX0/5odzVn9R6+Pb12Pp2SNs0TfSBRnMkNg799V4wkIOCrhr
djD8qt4UHTYm3tkaQWyJymhkSDVaebfOLWK9LSJVSiLdPtaOFE8XR0uBu6UltzN2
N/2I4RqsHGg/eXh8Jox+vXk=
-----END PRIVATE KEY-----
''';

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
  _FakePersistence({
    this.validCertificate = false,
    this.needsRenew = true,
    this.certPem,
    this.keyPem,
    this.metadata,
  });

  final bool validCertificate;
  final bool needsRenew;
  final String? certPem;
  final String? keyPem;
  final Map<String, dynamic>? metadata;
  var savedAccountKey = false;
  var savedCertificate = false;

  @override
  Future<bool> hasValidCertificate() async => validCertificate;

  @override
  Future<bool> needsRenewal() async => needsRenew;

  @override
  Future<String?> loadCertificate() async => certPem;

  @override
  Future<String?> loadPrivateKey() async => keyPem;

  @override
  Future<Map<String, dynamic>?> loadMetadata() async => metadata;

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
      final config = const GatewayConfig(
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
      final config = const GatewayConfig(
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
      final config = const GatewayConfig(
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
      final config = const GatewayConfig(
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

    test('obtainCertificate loads a persisted valid certificate', () async {
      final notAfter = DateTime.now().add(const Duration(days: 30));
      final persistence = _FakePersistence(
        validCertificate: true,
        needsRenew: false,
        certPem: _testCertPem,
        keyPem: _testKeyPem,
        metadata: {'notAfter': notAfter.toIso8601String()},
      );
      final provider = LetsEncryptAutoTlsProvider(persistence: persistence);
      final config = const GatewayConfig(
        autoTls: true,
        autoTlsAcceptTos: true,
        autoTlsDomain: 'test.local',
        autoTlsEmail: 'a@example.com',
      );

      final context = await provider.obtainCertificate(config);
      expect(context, isA<SecurityContext>());
      expect(provider.state, equals(AutoTlsState.active));
      expect(await provider.certificateExpiry(), equals(notAfter));
    });

    test('obtainCertificate completes a successful ACME issuance', () async {
      final persistence = _FakePersistence(
        validCertificate: false,
        needsRenew: true,
      );
      final acme = _FakeAcmeClient();
      String? usedDirectory;
      final provider = LetsEncryptAutoTlsProvider(
        staging: true,
        persistence: persistence,
        acmeClientFactory: ({required directoryUrl}) {
          usedDirectory = directoryUrl;
          return acme;
        },
      );
      final config = const GatewayConfig(
        autoTls: true,
        autoTlsAcceptTos: true,
        autoTlsDomain: 'test.local',
        autoTlsEmail: 'a@example.com',
        autoTlsProvider: 'letsencrypt',
      );

      final context = await provider.obtainCertificate(config);
      expect(context, isA<SecurityContext>());
      expect(provider.state, equals(AutoTlsState.active));
      expect(
        usedDirectory,
        'https://acme-staging-v02.api.letsencrypt.org/directory',
      );
      // The challenge callbacks registered and cleared the pending token.
      expect(acme.servedChallenge, isTrue);
      expect(provider.pendingChallenges, isEmpty);
      expect(persistence.savedAccountKey, isTrue);
      expect(persistence.savedCertificate, isTrue);
      expect(await provider.certificateExpiry(), isNotNull);
      await provider.dispose();
    });
  });
}

/// A fake [AcmeClient] whose issuance immediately succeeds with the test
/// certificate fixture.
class _FakeAcmeClient extends Fake implements AcmeClient {
  var servedChallenge = false;

  @override
  Future<AcmeCertificateResult> issueCertificate({
    required List<String> domains,
    required String email,
    required bool termsOfServiceAgreed,
    required Future<void> Function(AcmeHttp01Challenge challenge)
    serveChallenge,
    required Future<void> Function(AcmeHttp01Challenge challenge)
    removeChallenge,
  }) async {
    final challenge = AcmeHttp01Challenge(
      token: 'tok',
      keyAuthorization: 'tok.key',
      challengeUrl: 'https://acme.invalid/challenge/tok',
    );
    await serveChallenge(challenge);
    servedChallenge = true;
    await removeChallenge(challenge);
    return AcmeCertificateResult(
      certificatePem: _testCertPem,
      privateKeyPem: _testKeyPem,
      notAfter: DateTime.now().add(const Duration(days: 90)),
    );
  }

  @override
  String exportAccountKeyPem() => _testKeyPem;

  @override
  void dispose() {}
}
