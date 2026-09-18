// lib/src/core/crypto/encrypted_keystore.dart
//
// SEC-001: Encrypted keystore for secure private key storage.
// Uses AES-256-GCM encryption with PBKDF2 key derivation.

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto_utils.dart';
import 'ed25519_signer.dart';

/// Entry for an encrypted key in the keystore.
///
/// Contains the encrypted seed, nonce, public key, and metadata.
class EncryptedKeyEntry {
  /// Creates an encrypted key entry with the given values.
  EncryptedKeyEntry({
    required this.encryptedSeed,
    required this.nonce,
    required this.publicKey,
    required this.createdAt,
    this.label,
  });

  /// The encrypted private key seed (AES-256-GCM ciphertext).
  final Uint8List encryptedSeed;

  /// The 12-byte nonce used for encryption.
  final Uint8List nonce;

  /// The unencrypted public key (safe to store in plaintext).
  final Uint8List publicKey;

  /// When the key was created.
  final DateTime createdAt;

  /// Optional human-readable name/label.
  final String? label;

  /// Serializes this entry to a JSON map.
  Map<String, dynamic> toJson() => {
    'encryptedSeed': base64Encode(encryptedSeed),
    'nonce': base64Encode(nonce),
    'publicKey': base64Encode(publicKey),
    'createdAt': createdAt.toIso8601String(),
    if (label != null) 'label': label,
  };

  /// Creates an [EncryptedKeyEntry] from a JSON map.
  ///
  /// Throws [FormatException] if the JSON structure is invalid.
  static EncryptedKeyEntry fromJson(Map<String, dynamic> json) {
    try {
      return EncryptedKeyEntry(
        encryptedSeed: base64Decode(json['encryptedSeed'] as String),
        nonce: base64Decode(json['nonce'] as String),
        publicKey: base64Decode(json['publicKey'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        label: json['label'] as String?,
      );
    } catch (e) {
      throw FormatException('Invalid EncryptedKeyEntry JSON: $e');
    }
  }
}

/// Encrypted keystore for secure private key storage.
///
/// **Security Features (SEC-001):**
/// - Master key derived from password using PBKDF2 (100K iterations by default)
/// - All private keys encrypted with AES-256-GCM
/// - Memory zeroing on lock
/// - Public keys stored unencrypted for lookup
///
/// Example:
/// ```dart
/// final keystore = EncryptedKeystore();
/// await keystore.unlock('my-secure-password');
///
/// // Generate and store a new key
/// final keyPair = await keystore.generateKey('my-key');
///
/// // Later, retrieve for signing
/// final kp = await keystore.getKey('my-key');
/// // ... use key ...
/// keystore.lock();  // Zero memory
/// ```
class EncryptedKeystore {
  /// Master key derived from password (zeroed on lock).
  Uint8List? _masterKey;

  /// Salt used for PBKDF2 derivation.
  Uint8List? _salt;

  /// Encrypted known-plaintext blob used to verify the master password on
  /// unlock. Without it, a wrong password would derive a wrong master key
  /// silently and corrupt newly stored keys.
  EncryptedData? _passwordVerifier;

  /// Plaintext expected when [_passwordVerifier] decrypts correctly.
  static const String _verifierPlaintext = 'dart_ipfs-keystore-verifier-v1';

  /// Encrypted key entries indexed by name.
  final Map<String, EncryptedKeyEntry> _keys = {};

  /// Ed25519 signer for key operations.
  final Ed25519Signer _signer = Ed25519Signer();

  /// Whether the keystore is currently unlocked.
  bool get isUnlocked => _masterKey != null;

  /// List of all key names in the keystore.
  List<String> get keyNames => _keys.keys.toList();

  /// Optional callback invoked after every state mutation while unlocked.
  ///
  /// Receives the current [serialize] output, allowing callers to persist
  /// the encrypted keystore to durable storage.
  void Function(String serialized)? onChanged;

  void _notifyChanged() {
    if (isUnlocked) {
      onChanged?.call(serialize());
    }
  }

  /// Unlocks the keystore with a password.
  ///
  /// [password] - The master password (must not be empty)
  /// [salt] - Optional salt (generated if not provided and no salt exists)
  /// [iterations] - PBKDF2 iterations (default [CryptoUtils.defaultIterations])
  ///
  /// Derives a master key using PBKDF2 and stores it for encryption/decryption.
  /// Throws [ArgumentError] if [password] is empty.
  Future<void> unlock(
    String password, {
    Uint8List? salt,
    int iterations = CryptoUtils.defaultIterations,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError('Master password cannot be empty');
    }

    _salt = salt ?? _salt ?? CryptoUtils.generateSalt();
    final masterKey = CryptoUtils.deriveKey(
      password,
      _salt!,
      iterations: iterations,
    );

    if (_passwordVerifier != null) {
      // Verify the password before accepting the unlock: AES-GCM decryption
      // of the verifier fails (auth tag) or yields unexpected plaintext
      // whenever the derived key is wrong.
      Uint8List? plaintext;
      try {
        plaintext = await CryptoUtils.decrypt(_passwordVerifier!, masterKey);
      } catch (_) {
        plaintext = null;
      }
      if (plaintext == null || utf8.decode(plaintext) != _verifierPlaintext) {
        CryptoUtils.zeroMemory(masterKey);
        throw ArgumentError('Incorrect keystore password');
      }
    } else {
      // Legacy keystore without a verifier: when keys exist, trial-decrypt
      // one so a wrong password is still detected, then establish the
      // verifier so subsequent unlocks verify directly.
      if (_keys.isNotEmpty) {
        final entry = _keys.values.first;
        try {
          await CryptoUtils.decrypt(
            EncryptedData(ciphertext: entry.encryptedSeed, nonce: entry.nonce),
            masterKey,
          );
        } catch (_) {
          CryptoUtils.zeroMemory(masterKey);
          throw ArgumentError('Incorrect keystore password');
        }
      }
      _passwordVerifier = await CryptoUtils.encrypt(
        Uint8List.fromList(utf8.encode(_verifierPlaintext)),
        masterKey,
      );
    }

    _masterKey = masterKey;
    _notifyChanged();
  }

  /// Locks the keystore and zeros the master key from memory.
  ///
  /// **Security Note:** Always call this when done with cryptographic operations.
  void lock() {
    if (_masterKey != null) {
      CryptoUtils.zeroMemory(_masterKey!);
      _masterKey = null;
    }
  }

  /// Generates a new Ed25519 key pair and stores it encrypted.
  ///
  /// [name] - Unique name for the key.
  /// [label] - Optional human-readable label.
  ///
  /// Returns the public key bytes.
  /// Throws [StateError] if locked or if [name] already exists.
  Future<Uint8List> generateKey(String name, {String? label}) async {
    _requireUnlocked();

    if (name.isEmpty) {
      throw ArgumentError('Key name cannot be empty');
    }

    if (_keys.containsKey(name)) {
      throw StateError('Key already exists: $name');
    }

    // Generate new key pair
    final keyPair = await _signer.generateKeyPair();
    final seed = await keyPair.extractSeedAndZero();
    final publicKey = await _signer.extractPublicKeyBytes(keyPair);

    // Encrypt the seed
    final encrypted = await CryptoUtils.encrypt(seed, _masterKey!);
    CryptoUtils.zeroMemory(seed);

    // Store entry
    _keys[name] = EncryptedKeyEntry(
      encryptedSeed: encrypted.ciphertext,
      nonce: encrypted.nonce,
      publicKey: publicKey,
      createdAt: DateTime.now(),
      label: label,
    );
    _notifyChanged();

    return publicKey;
  }

  /// Imports an existing Ed25519 seed and stores it encrypted.
  ///
  /// [name] - Unique name for the key.
  /// [seed] - 32-byte Ed25519 seed.
  /// [label] - Optional human-readable label.
  ///
  /// Throws [ArgumentError] if [seed] is not 32 bytes or [name] is empty.
  /// Throws [StateError] if locked or if [name] already exists.
  Future<Uint8List> importSeed(
    String name,
    Uint8List seed, {
    String? label,
  }) async {
    _requireUnlocked();

    if (name.isEmpty) {
      throw ArgumentError('Key name cannot be empty');
    }

    if (seed.length != 32) {
      throw ArgumentError('Seed must be exactly 32 bytes for Ed25519');
    }

    if (_keys.containsKey(name)) {
      throw StateError('Key already exists: $name');
    }

    // Derive public key from seed
    final keyPair = await _signer.keyPairFromSeed(seed);
    final publicKey = await _signer.extractPublicKeyBytes(keyPair);

    // Encrypt the seed
    final encrypted = await CryptoUtils.encrypt(seed, _masterKey!);

    // Store entry
    _keys[name] = EncryptedKeyEntry(
      encryptedSeed: encrypted.ciphertext,
      nonce: encrypted.nonce,
      publicKey: publicKey,
      createdAt: DateTime.now(),
      label: label,
    );
    _notifyChanged();

    return publicKey;
  }

  /// Retrieves a decrypted key pair by name.
  ///
  /// **Security Note:** The caller is responsible for using the key
  /// promptly and not storing it long-term. Keys are automatically
  /// zeroed when this keystore is locked.
  ///
  /// Throws [ArgumentError] if [name] is not found.
  /// Throws [StateError] if locked.
  Future<SimpleKeyPair> getKey(String name) async {
    _requireUnlocked();

    final entry = _keys[name];
    if (entry == null) {
      throw ArgumentError('Key not found: $name');
    }

    // Decrypt the seed
    final encrypted = EncryptedData(
      ciphertext: entry.encryptedSeed,
      nonce: entry.nonce,
    );
    final seed = await CryptoUtils.decrypt(encrypted, _masterKey!);

    // Reconstruct key pair
    final keyPair = await _signer.keyPairFromSeed(seed);
    CryptoUtils.zeroMemory(seed);

    return keyPair;
  }

  /// Exports the raw 32-byte Ed25519 seed for a stored key.
  ///
  /// [name] - Name of the key to export.
  ///
  /// Returns the decrypted private key seed.
  ///
  /// **Security Warning:** The returned bytes are unencrypted private key
  /// material. The caller is responsible for protecting them in transit and
  /// zeroing them after use (see [CryptoUtils.zeroMemory]).
  ///
  /// Throws [ArgumentError] if [name] is not found.
  /// Throws [StateError] if locked.
  Future<Uint8List> exportSeed(String name) async {
    _requireUnlocked();

    final entry = _keys[name];
    if (entry == null) {
      throw ArgumentError('Key not found: $name');
    }

    // Decrypt the seed
    final encrypted = EncryptedData(
      ciphertext: entry.encryptedSeed,
      nonce: entry.nonce,
    );
    return CryptoUtils.decrypt(encrypted, _masterKey!);
  }

  /// Gets the public key for a stored key.
  ///
  /// Returns `null` if the key is not found.
  Uint8List? getPublicKey(String name) {
    return _keys[name]?.publicKey;
  }

  /// Checks if a key exists in the keystore.
  bool hasKey(String name) => _keys.containsKey(name);

  /// Removes a key from the keystore.
  void removeKey(String name) {
    _keys.remove(name);
    _notifyChanged();
  }

  /// Serializes the keystore to encrypted JSON format.
  ///
  /// The result can be safely stored to disk.
  /// Note: The [isUnlocked] state is not preserved.
  String serialize() {
    final json = {
      'version': 1,
      'salt': _salt != null ? base64Encode(_salt!) : null,
      'verifier': _passwordVerifier != null
          ? base64Encode(_passwordVerifier!.toBytes())
          : null,
      'keys': _keys.map((name, entry) => MapEntry(name, entry.toJson())),
    };
    return jsonEncode(json);
  }

  /// Deserializes a keystore from encrypted JSON.
  ///
  /// The keystore must be unlocked with the correct password after loading.
  /// Throws [FormatException] if the JSON structure or version is invalid.
  static EncryptedKeystore deserialize(String jsonStr) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON for keystore: $e');
    }

    final version = json['version'] as int?;

    if (version != 1) {
      throw FormatException('Unsupported keystore version: $version');
    }

    final keystore = EncryptedKeystore();
    final saltStr = json['salt'] as String?;
    if (saltStr != null) {
      keystore._salt = base64Decode(saltStr);
    }

    final verifierStr = json['verifier'] as String?;
    if (verifierStr != null) {
      keystore._passwordVerifier = EncryptedData.fromBytes(
        base64Decode(verifierStr),
      );
    }

    final keysJson = json['keys'] as Map<String, dynamic>?;
    if (keysJson != null) {
      for (final entry in keysJson.entries) {
        keystore._keys[entry.key] = EncryptedKeyEntry.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    return keystore;
  }

  /// Loads from JSON and unlocks with password.
  ///
  /// Throws if deserialization or unlocking fails.
  static Future<EncryptedKeystore> loadAndUnlock(
    String jsonStr,
    String password, {
    int iterations = CryptoUtils.defaultIterations,
  }) async {
    final keystore = deserialize(jsonStr);
    if (keystore._salt == null) {
      throw const FormatException('Keystore missing salt');
    }
    await keystore.unlock(
      password,
      salt: keystore._salt,
      iterations: iterations,
    );
    return keystore;
  }

  void _requireUnlocked() {
    if (!isUnlocked) {
      throw StateError('Keystore is locked. Call unlock() first.');
    }
  }
}
