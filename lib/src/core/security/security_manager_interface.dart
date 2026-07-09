import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import '../interfaces/i_lifecycle.dart';

/// Interface for SecurityManager to allow platform-agnostic implementations.
///
/// The security manager is responsible for:
/// - Managing the encrypted keystore lifecycle (lock/unlock)
/// - Generating and retrieving secure Ed25519 keys
/// - Providing access to public keys for verification
/// - Handling security-related metrics and policies
abstract class ISecurityManager implements ILifecycle {
  /// Whether the encrypted keystore is currently unlocked.
  bool get isKeystoreUnlocked;

  /// Unlocks the encrypted keystore with a [password].
  ///
  /// [password] - The master password (must not be empty).
  /// [salt] - Optional salt for key derivation.
  Future<void> unlockKeystore(String password, {Uint8List? salt});

  /// Locks the encrypted keystore and clears the master key from memory.
  void lockKeystore();

  /// Gets a secure Ed25519 key pair by [keyName].
  ///
  /// Throws if the keystore is locked or the key is not found.
  Future<SimpleKeyPair> getSecureKey(String keyName);

  /// Generates a new secure Ed25519 key and stores it encrypted.
  ///
  /// [keyName] - Unique identifier for the key.
  /// [label] - Optional human-readable label.
  ///
  /// Returns the public key bytes.
  Future<Uint8List> generateSecureKey(String keyName, {String? label});

  /// Checks if a secure key with [keyName] exists.
  bool hasSecureKey(String keyName);

  /// Gets the public key for a stored secure key.
  ///
  /// Returns `null` if the key is not found.
  Uint8List? getSecurePublicKey(String keyName);

  /// Checks if a client should be rate limited.
  bool shouldRateLimit(String clientId);

  /// Tracks an authentication attempt and returns true if allowed.
  bool trackAuthAttempt(String clientId, bool success);

  /// Gets the security status of the node.
  Future<Map<String, dynamic>> getStatus();
}
