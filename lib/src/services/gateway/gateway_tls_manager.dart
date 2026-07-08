// lib/src/services/gateway/gateway_tls_manager.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/gateway_config.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:pointycastle/asn1.dart' as asn1;

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

/// Minimal ACME provider skeleton for Let's Encrypt / ZeroSSL.
///
/// This is a structural implementation; real ACME HTTP-01 issuance requires a
/// mature Dart ACME client. The provider enforces explicit ToS acceptance and
/// never issues certificates silently.
class LetsEncryptAutoTlsProvider implements AutoTlsProvider {
  /// Creates a Let's Encrypt/ZeroSSL ACME provider.
  LetsEncryptAutoTlsProvider({this.staging = false});

  /// Whether to use the ACME provider's staging endpoint.
  final bool staging;

  final _logger = Logger('LetsEncryptAutoTlsProvider');

  DateTime? _certificateExpiry;
  AutoTlsState _state = AutoTlsState.idle;

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

    try {
      _state = AutoTlsState.acquiring;
      _logger.info(
        'Requesting AutoTLS certificate from ${config.autoTlsProvider} '
        'for ${config.autoTlsDomain}',
      );
      _state = AutoTlsState.validating;

      // TODO: perform real ACME HTTP-01 challenge and obtain certificate chain.
      // For now, this provider documents the state machine and fails cleanly
      // so that callers can inject a real implementation or test stub.
      throw UnimplementedError(
        'Real ACME HTTP-01 certificate issuance is not yet implemented; '
        'use a concrete AutoTlsProvider or test stub',
      );
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
