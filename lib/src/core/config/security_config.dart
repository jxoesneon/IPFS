/// Security-related configuration options for IPFS node
class SecurityConfig {
  /// Creates a new [SecurityConfig] with default encryption and rotation settings.
  const SecurityConfig({
    this.enableTLS = false,
    this.tlsCertificatePath,
    this.tlsPrivateKeyPath,
    this.enableKeyRotation = true,
    this.keyRotationInterval = const Duration(days: 30),
    this.maxAuthAttempts = 3,
    this.enableRateLimiting = true,
    this.maxRequestsPerMinute = 100,
    this.dhtDifficulty = 0, // SEC-005: Default disabled
    this.enableDenylist = false,
    this.denylistPath,
    this.denylistStoragePath,
    this.denylistRefreshInterval = const Duration(hours: 1),
    this.denylistCompactFormat = true,
    this.denylistDefaultAction = 'block',
  });

  /// Creates a [SecurityConfig] from a JSON map.
  factory SecurityConfig.fromJson(Map<String, dynamic> json) {
    return SecurityConfig(
      enableTLS: json['enableTLS'] as bool? ?? false,
      tlsCertificatePath: json['tlsCertificatePath'] as String?,
      tlsPrivateKeyPath: json['tlsPrivateKeyPath'] as String?,
      enableKeyRotation: json['enableKeyRotation'] as bool? ?? true,
      keyRotationInterval: Duration(
        days: json['keyRotationDays'] as int? ?? 30,
      ),
      maxAuthAttempts: json['maxAuthAttempts'] as int? ?? 3,
      enableRateLimiting: json['enableRateLimiting'] as bool? ?? true,
      maxRequestsPerMinute: json['maxRequestsPerMinute'] as int? ?? 100,
      dhtDifficulty: json['dhtDifficulty'] as int? ?? 0,
      enableDenylist: json['enableDenylist'] as bool? ?? false,
      denylistPath: json['denylistPath'] as String?,
      denylistStoragePath: json['denylistStoragePath'] as String?,
      denylistRefreshInterval: json['denylistRefreshIntervalSeconds'] != null
          ? Duration(seconds: json['denylistRefreshIntervalSeconds'] as int)
          : const Duration(hours: 1),
      denylistCompactFormat: json['denylistCompactFormat'] as bool? ?? true,
      denylistDefaultAction:
          json['denylistDefaultAction'] as String? ?? 'block',
    );
  }

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

  /// SEC-005: Static PoW difficulty for DHT Sybil protection (number of zero bits)
  final int dhtDifficulty;

  /// Whether the operator-controlled content denylist is enabled.
  final bool enableDenylist;

  /// Local file path or HTTP(S) URL to the denylist source.
  final String? denylistPath;

  /// Optional local path for a persistent cached copy of the denylist.
  final String? denylistStoragePath;

  /// Interval between automatic denylist refreshes.
  final Duration denylistRefreshInterval;

  /// Whether the denylist source uses the BadBits-style compact format.
  final bool denylistCompactFormat;

  /// Default action for denylist hits: `"block"` or `"log"`.
  final String denylistDefaultAction;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enableTLS': enableTLS,
    'tlsCertificatePath': tlsCertificatePath,
    'tlsPrivateKeyPath': tlsPrivateKeyPath,
    'enableKeyRotation': enableKeyRotation,
    'keyRotationDays': keyRotationInterval.inDays,
    'maxAuthAttempts': maxAuthAttempts,
    'enableRateLimiting': enableRateLimiting,
    'maxRequestsPerMinute': maxRequestsPerMinute,
    'dhtDifficulty': dhtDifficulty,
    'enableDenylist': enableDenylist,
    'denylistPath': denylistPath,
    'denylistStoragePath': denylistStoragePath,
    'denylistRefreshIntervalSeconds': denylistRefreshInterval.inSeconds,
    'denylistCompactFormat': denylistCompactFormat,
    'denylistDefaultAction': denylistDefaultAction,
  };
}
