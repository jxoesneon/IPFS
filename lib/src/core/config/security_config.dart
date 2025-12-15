/// Security-related configuration options for IPFS node
class SecurityConfig {
  /// Whether to enable TLS for secure communication
  final bool enableTLS;

  /// The path to the TLS certificate file
  final String? tlsCertificatePath;

  /// The path to the TLS private key file
  final String? tlsPrivateKeyPath;

  /// Whether to enable key rotation
  final bool enableKeyRotation;

  /// Key rotation interval
  final Duration keyRotationInterval;

  /// Maximum number of authentication attempts
  final int maxAuthAttempts;

  /// Whether to enable request rate limiting
  final bool enableRateLimiting;

  /// Maximum requests per minute
  final int maxRequestsPerMinute;

  const SecurityConfig({
    this.enableTLS = false,
    this.tlsCertificatePath,
    this.tlsPrivateKeyPath,
    this.enableKeyRotation = true,
    this.keyRotationInterval = const Duration(days: 30),
    this.maxAuthAttempts = 3,
    this.enableRateLimiting = true,
    this.maxRequestsPerMinute = 100,
  });

  factory SecurityConfig.fromJson(Map<String, dynamic> json) {
    return SecurityConfig(
      enableTLS: json['enableTLS'] ?? false,
      tlsCertificatePath: json['tlsCertificatePath'],
      tlsPrivateKeyPath: json['tlsPrivateKeyPath'],
      enableKeyRotation: json['enableKeyRotation'] ?? true,
      keyRotationInterval: Duration(days: json['keyRotationDays'] ?? 30),
      maxAuthAttempts: json['maxAuthAttempts'] ?? 3,
      enableRateLimiting: json['enableRateLimiting'] ?? true,
      maxRequestsPerMinute: json['maxRequestsPerMinute'] ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
    'enableTLS': enableTLS,
    'tlsCertificatePath': tlsCertificatePath,
    'tlsPrivateKeyPath': tlsPrivateKeyPath,
    'enableKeyRotation': enableKeyRotation,
    'keyRotationDays': keyRotationInterval.inDays,
    'maxAuthAttempts': maxAuthAttempts,
    'enableRateLimiting': enableRateLimiting,
    'maxRequestsPerMinute': maxRequestsPerMinute,
  };
}
