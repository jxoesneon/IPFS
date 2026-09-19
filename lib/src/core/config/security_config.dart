/// Security-related configuration options for IPFS node
class SecurityConfig {
  /// Creates a new [SecurityConfig] with default encryption and rotation settings.
  const SecurityConfig({
    @Deprecated(
      'No listener terminates TLS via this config; enabling it only '
      'validates that the certificate files exist. This option is ignored.',
    )
    this.enableTLS = false,
    @Deprecated(
      'No listener terminates TLS via this config; see enableTLS. '
      'This option is ignored.',
    )
    this.tlsCertificatePath,
    @Deprecated(
      'No listener terminates TLS via this config; see enableTLS. '
      'This option is ignored.',
    )
    this.tlsPrivateKeyPath,
    @Deprecated('Key rotation is not implemented; this flag is ignored.')
    this.enableKeyRotation = true,
    @Deprecated('Key rotation is not implemented; this flag is ignored.')
    this.keyRotationInterval = const Duration(days: 30),
    @Deprecated(
      'No live code path enforces authentication attempt limits; '
      'this option is ignored.',
    )
    this.maxAuthAttempts = 3,
    @Deprecated(
      'No live code path enforces rate limiting; '
      'this option is ignored.',
    )
    this.enableRateLimiting = true,
    @Deprecated(
      'No live code path enforces rate limiting; '
      'this option is ignored.',
    )
    this.maxRequestsPerMinute = 100,
    this.dhtDifficulty = 0, // SEC-005: Default disabled
    this.enableDenylist = false,
    this.denylistPath,
    this.denylistStoragePath,
    this.denylistRefreshInterval = const Duration(hours: 1),
    @Deprecated(
      'The denylist loader auto-detects the source format; '
      'this option is ignored.',
    )
    this.denylistCompactFormat = true,
    this.denylistDefaultAction = 'block',
  });

  /// Creates a [SecurityConfig] from a JSON map.
  factory SecurityConfig.fromJson(Map<String, dynamic> json) {
    return SecurityConfig(
      // ignore: deprecated_member_use_from_same_package
      enableTLS: json['enableTLS'] as bool? ?? false,
      // ignore: deprecated_member_use_from_same_package
      tlsCertificatePath: json['tlsCertificatePath'] as String?,
      // ignore: deprecated_member_use_from_same_package
      tlsPrivateKeyPath: json['tlsPrivateKeyPath'] as String?,
      // ignore: deprecated_member_use_from_same_package
      enableKeyRotation: json['enableKeyRotation'] as bool? ?? true,
      // ignore: deprecated_member_use_from_same_package
      keyRotationInterval: Duration(
        days: json['keyRotationDays'] as int? ?? 30,
      ),
      // ignore: deprecated_member_use_from_same_package
      maxAuthAttempts: json['maxAuthAttempts'] as int? ?? 3,
      // ignore: deprecated_member_use_from_same_package
      enableRateLimiting: json['enableRateLimiting'] as bool? ?? true,
      // ignore: deprecated_member_use_from_same_package
      maxRequestsPerMinute: json['maxRequestsPerMinute'] as int? ?? 100,
      dhtDifficulty: json['dhtDifficulty'] as int? ?? 0,
      enableDenylist: json['enableDenylist'] as bool? ?? false,
      denylistPath: json['denylistPath'] as String?,
      denylistStoragePath: json['denylistStoragePath'] as String?,
      denylistRefreshInterval: json['denylistRefreshIntervalSeconds'] != null
          ? Duration(seconds: json['denylistRefreshIntervalSeconds'] as int)
          : const Duration(hours: 1),
      // ignore: deprecated_member_use_from_same_package
      denylistCompactFormat: json['denylistCompactFormat'] as bool? ?? true,
      denylistDefaultAction:
          json['denylistDefaultAction'] as String? ?? 'block',
    );
  }

  /// Whether to enable TLS for secure communication
  ///
  /// Ignored: no listener terminates TLS via this config; enabling it only
  /// validates that the certificate files exist.
  final bool enableTLS;

  /// The path to the TLS certificate file
  ///
  /// Ignored: see [enableTLS].
  final String? tlsCertificatePath;

  /// The path to the TLS private key file
  ///
  /// Ignored: see [enableTLS].
  final String? tlsPrivateKeyPath;

  /// Whether to enable key rotation
  ///
  /// Ignored: key rotation is not implemented; enabling it only logs a
  /// warning at startup.
  final bool enableKeyRotation;

  /// Key rotation interval
  ///
  /// Ignored: see [enableKeyRotation].
  final Duration keyRotationInterval;

  /// Maximum number of authentication attempts
  ///
  /// Ignored: no live code path enforces authentication attempt limits.
  final int maxAuthAttempts;

  /// Whether to enable request rate limiting
  ///
  /// Ignored: no live code path enforces rate limiting.
  final bool enableRateLimiting;

  /// Maximum requests per minute
  ///
  /// Ignored: no live code path enforces rate limiting.
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
  ///
  /// Ignored: the denylist loader auto-detects the source format.
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
