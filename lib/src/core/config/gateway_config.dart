/// Configuration for the IPFS HTTP Gateway.
class GatewayConfig {
  /// Creates a new [GatewayConfig].
  const GatewayConfig({
    this.enabled = false,
    this.port = 8080,
    this.address = '0.0.0.0',
    this.writable = false,
    this.enableCache = true,
    this.cacheSize = 104857600, // 100MB
    this.gatewayDomain,
    this.enableSubdomainGateway = false,
    this.subdomainDNSLinkResolver = true,
    this.subdomainTLSRedirect = false,
    this.enableTls = false,
    this.certificatePath,
    this.privateKeyPath,
    this.certificatePassword,
    this.autoTls = false,
    this.autoTlsDomain,
    this.autoTlsEmail,
    this.autoTlsProvider = 'letsencrypt',
    this.autoTlsAcceptTos = false,
    this.autoTlsSANs = const [],
    this.tlsPort = 443,
    this.redirectHttpToHttps = false,
  });

  /// Creates a [GatewayConfig] from a JSON map.
  factory GatewayConfig.fromJson(Map<String, dynamic> json) {
    return GatewayConfig(
      enabled: json['enabled'] as bool? ?? false,
      port: json['port'] as int? ?? 8080,
      address: json['address'] as String? ?? '0.0.0.0',
      writable: json['writable'] as bool? ?? false,
      enableCache: json['enableCache'] as bool? ?? true,
      cacheSize: json['cacheSize'] as int? ?? 104857600,
      gatewayDomain: json['gatewayDomain'] as String?,
      enableSubdomainGateway: json['enableSubdomainGateway'] as bool? ?? false,
      subdomainDNSLinkResolver:
          json['subdomainDNSLinkResolver'] as bool? ?? true,
      subdomainTLSRedirect: json['subdomainTLSRedirect'] as bool? ?? false,
      enableTls: json['enableTls'] as bool? ?? false,
      certificatePath: json['certificatePath'] as String?,
      privateKeyPath: json['privateKeyPath'] as String?,
      certificatePassword: json['certificatePassword'] as String?,
      autoTls: json['autoTls'] as bool? ?? false,
      autoTlsDomain: json['autoTlsDomain'] as String?,
      autoTlsEmail: json['autoTlsEmail'] as String?,
      autoTlsProvider: json['autoTlsProvider'] as String? ?? 'letsencrypt',
      autoTlsAcceptTos: json['autoTlsAcceptTos'] as bool? ?? false,
      autoTlsSANs:
          (json['autoTlsSANs'] as List<dynamic>?)?.cast<String>() ?? const [],
      tlsPort: json['tlsPort'] as int? ?? 443,
      redirectHttpToHttps: json['redirectHttpToHttps'] as bool? ?? false,
    );
  }

  /// Whether the gateway is enabled.
  final bool enabled;

  /// The port the gateway listens on.
  final int port;

  /// The address the gateway listens on.
  final String address;

  /// Whether the gateway is writable (allows POST/PUT).
  final bool writable;

  /// Whether to enable caching for gateway responses.
  final bool enableCache;

  /// The maximum size of the gateway cache in bytes.
  final int cacheSize;

  /// The configured gateway domain for subdomain requests (e.g. `ipfs.example.com`).
  /// When null, only `*.ipfs.localhost` and `*.ipns.localhost` subdomains are
  /// supported.
  final String? gatewayDomain;

  /// Whether subdomain gateway support is enabled.
  final bool enableSubdomainGateway;

  /// Whether DNSLink resolution is enabled for `.ipns` subdomains.
  final bool subdomainDNSLinkResolver;

  /// Whether to redirect HTTP subdomain requests to HTTPS.
  /// Never enabled for `localhost` or `127.0.0.1` to avoid redirect loops.
  final bool subdomainTLSRedirect;

  /// Whether to terminate TLS for HTTPS and WSS gateway traffic.
  final bool enableTls;

  /// Filesystem path to the PEM-encoded TLS certificate.
  final String? certificatePath;

  /// Filesystem path to the PEM-encoded TLS private key.
  final String? privateKeyPath;

  /// Optional password for the encrypted private key file.
  /// Never log this value.
  final String? certificatePassword;

  /// Whether to obtain and renew certificates automatically via ACME.
  /// Off by default and requires explicit [autoTlsAcceptTos].
  final bool autoTls;

  /// Primary domain for the ACME certificate.
  final String? autoTlsDomain;

  /// Contact email for the ACME account.
  final String? autoTlsEmail;

  /// ACME provider name (e.g. `letsencrypt`, `zerossl`).
  final String autoTlsProvider;

  /// Whether the operator has accepted the ACME provider's terms of service.
  /// AutoTLS refuses to run when this is false.
  final bool autoTlsAcceptTos;

  /// Additional subject alternative names for the ACME certificate.
  final List<String> autoTlsSANs;

  /// The port the TLS server listens on.
  final int tlsPort;

  /// Whether the plain HTTP port should redirect all requests to HTTPS.
  /// Only meaningful when [enableTls] is true.
  final bool redirectHttpToHttps;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'port': port,
    'address': address,
    'writable': writable,
    'enableCache': enableCache,
    'cacheSize': cacheSize,
    'gatewayDomain': gatewayDomain,
    'enableSubdomainGateway': enableSubdomainGateway,
    'subdomainDNSLinkResolver': subdomainDNSLinkResolver,
    'subdomainTLSRedirect': subdomainTLSRedirect,
    'enableTls': enableTls,
    'certificatePath': certificatePath,
    'privateKeyPath': privateKeyPath,
    'certificatePassword': certificatePassword,
    'autoTls': autoTls,
    'autoTlsDomain': autoTlsDomain,
    'autoTlsEmail': autoTlsEmail,
    'autoTlsProvider': autoTlsProvider,
    'autoTlsAcceptTos': autoTlsAcceptTos,
    'autoTlsSANs': autoTlsSANs,
    'tlsPort': tlsPort,
    'redirectHttpToHttps': redirectHttpToHttps,
  };
}
