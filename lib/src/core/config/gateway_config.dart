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
      };
}
