// lib/src/services/gateway/gateway_tls_manager.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart' as asn1;

import '../../core/config/gateway_config.dart';
import '../../utils/logger.dart';
import 'acme_client.dart';
import 'acme_persistence.dart';

/// States of the ACME certificate lifecycle.
enum AutoTlsState {
  /// No automatic certificate operation is in progress.
  idle,

  /// Waiting for a certificate from the ACME provider.
  acquiring,

  /// The ACME provider is validating domain ownership.
  validating,

  /// A valid certificate is installed and active.
  active,

  /// The certificate is being renewed.
  renewing,
}

/// Provider interface for automatic TLS certificate issuance via ACME.
abstract class AutoTlsProvider {
  /// Current state of the certificate lifecycle.
  AutoTlsState get state;

  /// Obtains or renews a certificate for the configured domain and returns a
  /// [SecurityContext] containing it.
  Future<SecurityContext> obtainCertificate(GatewayConfig config);

  /// Returns the not-after expiry of the current certificate, if known.
  Future<DateTime?> certificateExpiry();

  /// Releases any resources held by the provider.
  Future<void> dispose();
}

/// Production-ready ACME provider for Let's Encrypt / ZeroSSL.
///
/// This provider implements the full ACME HTTP-01 certificate issuance flow
/// with persistent storage, domain validation, and automatic renewal.
class LetsEncryptAutoTlsProvider implements AutoTlsProvider {
  /// Creates a Let's Encrypt/ZeroSSL ACME provider.
  LetsEncryptAutoTlsProvider({
    this.staging = false,
    AcmePersistence? persistence,
  }) : _persistence = persistence;

  /// Whether to use the ACME provider's staging endpoint.
  final bool staging;

  /// Optional persistence manager for account keys and certificates.
  /// If null, a new one is created on first use.
  final AcmePersistence? _persistence;

  final _logger = Logger('LetsEncryptAutoTlsProvider');

  DateTime? _certificateExpiry;
  AutoTlsState _state = AutoTlsState.idle;
  final Map<String, String> _pendingChallenges = {};
  AcmeClient? _acmeClient;
  AcmePersistence? _usedPersistence;

  /// Pending HTTP-01 challenges keyed by token, mapping to the key
  /// authorization that must be served for each. Cleared by [dispose].
  Map<String, String> get pendingChallenges => _pendingChallenges;

  /// Gets the ACME directory URL based on staging flag.
  String _getDirectoryUrl(String provider) {
    if (staging) {
      if (provider.toLowerCase() == 'letsencrypt') {
        return 'https://acme-staging-v02.api.letsencrypt.org/directory';
      } else if (provider.toLowerCase() == 'zerossl') {
        return 'https://acme.zerossl.com/staging/directory';
      }
    } else {
      if (provider.toLowerCase() == 'letsencrypt') {
        return 'https://acme-v02.api.letsencrypt.org/directory';
      } else if (provider.toLowerCase() == 'zerossl') {
        return 'https://acme.zerossl.com/directory';
      }
    }
    // Default to Let's Encrypt production
    return staging
        ? 'https://acme-staging-v02.api.letsencrypt.org/directory'
        : 'https://acme-v02.api.letsencrypt.org/directory';
  }

  @override
  AutoTlsState get state => _state;

  @override
  Future<SecurityContext> obtainCertificate(GatewayConfig config) async {
    if (!config.autoTlsAcceptTos) {
      throw StateError(
        'AutoTLS requires explicit acceptance of the ACME terms of service',
      );
    }
    if (config.autoTlsDomain == null || config.autoTlsDomain!.isEmpty) {
      throw StateError('AutoTLS requires a configured domain');
    }
    if (config.autoTlsEmail == null || config.autoTlsEmail!.isEmpty) {
      throw StateError('AutoTLS requires a configured account email');
    }

    // Initialize persistence
    _usedPersistence ??= _persistence ?? AcmePersistence(config);

    // Check if we have a valid certificate that doesn't need renewal
    if (await _usedPersistence!.hasValidCertificate() &&
        !(await _usedPersistence!.needsRenewal())) {
      _logger.info('Valid certificate exists, loading from storage');
      final certPem = await _usedPersistence!.loadCertificate();
      final keyPem = await _usedPersistence!.loadPrivateKey();
      final metadata = await _usedPersistence!.loadMetadata();

      if (certPem != null && keyPem != null && metadata != null) {
        final notAfterStr = metadata['notAfter'] as String?;
        if (notAfterStr != null) {
          _certificateExpiry = DateTime.parse(notAfterStr);
        }

        // Create SecurityContext from stored certificate
        final context = SecurityContext();
        // Write temporary files for SecurityContext to load
        final tempDir = Directory.systemTemp;
        final certFile = File('${tempDir.path}/acme_cert_${DateTime.now().millisecondsSinceEpoch}.pem');
        final keyFile = File('${tempDir.path}/acme_key_${DateTime.now().millisecondsSinceEpoch}.pem');
        try {
          await certFile.writeAsString(certPem);
          await keyFile.writeAsString(keyPem);
          context
            ..useCertificateChain(certFile.path)
            ..usePrivateKey(keyFile.path);
          _state = AutoTlsState.active;
          return context;
        } finally {
          if (certFile.existsSync()) await certFile.delete();
          if (keyFile.existsSync()) await keyFile.delete();
        }
      }
    }

    // Need to obtain or renew certificate
    try {
      _state = AutoTlsState.acquiring;
      _logger.info(
        'Requesting AutoTLS certificate from ${config.autoTlsProvider} '
        'for ${config.autoTlsDomain}',
      );

      // Create ACME client (account key will be generated if not provided)
      final directoryUrl = _getDirectoryUrl(config.autoTlsProvider);
      _acmeClient = AcmeClient(
        directoryUrl: directoryUrl,
      );

      // Build domain list
      final domains = <String>[
        config.autoTlsDomain!,
        ...config.autoTlsSANs,
      ];

      _state = AutoTlsState.validating;

      // Issue certificate
      final result = await _acmeClient!.issueCertificate(
        domains: domains,
        email: config.autoTlsEmail!,
        termsOfServiceAgreed: config.autoTlsAcceptTos,
        serveChallenge: (challenge) async {
          // Store the challenge for the gateway to serve
          _pendingChallenges[challenge.token] = challenge.keyAuthorization;
          _logger.info(
            'Challenge ready: /.well-known/acme-challenge/${challenge.token}',
          );
          // Give the gateway a moment to start serving the challenge
          await Future<void>.delayed(const Duration(seconds: 2));
        },
        removeChallenge: (challenge) async {
          _pendingChallenges.remove(challenge.token);
          _logger.info('Challenge removed: ${challenge.token}');
        },
      );

      // Save account key (always save since we can't reliably reload it)
      final newAccountKeyPem = _acmeClient!.exportAccountKeyPem();
      await _usedPersistence!.saveAccountKeyPem(newAccountKeyPem);
      _logger.info('Saved account key to storage');

      // Save certificate
      await _usedPersistence!.saveCertificate(
        certificatePem: result.certificatePem,
        privateKeyPem: result.privateKeyPem,
        notAfter: result.notAfter,
        domains: domains,
      );

      _certificateExpiry = result.notAfter;
      _state = AutoTlsState.active;

      // Create SecurityContext from the result
      final context = SecurityContext();
      final tempDir = Directory.systemTemp;
      final certFile = File('${tempDir.path}/acme_cert_${DateTime.now().millisecondsSinceEpoch}.pem');
      final keyFile = File('${tempDir.path}/acme_key_${DateTime.now().millisecondsSinceEpoch}.pem');
      try {
        await certFile.writeAsString(result.certificatePem);
        await keyFile.writeAsString(result.privateKeyPem);
        context
          ..useCertificateChain(certFile.path)
          ..usePrivateKey(keyFile.path);
        _logger.info('AutoTLS certificate obtained successfully');
        return context;
      } finally {
        if (certFile.existsSync()) await certFile.delete();
        if (keyFile.existsSync()) await keyFile.delete();
      }
    } catch (e, stackTrace) {
      _state = AutoTlsState.idle;
      _logger.error('AutoTLS certificate acquisition failed', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<DateTime?> certificateExpiry() async => _certificateExpiry;

  @override
  Future<void> dispose() async {
    _pendingChallenges.clear();
    _acmeClient?.dispose();
    _acmeClient = null;
    _state = AutoTlsState.idle;
  }
}

/// Manages TLS configuration, certificate loading, and AutoTLS orchestration
/// for [GatewayServer].
class GatewayTlsManager {
  /// Creates a TLS manager for the supplied [config].
  ///
  /// A custom [provider] may be injected for testing or for a production ACME
  /// implementation.
  GatewayTlsManager(this.config, {AutoTlsProvider? provider})
    : _provider = provider;

  /// Gateway configuration including TLS settings.
  final GatewayConfig config;

  AutoTlsProvider? _provider;
  SecurityContext? _securityContext;
  DateTime? _certificateExpiry;
  bool _active = false;

  final _logger = Logger('GatewayTlsManager');

  /// Whether a TLS [SecurityContext] has been successfully loaded.
  bool get isContextLoaded => _securityContext != null;

  /// Current AutoTLS state, or [AutoTlsState.idle] when no provider is used.
  AutoTlsState get autoTlsState => _provider?.state ?? AutoTlsState.idle;

  /// The active [LetsEncryptAutoTlsProvider] when one is configured, otherwise
  /// `null` (e.g. when a custom [AutoTlsProvider] was injected).
  LetsEncryptAutoTlsProvider? get activeAutoTlsProvider =>
      _provider is LetsEncryptAutoTlsProvider
      ? _provider as LetsEncryptAutoTlsProvider
      : null;

  /// Loads or obtains a [SecurityContext] based on [GatewayConfig].
  ///
  /// Returns the loaded context and stores the certificate expiry when
  /// available. Throws if the certificate files are missing or malformed.
  Future<SecurityContext> loadSecurityContext() async {
    if (config.autoTls) {
      _provider ??= LetsEncryptAutoTlsProvider(staging: _isStaging(config));
      _securityContext = await _provider!.obtainCertificate(config);
      _certificateExpiry = await _provider!.certificateExpiry();
      _active = _securityContext != null;
      return _securityContext!;
    }

    if (!config.enableTls) {
      throw StateError('TLS is not enabled in GatewayConfig');
    }

    final certPath = config.certificatePath;
    final keyPath = config.privateKeyPath;
    if (certPath == null || keyPath == null) {
      throw StateError(
        'TLS is enabled but certificatePath and privateKeyPath are missing',
      );
    }

    final certFile = File(certPath);
    final keyFile = File(keyPath);
    if (!certFile.existsSync() || !keyFile.existsSync()) {
      throw StateError('TLS certificate or key file not found');
    }

    final context = SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath, password: config.certificatePassword);

    try {
      _certificateExpiry = _extractExpiry(await certFile.readAsBytes());
    } catch (e, stackTrace) {
      _logger.warning('Could not parse certificate expiry', e, stackTrace);
      _certificateExpiry = null;
    }

    _securityContext = context;
    _active = true;
    return context;
  }

  /// Returns the not-after expiry of the loaded certificate, if known.
  DateTime? get certificateExpiry => _certificateExpiry;

  /// Returns true once the TLS context is loaded and the listener is active.
  bool get isActive => _active && _securityContext != null;

  /// Marks the manager as active after the TLS listener has been bound.
  void markActive() {
    if (_securityContext == null) {
      throw StateError('Cannot mark active without a loaded SecurityContext');
    }
    _active = true;
  }

  /// Marks the manager as inactive (e.g. after the TLS listener is closed).
  void markInactive() {
    _active = false;
  }

  /// Releases the provider and clears internal state.
  Future<void> dispose() async {
    await _provider?.dispose();
    _provider = null;
    _securityContext = null;
    _certificateExpiry = null;
    _active = false;
  }

  static bool _isStaging(GatewayConfig config) {
    // Operators may set a 'staging' provider value or environment override.
    return config.autoTlsProvider.toLowerCase().contains('staging');
  }

  /// Extracts the not-after date from a PEM-encoded X.509 certificate.
  static DateTime? _extractExpiry(Uint8List certBytes) {
    try {
      final pem = utf8.decode(certBytes);
      final base64Lines = pem
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('-----'))
          .join();
      if (base64Lines.isEmpty) return null;
      final der = base64Decode(base64Lines);

      final parser = asn1.ASN1Parser(Uint8List.fromList(der));
      final sequence = parser.nextObject() as asn1.ASN1Sequence;
      final elements = sequence.elements;
      if (elements == null || elements.length < 3) return null;

      final tbsCertificate = elements[0] as asn1.ASN1Sequence;
      final tbsElements = tbsCertificate.elements;
      if (tbsElements == null || tbsElements.length < 6) return null;

      // Validity is the 4th element in the TBSCertificate sequence:
      // version, serialNumber, signature, issuer, validity, subject, ...
      final validity = tbsElements[4] as asn1.ASN1Sequence;
      final validityElements = validity.elements;
      if (validityElements == null || validityElements.length < 2) return null;

      final notAfter = validityElements[1] as asn1.ASN1UtcTime;
      return notAfter.time;
    } catch (e) {
      return null;
    }
  }
}
