// lib/src/core/plugins/plugin_host.dart
//
// Optional, higher-level plugin loader for the v2.2 plugin security model.
// The host validates manifests, verifies Ed25519 signatures, enforces
// deny-by-default capability ACLs, and routes the lifecycle of in-process
// plugins. It never exposes raw IPFSNode, BlockStore, NetworkHandler, or
// SecurityManager references to a plugin.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/plugins/ipfs_plugin.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:path/path.dart' as p;

import 'capability_metrics_emitter.dart';
import 'capability_registry.dart';
import 'plugin_audit_log.dart';
import 'plugin_manifest.dart';

/// Configuration for the optional plugin host.
class PluginHostConfig {
  /// Creates a plugin host configuration.
  const PluginHostConfig({
    this.enabled = false,
    this.trustedKeysPath,
    this.allowUnsigned = false,
    this.pluginDirectories = const [],
  });

  /// Creates a configuration from a JSON map.
  factory PluginHostConfig.fromJson(Map<String, dynamic> json) {
    return PluginHostConfig(
      enabled: json['enabled'] as bool? ?? false,
      trustedKeysPath: json['trustedKeysPath'] as String?,
      allowUnsigned: json['allowUnsigned'] as bool? ?? false,
      pluginDirectories:
          (json['pluginDirectories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Whether the plugin host is enabled.
  final bool enabled;

  /// Path to a file containing trusted Ed25519 public keys (base64 lines).
  final String? trustedKeysPath;

  /// Whether unsigned plugins may be loaded (with a warning).
  final bool allowUnsigned;

  /// Directories to scan for plugins.
  final List<String> pluginDirectories;

  /// Returns this configuration as a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'trustedKeysPath': trustedKeysPath,
    'allowUnsigned': allowUnsigned,
    'pluginDirectories': pluginDirectories,
  };
}

/// State of a loaded plugin.
class LoadedPlugin {
  /// Creates a loaded plugin state.
  LoadedPlugin({
    required this.manifest,
    required this.grantedCapabilities,
    this.plugin,
    this.disabled = false,
  });

  /// The parsed plugin manifest.
  final PluginManifest manifest;

  /// Capabilities granted to this plugin.
  final Set<String> grantedCapabilities;

  /// The instantiated plugin, if available.
  IPFSPlugin? plugin;

  /// Whether the plugin has been disabled due to a violation.
  bool disabled;

  /// Disables the plugin after a capability violation.
  void disable() => disabled = true;
}

/// The plugin host validates, loads, and manages in-process plugins.
class PluginHost {
  /// Creates a plugin host with the given configuration and metrics collector.
  PluginHost({
    required this.config,
    required MetricsCollector metrics,
    PluginAuditLog? auditLog,
    CapabilityRegistry? capabilityRegistry,
    Ed25519Signer? signer,
  }) : _metrics = metrics,
       _auditLog = auditLog ?? PluginAuditLog(),
       _signer = signer ?? Ed25519Signer(),
       _logger = Logger('PluginHost', debug: true) {
    _registry = capabilityRegistry ?? CapabilityRegistry(auditLog: _auditLog);
  }

  /// The plugin host configuration.
  final PluginHostConfig config;

  final MetricsCollector _metrics;
  final PluginAuditLog _auditLog;
  late final CapabilityRegistry _registry;
  final Ed25519Signer _signer;
  final Logger _logger;
  final List<LoadedPlugin> _plugins = [];
  final List<SimplePublicKey> _trustedKeys = [];

  /// Returns loaded plugins (including disabled ones).
  List<LoadedPlugin> get loadedPlugins => List.unmodifiable(_plugins);

  /// Returns the audit log.
  PluginAuditLog get auditLog => _auditLog;

  /// Returns the capability registry.
  CapabilityRegistry get registry => _registry;

  /// Initializes the host by loading trusted keys and scanning plugins.
  Future<void> initialize() async {
    _logger.info('Initializing PluginHost (enabled=${config.enabled})');
    if (!config.enabled) {
      return;
    }

    await _loadTrustedKeys();
    _logger.info('Loaded ${_trustedKeys.length} trusted key(s)');

    for (final dir in config.pluginDirectories) {
      await _loadPluginsFromDirectory(dir);
    }
  }

  /// Starts all loaded plugins.
  Future<void> startAll() async {
    for (final loaded in _plugins) {
      if (loaded.disabled) continue;
      final plugin = loaded.plugin;
      if (plugin != null) {
        await plugin.onStart(_NullIpfsNode());
      }
    }
  }

  /// Stops all loaded plugins.
  Future<void> stopAll() async {
    for (final loaded in _plugins) {
      if (loaded.disabled) continue;
      final plugin = loaded.plugin;
      if (plugin != null) {
        await plugin.onStop(_NullIpfsNode());
      }
    }
  }

  /// Loads a plugin from a directory containing a `plugin.yaml` manifest.
  Future<LoadedPlugin?> loadPluginFromDirectory(String directory) async {
    final manifestPath = '$directory/plugin.yaml';
    final file = File(manifestPath);
    if (!await file.exists()) {
      _logger.warning('Plugin manifest not found: $manifestPath');
      return null;
    }

    final yaml = await file.readAsString();
    return loadPluginFromYaml(yaml, directory: directory);
  }

  /// Loads a plugin from a manifest YAML string.
  ///
  /// If [directory] is provided, the archive checksum is verified against the
  /// files on disk (excluding the manifest itself).
  Future<LoadedPlugin?> loadPluginFromYaml(
    String yaml, {
    String? directory,
  }) async {
    late final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromYaml(yaml);
    } on PluginManifestException catch (e) {
      _logger.warning('Invalid plugin manifest: ${e.message}');
      return null;
    }

    _logger.info('Loading plugin ${manifest.id} (${manifest.name})');

    // Validate capabilities against the known set.
    final unknown = _registry.unknownCapabilities(manifest.capabilities);
    if (unknown.isNotEmpty) {
      _logger.warning(
        'Plugin ${manifest.id} requested unknown capabilities: $unknown',
      );
      _registry.recordLoadOutcome(
        manifest.id,
        outcome: 'rejected',
        reason: 'unknown capabilities: ${unknown.join(', ')}',
      );
      return null;
    }

    // Signature / trust policy.
    if (manifest.isSigned) {
      final valid = await manifest.verifySignature(_trustedKeys);
      if (!valid) {
        _logger.warning(
          'Plugin ${manifest.id} signature is invalid or untrusted',
        );
        _registry.recordLoadOutcome(
          manifest.id,
          outcome: 'rejected',
          reason: 'signature invalid or key not trusted',
        );
        return null;
      }
    } else {
      if (!config.allowUnsigned) {
        _logger.warning(
          'Plugin ${manifest.id} is unsigned and allowUnsigned is false',
        );
        _registry.recordLoadOutcome(
          manifest.id,
          outcome: 'rejected',
          reason: 'unsigned plugin not allowed',
        );
        return null;
      }
      _logger.warning(
        'Loading unsigned plugin ${manifest.id}; this is deprecated',
      );
    }

    // Verify the plugin archive checksum if a directory was provided.
    if (directory != null) {
      final archiveValid = await _verifyArchiveChecksum(directory, manifest);
      if (!archiveValid) {
        _logger.warning('Plugin ${manifest.id} archive checksum mismatch');
        _registry.recordLoadOutcome(
          manifest.id,
          outcome: 'rejected',
          reason: 'archive checksum mismatch',
        );
        return null;
      }
    }

    final loaded = LoadedPlugin(
      manifest: manifest,
      grantedCapabilities: manifest.capabilities.toSet(),
    );
    _plugins.add(loaded);

    _registry.recordLoadOutcome(
      manifest.id,
      outcome: manifest.isSigned ? 'loaded-signed' : 'loaded-unsigned',
      reason: manifest.isSigned ? null : 'allowUnsigned=true',
    );

    _logger.info('Plugin ${manifest.id} loaded successfully');
    return loaded;
  }

  /// Creates a capability-gated metrics emitter for the plugin with [pluginId].
  ///
  /// Returns `null` if the plugin is not loaded or disabled.
  CapabilityMetricsEmitter? metricsEmitterFor(String pluginId) {
    final loaded = _plugins.firstWhere(
      (p) => p.manifest.id == pluginId,
      orElse: () => LoadedPlugin(
        manifest: PluginManifest(
          id: '',
          name: '',
          version: '',
          dartIpfsVersion: '',
          author: '',
          capabilities: const [],
          hooks: const [],
          entrypoint: '',
        ),
        grantedCapabilities: const {},
      ),
    );
    if (loaded.manifest.id.isEmpty || loaded.disabled) {
      return null;
    }
    return CapabilityMetricsEmitter(
      pluginId,
      _metrics,
      _registry,
      loaded.grantedCapabilities,
      onViolation: disablePlugin,
    );
  }

  /// Disables a plugin after a capability violation.
  void disablePlugin(String pluginId) {
    final loaded = _plugins.firstWhere(
      (p) => p.manifest.id == pluginId,
      orElse: () => LoadedPlugin(
        manifest: PluginManifest(
          id: '',
          name: '',
          version: '',
          dartIpfsVersion: '',
          author: '',
          capabilities: const [],
          hooks: const [],
          entrypoint: '',
        ),
        grantedCapabilities: const {},
      ),
    );
    if (loaded.manifest.id.isNotEmpty) {
      loaded.disable();
      _logger.warning('Plugin $pluginId disabled due to capability violation');
      _auditLog.record(
        pluginId: pluginId,
        capability: 'plugin.disabled',
        outcome: 'disabled',
        reason: 'capability violation',
      );
    }
  }

  Future<void> _loadTrustedKeys() async {
    _trustedKeys.clear();
    final path = config.trustedKeysPath;
    if (path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      _logger.warning('Trusted keys file not found: $path');
      return;
    }

    final lines = await file.readAsLines();
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      try {
        final bytes = base64Decode(line);
        if (bytes.length == 32) {
          _trustedKeys.add(
            _signer.publicKeyFromBytes(Uint8List.fromList(bytes)),
          );
        } else {
          _logger.warning('Invalid trusted key length: ${bytes.length}');
        }
      } on FormatException catch (e) {
        _logger.warning('Invalid trusted key line: $line', e);
      }
    }
  }

  Future<void> _loadPluginsFromDirectory(String dir) async {
    final directory = Directory(dir);
    if (!await directory.exists()) {
      _logger.warning('Plugin directory does not exist: $dir');
      return;
    }

    await for (final entity in directory.list()) {
      if (entity is Directory) {
        await loadPluginFromDirectory(entity.path);
      }
    }
  }

  /// Verifies the plugin archive checksum declared in [manifest] against the
  /// files in [directory]. The manifest file (`plugin.yaml`) is excluded from
  /// the hash so the signature can cover the checksum without circularity.
  Future<bool> _verifyArchiveChecksum(
    String directory,
    PluginManifest manifest,
  ) async {
    final checksum = manifest.checksums?['archive_sha256'];
    if (checksum == null || checksum.isEmpty) {
      return true;
    }

    final dir = Directory(directory);
    if (!await dir.exists()) {
      return false;
    }

    final expected = checksum.toLowerCase();
    final builder = BytesBuilder();
    final files = await dir
        .list(recursive: true)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort(
      (a, b) => _relativePath(dir, a).compareTo(_relativePath(dir, b)),
    );

    for (final file in files) {
      final relativePath = _relativePath(dir, file);
      if (relativePath == 'plugin.yaml') continue;
      builder.add(utf8.encode(relativePath));
      builder.add(const [0]);
      builder.add(await file.readAsBytes());
      builder.add(const [0]);
    }

    final actual = sha256.convert(builder.toBytes()).toString();
    return actual == expected;
  }

  /// Returns a forward-slash relative path of [file] from [root].
  static String _relativePath(Directory root, File file) {
    return p.relative(file.path, from: root.path).replaceAll(r'\', '/');
  }
}

/// A placeholder [IPFSNode] that exposes no real services.
///
/// The v2.2 plugin host never exposes raw node references to plugins. The
/// legacy [IPFSPlugin] lifecycle methods still receive a node argument, so we
/// pass a null-safe stand-in that throws if any real service is accessed.
class _NullIpfsNode implements IPFSNode {
  @override
  Never noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'PluginHost does not expose raw IPFSNode services to plugins',
    );
  }
}
