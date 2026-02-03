// src/utils/keystore.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/utils/private_key.dart';

import 'logger.dart';

/// Represents a public/private key pair for cryptographic operations.
class KeyPair {
  /// Creates a new key pair.
  KeyPair(this.publicKey, this.privateKey);

  /// The public key in string format.
  final String publicKey;

  /// The private key in string format.
  final String privateKey;
}

/// In-memory keystore for managing IPNS keys and cryptographic identities.
///
/// The Keystore stores named key pairs used for signing IPNS records,
/// peer identity, and other cryptographic operations.
///
/// Example:
/// ```dart
/// final keystore = Keystore();
/// keystore.addKeyPair('mykey', KeyPair(pubKey, privKey));
///
/// if (keystore.hasKeyPair('mykey')) {
///   final pair = keystore.getKeyPair('mykey');
/// }
/// ```
class Keystore {
  /// Creates an empty keystore.
  Keystore();

  // Named constructor for configuration
  /// Creates a keystore from the provided configuration.
  factory Keystore.withConfig(dynamic config) {
    final keystore = Keystore();
    // Initialize with config
    return keystore;
  }
  final Map<String, KeyPair> _keyPairs = {};
  final _logger = Logger('Keystore');
  final _ed25519 = Ed25519();

  /// The default key name used for node identity.
  static const String defaultKeyName = 'self';

  /// Adds a new key pair to the keystore.
  void addKeyPair(String name, KeyPair keyPair) {
    _keyPairs[name] = keyPair;
    _logger.info('Added key pair for $name.');
  }

  /// Retrieves a key pair by its name.
  KeyPair getKeyPair(String name) {
    final keyPair = _keyPairs[name];
    if (keyPair == null) {
      throw ArgumentError('No key pair found for name: $name');
    }
    return keyPair;
  }

  /// Checks if a key pair exists for the given name.
  bool hasKeyPair(String name) {
    return _keyPairs.containsKey(name);
  }

  /// Removes a key pair from the keystore.
  void removeKeyPair(String name) {
    if (_keyPairs.remove(name) != null) {
      _logger.info('Removed key pair for $name.');
    } else {
      _logger.warning('No key pair found for $name to remove.');
    }
  }

  /// Lists all stored key pairs.
  List<String> listKeyPairs() {
    return _keyPairs.keys.toList();
  }

  /// Serializes the keystore to JSON format (optional).
  String serialize() {
    final jsonMap = _keyPairs.map(
      (name, keyPair) => MapEntry(name, {
        'publicKey': keyPair.publicKey,
        'privateKey': keyPair.privateKey,
      }),
    );
    return jsonEncode(jsonMap);
  }

  /// Deserializes the keystore from JSON format (optional).
  void deserialize(String jsonString) {
    final Map<String, dynamic> jsonMap =
        jsonDecode(jsonString) as Map<String, dynamic>;
    for (final entry in jsonMap.entries) {
      final name = entry.key;
      final keys = entry.value as Map<String, dynamic>;
      addKeyPair(
        name,
        KeyPair(keys['publicKey'] as String, keys['privateKey'] as String),
      );
    }
    _logger.info('Keystore deserialized from JSON.');
  }

  /// Verifies a signature using a public key
  ///
  /// Uses Ed25519 signature verification via pure-Dart cryptography package.
  Future<bool> verifySignature(
    String publicKey,
    Uint8List data,
    Uint8List signature,
  ) async {
    try {
      // Decode the public key from hex/base64
      final pubKeyBytes = _decodePublicKey(publicKey);

      // Create the public key object
      final pubKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);

      // Create the signature object
      final sig = Signature(signature, publicKey: pubKey);

      // Verify the signature
      final isValid = await _ed25519.verify(data, signature: sig);
      return isValid;
    } on ArgumentError catch (e) {
      // Invalid key length or format
      _logger.warning('Invalid key format for verification: ${e.message}');
      return false;
    } catch (e, stackTrace) {
      _logger.error('Error verifying signature', e, stackTrace);
      return false;
    }
  }

  Uint8List _decodePublicKey(String publicKey) {
    // Try to decode as hex first
    if (publicKey.length == 64) {
      // Likely hex-encoded 32-byte key
      final bytes = <int>[];
      for (var i = 0; i < publicKey.length; i += 2) {
        bytes.add(int.parse(publicKey.substring(i, i + 2), radix: 16));
      }
      return Uint8List.fromList(bytes);
    }

    // Try base64
    try {
      return base64Decode(publicKey);
    } catch (e) {
      // Return as bytes
      return Uint8List.fromList(utf8.encode(publicKey));
    }
  }

  /// Getter for the default private key
  IPFSPrivateKey get privateKey {
    final defaultPair = _keyPairs[defaultKeyName];
    if (defaultPair == null) {
      throw StateError('No default key pair found in keystore');
    }
    return IPFSPrivateKey.fromString(defaultPair.privateKey);
  }

  /// Returns all key pairs for migration to encrypted storage.
  ///
  /// **Security Note:** This method is intended for one-time migration
  /// to `EncryptedKeystore`. After migration, keys should be removed
  /// from this plaintext store.
  ///
  /// Returns a map of key names to their private key bytes.
  Map<String, Uint8List> exportKeysForMigration() {
    _logger.warning(
      'Exporting plaintext keys for migration - ensure they are encrypted!',
    );
    final result = <String, Uint8List>{};
    for (final entry in _keyPairs.entries) {
      try {
        // Try base64 decoding first (standard for IPFSPrivateKey)
        result[entry.key] = base64Url.decode(entry.value.privateKey);
      } catch (_) {
        // Fallback to UTF-8 for legacy raw string keys
        result[entry.key] = Uint8List.fromList(
          utf8.encode(entry.value.privateKey),
        );
      }
    }
    return result;
  }

  /// Clears all keys from the plaintext store.
  ///
  /// **Security Note:** Call this after successfully migrating keys
  /// to `EncryptedKeystore` to remove plaintext key material.
  void clearAfterMigration() {
    _keyPairs.clear();
    _logger.info('Plaintext keystore cleared after migration');
  }
}
