// test/core/plugins/plugin_security_test.dart
//
// Tests for the v2.2 plugin security model: signed/unsigned trust policy,
// capability ACLs, and audit logging.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/plugins/capability_exception.dart';
import 'package:dart_ipfs/src/core/plugins/capability_registry.dart';
import 'package:dart_ipfs/src/core/plugins/plugin_host.dart';
import 'package:dart_ipfs/src/core/plugins/plugin_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repo root not found');
    }
    dir = parent;
  }
}

String _fixturePath(String relative) => '${_repoRoot()}/$relative';

PluginHost _createHost({
  required bool enabled,
  String? trustedKeysPath,
  bool allowUnsigned = false,
}) {
  final config = PluginHostConfig(
    enabled: enabled,
    trustedKeysPath: trustedKeysPath,
    allowUnsigned: allowUnsigned,
  );
  return PluginHost(config: config, metrics: MetricsCollector(IPFSConfig()));
}

const _unsignedMetricsManifest = '''
plugin:
  id: org.dart-ipfs.examples.unsigned-metrics-emitter
  name: Unsigned Metrics Emitter
  version: 1.0.0
  dart_ipfs_version: ">=2.2.0 <2.3.0"
  author: "Dart IPFS Contributors <security@dart-ipfs.invalid>"
  capabilities:
    - metrics.emit
  hooks:
    - on_metrics_flush
  entrypoint: main.dart
''';

const _unsignedNoMetricsManifest = '''
plugin:
  id: org.dart-ipfs.examples.no-metrics
  name: No Metrics Plugin
  version: 1.0.0
  dart_ipfs_version: ">=2.2.0 <2.3.0"
  author: "Dart IPFS Contributors <security@dart-ipfs.invalid>"
  capabilities:
    - network.bitswap.observe
  hooks:
    - on_bitswap_message
  entrypoint: main.dart
''';

/// Temporary plugin fixture used for archive-checksum tests.
class _TempPlugin {
  _TempPlugin(this.pluginMap, this.yaml);
  final Map<String, dynamic> pluginMap;
  final String yaml;
}

/// Creates a small plugin on disk and returns its map and YAML.
Future<_TempPlugin> _createTempPlugin(
  Directory pluginDir, {
  required String id,
  required List<String> capabilities,
}) async {
  await pluginDir.create(recursive: true);
  await File('${pluginDir.path}/main.dart').writeAsString('''
// Temporary plugin for testing.
class TempPlugin {}
''');

  final pluginMap = <String, dynamic>{
    'id': id,
    'name': 'Temp Plugin',
    'version': '1.0.0',
    'dart_ipfs_version': '>=2.2.0 <2.3.0',
    'author': 'Test',
    'capabilities': capabilities,
    'hooks': ['on_metrics_flush'],
    'entrypoint': 'main.dart',
  };

  final yaml =
      '''
plugin:
  id: $id
  name: Temp Plugin
  version: 1.0.0
  dart_ipfs_version: ">=2.2.0 <2.3.0"
  author: "Test"
  capabilities:
${capabilities.map((c) => '    - $c').join('\n')}
  hooks:
    - on_metrics_flush
  entrypoint: main.dart
  signature:
    algorithm: ed25519
    public_key: ""
    signature: ""
  checksums:
    archive_sha256: ""
''';

  await File('${pluginDir.path}/plugin.yaml').writeAsString(yaml);
  return _TempPlugin(pluginMap, yaml);
}

/// Signs a manifest with a fresh Ed25519 key and returns the signed YAML.
Future<String> _signPluginManifest(
  String pluginDir,
  Map<String, dynamic> pluginMap,
  String manifestYaml,
  SimpleKeyPair keyPair,
  Ed25519Signer signer,
) async {
  final checksum = await _computeArchiveChecksum(pluginDir);
  final manifestMapWithChecksum = {
    ...pluginMap,
    'checksums': {'archive_sha256': checksum},
  };
  final canonicalBytes = PluginManifest.canonicalBytes(manifestMapWithChecksum);
  final signature = await signer.sign(
    Uint8List.fromList(canonicalBytes),
    keyPair,
  );
  final publicKey = await signer.extractPublicKeyBytes(keyPair);

  return manifestYaml
      .replaceAll(
        RegExp(r'public_key: "[^"]*"'),
        'public_key: "${base64Encode(publicKey)}"',
      )
      .replaceAll(
        RegExp(r'signature: "[^"]*"'),
        'signature: "${base64Encode(signature)}"',
      )
      .replaceAll(
        RegExp(r'archive_sha256: "[^"]*"'),
        'archive_sha256: "$checksum"',
      );
}

/// Computes a stable SHA-256 checksum of all plugin files except the manifest.
Future<String> _computeArchiveChecksum(String pluginDir) async {
  final root = Directory(pluginDir);
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => p.basename(f.path) != 'plugin.yaml')
      .toList();
  files.sort(
    (a, b) => _relativePath(root, a).compareTo(_relativePath(root, b)),
  );
  final builder = BytesBuilder();
  for (final file in files) {
    final relativePath = _relativePath(root, file);
    builder.add(utf8.encode(relativePath));
    builder.add(const [0]);
    builder.add(await file.readAsBytes());
    builder.add(const [0]);
  }
  return sha256.convert(builder.toBytes()).toString();
}

String _relativePath(Directory root, File file) {
  return p.relative(file.path, from: root.path).replaceAll(r'\', '/');
}

void main() {
  group('PluginHost signed plugin trust', () {
    test('signed plugin loads when trusted', () async {
      final fixture = _fixturePath(
        'test/fixtures/plugin_test_public_key.base64',
      );
      final host = _createHost(enabled: true, trustedKeysPath: fixture);
      await host.initialize();

      final pluginDir = _fixturePath('example/plugins/metrics_emitter');
      final loaded = await host.loadPluginFromDirectory(pluginDir);

      expect(loaded, isNotNull);
      expect(loaded!.manifest.id, 'org.dart-ipfs.examples.metrics-emitter');
      expect(loaded.disabled, isFalse);
      expect(loaded.grantedCapabilities, contains('metrics.emit'));

      final audit = host.auditLog.forPlugin(
        'org.dart-ipfs.examples.metrics-emitter',
      );
      expect(audit.last.outcome, 'loaded-signed');
    });

    test('signed plugin fails when key is not trusted', () async {
      final host = _createHost(enabled: true);
      await host.initialize();

      final pluginDir = _fixturePath('example/plugins/metrics_emitter');
      final loaded = await host.loadPluginFromDirectory(pluginDir);

      expect(loaded, isNull);
    });
  });

  group('PluginHost archive checksum verification', () {
    test('tampered plugin archive fails after valid signature', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'plugin_security_test',
      );
      final pluginDir = Directory('${tempDir.path}/temp_plugin');

      final plugin = await _createTempPlugin(
        pluginDir,
        id: 'org.dart-ipfs.test.temp',
        capabilities: ['metrics.emit'],
      );

      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKeyBytes = await signer.extractPublicKeyBytes(keyPair);
      final trustedKeyFile = File('${tempDir.path}/trusted_key.base64');
      await trustedKeyFile.writeAsString('${base64Encode(publicKeyBytes)}\n');

      final signedYaml = await _signPluginManifest(
        pluginDir.path,
        plugin.pluginMap,
        plugin.yaml,
        keyPair,
        signer,
      );
      await File('${pluginDir.path}/plugin.yaml').writeAsString(signedYaml);

      // Untampered plugin should load.
      final host = _createHost(
        enabled: true,
        trustedKeysPath: trustedKeyFile.path,
      );
      await host.initialize();
      final loaded = await host.loadPluginFromDirectory(pluginDir.path);
      expect(loaded, isNotNull);
      expect(loaded!.manifest.id, 'org.dart-ipfs.test.temp');

      // Tamper with the plugin code.
      final mainFile = File('${pluginDir.path}/main.dart');
      await mainFile.writeAsString(
        '// tampered\n${await mainFile.readAsString()}',
      );

      // A new host should now reject the plugin because the archive checksum
      // no longer matches the signed manifest.
      final host2 = _createHost(
        enabled: true,
        trustedKeysPath: trustedKeyFile.path,
      );
      await host2.initialize();
      final loaded2 = await host2.loadPluginFromDirectory(pluginDir.path);
      expect(loaded2, isNull);

      final audit = host2.auditLog.forPlugin('org.dart-ipfs.test.temp');
      expect(audit.any((e) => e.reason == 'archive checksum mismatch'), isTrue);

      await tempDir.delete(recursive: true);
    });
  });

  group('PluginHost unsigned plugin policy', () {
    test('unsigned plugin fails by default', () async {
      final host = _createHost(enabled: true);
      await host.initialize();

      final loaded = await host.loadPluginFromYaml(_unsignedMetricsManifest);

      expect(loaded, isNull);
      final audit = host.auditLog.forPlugin(
        'org.dart-ipfs.examples.unsigned-metrics-emitter',
      );
      expect(audit.last.outcome, 'rejected');
      expect(audit.last.reason, 'unsigned plugin not allowed');
    });

    test(
      'unsigned plugin loads with allowUnsigned=true and logs a warning',
      () async {
        final host = _createHost(enabled: true, allowUnsigned: true);
        await host.initialize();

        final loaded = await host.loadPluginFromYaml(_unsignedMetricsManifest);

        expect(loaded, isNotNull);
        expect(
          loaded!.manifest.id,
          'org.dart-ipfs.examples.unsigned-metrics-emitter',
        );
        expect(loaded.disabled, isFalse);

        final audit = host.auditLog.forPlugin(
          'org.dart-ipfs.examples.unsigned-metrics-emitter',
        );
        expect(audit.last.outcome, 'loaded-unsigned');
        expect(audit.last.reason, 'allowUnsigned=true');
      },
    );
  });

  group('PluginHost capability enforcement', () {
    test(
      'capability violation throws CapabilityException and disables the plugin',
      () async {
        final host = _createHost(enabled: true, allowUnsigned: true);
        await host.initialize();

        // Load a plugin that does NOT have metrics.emit.
        final loaded = await host.loadPluginFromYaml(
          _unsignedNoMetricsManifest,
        );
        expect(loaded, isNotNull);
        expect(loaded!.manifest.id, 'org.dart-ipfs.examples.no-metrics');
        expect(loaded.grantedCapabilities, isNot(contains('metrics.emit')));

        final emitter = host.metricsEmitterFor(
          'org.dart-ipfs.examples.no-metrics',
        );
        expect(emitter, isNotNull);

        expect(
          () => emitter!.emitCounter('test_counter'),
          throwsA(isA<CapabilityException>()),
        );

        expect(loaded.disabled, isTrue);
        final audit = host.auditLog.forPlugin(
          'org.dart-ipfs.examples.no-metrics',
        );
        expect(audit.any((e) => e.outcome == 'disabled'), isTrue);
      },
    );

    test('granted capability allows metric emission', () async {
      final fixture = _fixturePath(
        'test/fixtures/plugin_test_public_key.base64',
      );
      final host = _createHost(enabled: true, trustedKeysPath: fixture);
      await host.initialize();

      final pluginDir = _fixturePath('example/plugins/metrics_emitter');
      final loaded = await host.loadPluginFromDirectory(pluginDir);
      expect(loaded, isNotNull);

      final emitter = host.metricsEmitterFor(
        'org.dart-ipfs.examples.metrics-emitter',
      );
      expect(emitter, isNotNull);

      expect(() => emitter!.emitCounter('allowed_counter'), returnsNormally);
      expect(loaded!.disabled, isFalse);
    });
  });

  group('CapabilityRegistry', () {
    test('unknown capabilities are rejected', () {
      final registry = CapabilityRegistry();
      expect(
        registry.unknownCapabilities(['metrics.emit', 'invalid.capability']),
        equals(['invalid.capability']),
      );
    });

    test('require throws CapabilityException for ungranted capability', () {
      final registry = CapabilityRegistry();
      expect(
        () => registry.require('test-plugin', 'metrics.emit', {}),
        throwsA(
          isA<CapabilityException>().having(
            (e) => e.outcome,
            'outcome',
            'denied',
          ),
        ),
      );
    });
  });
}
