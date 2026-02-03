import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Interface for SecurityManager to allow platform-agnostic implementations.
abstract class ISecurityManager {
  /// Whether the keystore is currently unlocked.
  bool get isKeystoreUnlocked;

  /// Unlocks the encrypted keystore with a password.
  Future<void> unlockKeystore(String password, {Uint8List? salt});

  /// Locks the encrypted keystore.
  void lockKeystore();

  /// Gets a secure key pair.
  Future<SimpleKeyPair> getSecureKey(String keyName);

  /// Generates a new secure key.
  Future<Uint8List> generateSecureKey(String keyName, {String? label});

  /// Checks if a secure key exists.
  bool hasSecureKey(String keyName);

  /// Gets the public key for a stored secure key.
  Uint8List? getSecurePublicKey(String keyName);
}
