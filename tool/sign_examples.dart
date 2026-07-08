// tool/sign_examples.dart
//
// Test-only helper for the v2.2 plugin security model.
//
// Generates an ephemeral Ed25519 key pair, signs the in-repo example plugin
// manifests, and writes the ephemeral public key to a test fixture. The
// private key is discarded after signing and never stored in the repository.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/plugins/plugin_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Directories under [example/plugins] that contain manifests to sign.
const _pluginDirectories = <String>[
  'example/plugins/metrics_emitter',
  'example/plugins/logging_observer',
];

/// Test fixture file to write the ephemeral public key (base64, one line).
const _publicKeyFixture = 'test/fixtures/plugin_test_public_key.base64';

Future<void> main() async {
  final repoRoot = _findRepoRoot(Directory.current.path);
  final signer = Ed25519Signer();
  final keyPair = await signer.generateKeyPair();
  final publicKeyBytes = await signer.extractPublicKeyBytes(keyPair);
  final publicKeyBase64 = base64Encode(publicKeyBytes);

  // Write public key fixture.
  final fixtureFile = File('$repoRoot/$_publicKeyFixture');
  await fixtureFile.create(recursive: true);
  await fixtureFile.writeAsString('$publicKeyBase64\n');
  stdout.writeln('Wrote public key fixture to $_publicKeyFixture');

  // Sign each example plugin manifest.
  for (final dir in _pluginDirectories) {
    final directory = Directory('$repoRoot/$dir');
    final manifestFile = File('${directory.path}/plugin.yaml');
    if (!await manifestFile.exists()) {
      stderr.writeln('Manifest not found: ${manifestFile.path}');
      continue;
    }

    final yaml = await manifestFile.readAsString();
    final manifestMap = _pluginMapFromYaml(yaml);

    // Compute the archive checksum from the plugin files (excluding the
    // manifest itself to avoid circularity). The signature will cover this
    // checksum, so tampering with plugin code after signing will fail.
    final archiveChecksum = await _computeArchiveChecksum(directory.path);

    // Build the canonical manifest bytes including the checksum. This is what
    // the host will verify.
    final manifestMapWithChecksum = {
      ...manifestMap,
      'checksums': {'archive_sha256': archiveChecksum},
    };
    final canonicalBytes = PluginManifest.canonicalBytes(
      manifestMapWithChecksum,
    );

    final signature = await signer.sign(
      Uint8List.fromList(canonicalBytes),
      keyPair,
    );
    final signatureBase64 = base64Encode(signature);

    // Update the YAML with the ephemeral public key, signature, and checksum.
    final updatedYaml = _replaceSignatureAndChecksum(
      yaml,
      publicKey: publicKeyBase64,
      signature: signatureBase64,
      archiveSha256: archiveChecksum,
    );

    await manifestFile.writeAsString(updatedYaml);
    stdout.writeln('Signed ${manifestFile.path}');
  }

  stdout.writeln('Done. Discard the ephemeral private key.');
}

/// Searches upward for the repository root (directory containing pubspec.yaml).
String _findRepoRoot(String start) {
  var dir = Directory(start);
  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not find repository root containing pubspec.yaml',
      );
    }
    dir = parent;
  }
}

/// Extracts the `plugin` map from a YAML string as plain Dart types.
Map<String, dynamic> _pluginMapFromYaml(String yaml) {
  final parsed = loadYaml(yaml);
  if (parsed is! YamlMap) {
    throw const FormatException('Manifest root must be a YAML map');
  }
  final pluginMap = parsed['plugin'];
  if (pluginMap is! YamlMap) {
    throw const FormatException('Missing top-level "plugin" map');
  }
  return _yamlToDart(pluginMap) as Map<String, dynamic>;
}

/// Recursively converts [YamlMap] and [YamlList] to plain Dart collections.
dynamic _yamlToDart(dynamic value) {
  if (value is YamlMap) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _yamlToDart(entry.value),
    };
  }
  if (value is YamlList) {
    return value.map(_yamlToDart).toList();
  }
  return value;
}

/// Computes a SHA-256 checksum of all files in [pluginDirectory] except
/// `plugin.yaml`. File paths are normalized to forward slashes and sorted
/// so the checksum is stable across platforms.
Future<String> _computeArchiveChecksum(String pluginDirectory) async {
  final root = Directory(pluginDirectory);
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

/// Returns a forward-slash relative path of [file] from [root].
String _relativePath(Directory root, File file) {
  return p.relative(file.path, from: root.path).replaceAll(r'\', '/');
}

/// Replaces placeholder signature and checksum fields in the YAML.
String _replaceSignatureAndChecksum(
  String yaml, {
  required String publicKey,
  required String signature,
  required String archiveSha256,
}) {
  return yaml
      .replaceAll(RegExp(r'public_key: "[^"]*"'), 'public_key: "$publicKey"')
      .replaceAll(RegExp(r'signature: "[^"]*"'), 'signature: "$signature"')
      .replaceAll(
        RegExp(r'archive_sha256: "[^"]*"'),
        'archive_sha256: "$archiveSha256"',
      );
}
