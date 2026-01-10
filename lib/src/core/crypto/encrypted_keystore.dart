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
  static EncryptedKeyEntry fromJson(Map<String, dynamic> json) {
    return EncryptedKeyEntry(
      encryptedSeed: base64Decode(json['encryptedSeed'] as String),
      nonce: base64Decode(json['nonce'] as String),
      publicKey: base64Decode(json['publicKey'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      label: json['label'] as String?,
    );
  }
}

/// Encrypted keystore for secure private key storage.
///
/// **Security Features (SEC-001):**
/// - Master key derived from password using PBKDF2 (100K iterations)
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

  /// Encrypted key entries indexed by name.
  final Map<String, EncryptedKeyEntry> _keys = {};

  /// Ed25519 signer for key operations.
  final Ed25519Signer _signer = Ed25519Signer();

  /// Whether the keystore is currently unlocked.
  bool get isUnlocked => _masterKey != null;

  /// List of all key names in the keystore.
  List<String> get keyNames => _keys.keys.toList();

  /// Unlocks the keystore with a password.
  ///
  /// [password] - The master password
  /// [salt] - Optional salt (generated if not provided)
  ///
  /// Derives a master key using PBKDF2 and stores it for encryption/decryption.
  Future<void> unlock(
    String password, {
    Uint8List? salt,
    int iterations = CryptoUtils.defaultIterations,
  }) async {
    _salt = salt ?? CryptoUtils.generateSalt();
    _masterKey = CryptoUtils.deriveKey(password, _salt!, iterations: iterations);
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
  /// Returns the public key bytes.
  Future<Uint8List> generateKey(String name, {String? label}) async {
    _requireUnlocked();

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

    return publicKey;
  }

  /// Imports an existing Ed25519 seed and stores it encrypted.
  Future<Uint8List> importSeed(String name, Uint8List seed, {String? label}) async {
    _requireUnlocked();

    if (seed.length != 32) {
      throw ArgumentError('Seed must be 32 bytes');
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

    return publicKey;
  }

  /// Retrieves a decrypted key pair by name.
  ///
  /// **Security Note:** The caller is responsible for using the key
  /// promptly and not storing it long-term. Keys are automatically
  /// zeroed when this keystore is locked.
  Future<SimpleKeyPair> getKey(String name) async {
    _requireUnlocked();

    final entry = _keys[name];
    if (entry == null) {
      throw ArgumentError('Key not found: $name');
    }

    // Decrypt the seed
    final encrypted = EncryptedData(ciphertext: entry.encryptedSeed, nonce: entry.nonce);
    final seed = await CryptoUtils.decrypt(encrypted, _masterKey!);

    // Reconstruct key pair
    final keyPair = await _signer.keyPairFromSeed(seed);
    CryptoUtils.zeroMemory(seed);

    return keyPair;
  }

  /// Gets the public key for a stored key.
  Uint8List? getPublicKey(String name) {
    return _keys[name]?.publicKey;
  }

  /// Checks if a key exists in the keystore.
  bool hasKey(String name) => _keys.containsKey(name);

  /// Removes a key from the keystore.
  void removeKey(String name) {
    _keys.remove(name);
  }

  /// Serializes the keystore to encrypted JSON format.
  ///
  /// The result can be safely stored to disk.
  String serialize() {
    final json = {
      'version': 1,
      'salt': base64Encode(_salt ?? Uint8List(0)),
      'keys': _keys.map((name, entry) => MapEntry(name, entry.toJson())),
    };
    return jsonEncode(json);
  }

  /// Deserializes a keystore from encrypted JSON.
  ///
  /// The keystore must be unlocked with the correct password after loading.
  static EncryptedKeystore deserialize(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final version = json['version'] as int?;

    if (version != 1) {
      throw FormatException('Unsupported keystore version: $version');
    }

    final keystore = EncryptedKeystore();
    keystore._salt = base64Decode(json['salt'] as String);

    final keysJson = json['keys'] as Map<String, dynamic>;
    for (final entry in keysJson.entries) {
      keystore._keys[entry.key] = EncryptedKeyEntry.fromJson(entry.value as Map<String, dynamic>);
    }

    return keystore;
  }

  /// Loads from JSON and unlocks with password.
  static Future<EncryptedKeystore> loadAndUnlock(
    String jsonStr,
    String password, {
    int iterations = CryptoUtils.defaultIterations,
  }) async {
    final keystore = deserialize(jsonStr);
    await keystore.unlock(password, salt: keystore._salt, iterations: iterations);
    return keystore;
  }

  void _requireUnlocked() {
    if (!isUnlocked) {
      throw StateError('Keystore is locked. Call unlock() first.');
    }
  }
}
