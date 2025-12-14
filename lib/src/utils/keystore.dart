// src/utils/keystore.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_ipfs/src/utils/private_key.dart';
import 'package:p2plib/p2plib.dart' show Crypto;
import 'logger.dart';

/// Represents a public/private key pair for cryptographic operations.
class KeyPair {
  /// The public key in string format.
  final String publicKey;

  /// The private key in string format.
  final String privateKey;

  /// Creates a new key pair.
  KeyPair(this.publicKey, this.privateKey);
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
  final Map<String, KeyPair> _keyPairs = const {};
  final _logger = Logger('Keystore');

  /// The default key name used for node identity.
  static const String DEFAULT_KEY = 'self';

  /// Creates an empty keystore.
  Keystore();

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
    final jsonMap = _keyPairs.map((name, keyPair) => MapEntry(name, {
          'publicKey': keyPair.publicKey,
          'privateKey': keyPair.privateKey,
        }));
    return jsonEncode(jsonMap);
  }

  /// Deserializes the keystore from JSON format (optional).
  void deserialize(String jsonString) {
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    jsonMap.forEach((name, keys) {
      addKeyPair(name, KeyPair(keys['publicKey'], keys['privateKey']));
    });
    _logger.info('Keystore deserialized from JSON.');
  }

  /// Verifies a signature using a public key
  Future<bool> verifySignature(
      String publicKey, Uint8List data, Uint8List signature) async {
    try {
      // Create crypto instance
      final crypto = Crypto();
      await crypto.init(); // Initialize the crypto worker

      // Construct the datagram in the format expected by p2plib
      // This needs to match the Message format used in p2plib
      final datagram = Uint8List.fromList([
        ...data, // Original message
        ...signature // Signature appended at the end
      ]);

      try {
        // Verify the signature
        await crypto.verify(datagram);
        return true;
      } catch (e) {
        // If verification fails, crypto.verify throws an exception
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Error verifying signature', e, stackTrace);
      return false;
    }
  }

  /// Getter for the default private key
  IPFSPrivateKey get privateKey {
    final defaultPair = _keyPairs[DEFAULT_KEY];
    if (defaultPair == null) {
      throw StateError('No default key pair found in keystore');
    }
    return IPFSPrivateKey.fromString(defaultPair.privateKey);
  }

  // Named constructor for configuration
  factory Keystore.withConfig(dynamic config) {
    final keystore = Keystore();
    // Initialize with config
    return keystore;
  }
}
