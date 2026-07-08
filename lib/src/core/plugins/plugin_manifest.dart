// lib/src/core/plugins/plugin_manifest.dart
//
// Plugin manifest parser and validator for the v2.2 plugin security model.
// Manifests are YAML files describing plugin identity, requested capabilities,
// and an optional Ed25519 signature.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:yaml/yaml.dart';

/// Exception thrown when a plugin manifest is invalid or cannot be parsed.
class PluginManifestException implements Exception {
  /// Creates a [PluginManifestException] with the given [message].
  PluginManifestException(this.message);

  /// Human-readable error description.
  final String message;

  @override
  String toString() => 'PluginManifestException: $message';
}

/// A parsed and validated plugin manifest.
class PluginManifest {
  /// Creates a plugin manifest with all required fields.
  PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.dartIpfsVersion,
    required this.author,
    required this.capabilities,
    required this.hooks,
    required this.entrypoint,
    this.signature,
    this.checksums,
    this.rawYaml,
  });

  /// Parses and validates a YAML manifest string.
  factory PluginManifest.fromYaml(String yaml) {
    final dynamic parsed = loadYaml(yaml);
    if (parsed is! YamlMap) {
      throw PluginManifestException('Manifest root must be a YAML map');
    }

    final pluginMap = parsed['plugin'];
    if (pluginMap is! YamlMap) {
      throw PluginManifestException('Missing top-level "plugin" map');
    }

    final id = _requireString(pluginMap, 'id');
    final name = _requireString(pluginMap, 'name');
    final version = _requireString(pluginMap, 'version');
    final dartIpfsVersion = _requireString(pluginMap, 'dart_ipfs_version');
    final author = _requireString(pluginMap, 'author');
    final entrypoint = _requireString(pluginMap, 'entrypoint');

    final rawCapabilities = pluginMap['capabilities'];
    final capabilities = _parseStringList(rawCapabilities, 'capabilities');

    final rawHooks = pluginMap['hooks'];
    final hooks = _parseStringList(rawHooks, 'hooks');

    if (id.isEmpty || !_looksLikeReverseDns(id)) {
      throw PluginManifestException(
        'id must be a non-empty reverse-DNS identifier (got "$id")',
      );
    }
    if (name.isEmpty) {
      throw PluginManifestException('name must be non-empty');
    }
    if (version.isEmpty) {
      throw PluginManifestException('version must be non-empty');
    }
    if (dartIpfsVersion.isEmpty) {
      throw PluginManifestException('dart_ipfs_version must be non-empty');
    }
    if (entrypoint.isEmpty) {
      throw PluginManifestException('entrypoint must be non-empty');
    }

    PluginSignature? signature;
    final rawSignature = pluginMap['signature'];
    if (rawSignature != null) {
      if (rawSignature is! YamlMap) {
        throw PluginManifestException('signature must be a map');
      }
      signature = PluginSignature(
        algorithm: _requireString(rawSignature, 'algorithm'),
        publicKeyBase64: _requireString(rawSignature, 'public_key'),
        signatureBase64: _requireString(rawSignature, 'signature'),
      );
    }

    Map<String, String>? checksums;
    final rawChecksums = pluginMap['checksums'];
    if (rawChecksums != null) {
      if (rawChecksums is! YamlMap) {
        throw PluginManifestException('checksums must be a map');
      }
      checksums = {
        for (final entry in rawChecksums.entries)
          entry.key.toString(): entry.value.toString(),
      };
    }

    return PluginManifest(
      id: id,
      name: name,
      version: version,
      dartIpfsVersion: dartIpfsVersion,
      author: author,
      capabilities: capabilities,
      hooks: hooks,
      entrypoint: entrypoint,
      signature: signature,
      checksums: checksums,
      rawYaml: yaml,
    );
  }

  /// Reverse-DNS plugin identifier (e.g. `org.dart-ipfs.examples.metrics-emitter`).
  final String id;

  /// Human-readable plugin name.
  final String name;

  /// Plugin version in semantic versioning format.
  final String version;

  /// Supported dart_ipfs version range.
  final String dartIpfsVersion;

  /// Plugin author contact.
  final String author;

  /// Requested capability names (e.g. `metrics.emit`).
  final List<String> capabilities;

  /// Lifecycle hooks the plugin wants to receive.
  final List<String> hooks;

  /// Plugin entrypoint path inside the plugin package.
  final String entrypoint;

  /// Optional Ed25519 signature block.
  final PluginSignature? signature;

  /// Optional content checksums.
  final Map<String, String>? checksums;

  /// The raw YAML string used to create this manifest.
  final String? rawYaml;

  /// Returns `true` if the manifest contains a signature block.
  bool get isSigned => signature != null;

  /// Verifies the manifest's Ed25519 signature against the manifest bytes.
  ///
  /// For Phase 1 the signature is computed over the canonical manifest YAML
  /// bytes. This covers the manifest and checksums declared inside it.
  Future<bool> verifySignature(List<SimplePublicKey> trustedKeys) async {
    final sig = signature;
    if (sig == null) return false;
    if (sig.algorithm != 'ed25519') return false;

    final publicKeyBytes = base64Decode(sig.publicKeyBase64);
    if (publicKeyBytes.length != 32) return false;

    final signatureBytes = base64Decode(sig.signatureBase64);
    if (signatureBytes.length != 64) return false;

    final signer = Ed25519Signer();
    final publicKey = signer.publicKeyFromBytes(
      Uint8List.fromList(publicKeyBytes),
    );

    // Check that the signing public key is in the trusted set.
    final isTrusted = trustedKeys.any((key) {
      if (key.type != publicKey.type) return false;
      return _constantTimeListEquals(
        Uint8List.fromList(key.bytes),
        publicKeyBytes,
      );
    });
    if (!isTrusted) return false;

    final data = _canonicalBytes;
    return signer.verify(Uint8List.fromList(data), signatureBytes, publicKey);
  }

  /// Canonical bytes for signing/verification, excluding the signature block.
  List<int> get _canonicalBytes => canonicalBytes({
    'id': id,
    'name': name,
    'version': version,
    'dart_ipfs_version': dartIpfsVersion,
    'author': author,
    'capabilities': capabilities,
    'hooks': hooks,
    'entrypoint': entrypoint,
    'checksums': checksums,
  });

  /// Returns canonical bytes for a plugin map, excluding the signature block.
  static List<int> canonicalBytes(Map<String, dynamic> pluginMap) {
    final checksums = pluginMap['checksums'] as Map<dynamic, dynamic>?;
    final ordered = <String, dynamic>{
      'id': pluginMap['id'],
      'name': pluginMap['name'],
      'version': pluginMap['version'],
      'dart_ipfs_version': pluginMap['dart_ipfs_version'],
      'author': pluginMap['author'],
      'capabilities': pluginMap['capabilities'],
      'hooks': pluginMap['hooks'],
      'entrypoint': pluginMap['entrypoint'],
      if (checksums != null)
        'checksums': {
          for (final entry in checksums.entries)
            entry.key.toString(): entry.value.toString(),
        },
    };
    return utf8.encode(jsonEncode({'plugin': ordered}));
  }

  static String _requireString(YamlMap map, String key) {
    final value = map[key];
    if (value == null) {
      throw PluginManifestException('Missing required field "$key"');
    }
    if (value is! String) {
      throw PluginManifestException('Field "$key" must be a string');
    }
    return value;
  }

  static List<String> _parseStringList(dynamic value, String field) {
    if (value == null) return [];
    if (value is! YamlList) {
      throw PluginManifestException('Field "$field" must be a list');
    }
    return value.nodes.map((node) => node.value.toString()).toList();
  }

  static bool _looksLikeReverseDns(String id) {
    // Allow reverse-DNS style with dashes and dots; e.g. org.dart-ipfs.examples.x
    return id.split('.').length >= 2 &&
        RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(id);
  }

  static bool _constantTimeListEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

/// Ed25519 signature block attached to a manifest.
class PluginSignature {
  /// Creates a signature block with the given [algorithm], [publicKeyBase64],
  /// and [signatureBase64].
  PluginSignature({
    required this.algorithm,
    required this.publicKeyBase64,
    required this.signatureBase64,
  });

  /// Signature algorithm (e.g. `ed25519`).
  final String algorithm;

  /// Base64-encoded public key used to verify the signature.
  final String publicKeyBase64;

  /// Base64-encoded signature.
  final String signatureBase64;
}
