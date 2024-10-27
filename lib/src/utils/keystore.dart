// lib/src/utils/keystore.dart

import 'dart:convert';

class KeyPair {
  final String publicKey;
  final String privateKey;

  KeyPair(this.publicKey, this.privateKey);
}

/// A simple in-memory keystore for managing IPNS key pairs.
class Keystore {
  final Map<String, KeyPair> _keyPairs = {};

  Keystore(config);

  /// Adds a new key pair to the keystore.
  void addKeyPair(String name, KeyPair keyPair) {
    _keyPairs[name] = keyPair;
    print('Added key pair for $name.');
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
      print('Removed key pair for $name.');
    } else {
      print('No key pair found for $name to remove.');
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
    print('Keystore deserialized from JSON.');
  }
}