import 'dart:typed_data';

import 'package:p2plib/p2plib.dart' as p2p;

import 'crypto_provider.dart';

/// IO implementation of [CryptoProvider] using p2plib.
///
/// This implementation uses the native libsodium bindings via p2plib
/// for high-performance cryptographic operations in isolates.
class CryptoProviderIO implements CryptoProvider {
  p2p.Crypto? _crypto;
  bool _initialized = false;

  @override
  Future<CryptoKeyPair> init([Uint8List? seed]) async {
    _crypto = p2p.Crypto();
    final result = await _crypto!.init(seed);
    _initialized = true;

    return CryptoKeyPair(
      seed: result.seed,
      encryptionPublicKey: result.encPubKey,
      signingPublicKey: result.signPubKey,
    );
  }

  @override
  Future<Uint8List> seal(Uint8List datagram) async {
    _ensureInitialized();
    return _crypto!.seal(datagram);
  }

  @override
  Future<Uint8List> unseal(Uint8List datagram) async {
    _ensureInitialized();
    return _crypto!.unseal(datagram);
  }

  @override
  Future<Uint8List> verify(Uint8List datagram) async {
    _ensureInitialized();
    return _crypto!.verify(datagram);
  }

  @override
  void dispose() {
    // p2plib Crypto doesn't expose dispose, but keys are cleaned up
    // when the isolate terminates
    _crypto = null;
    _initialized = false;
  }

  void _ensureInitialized() {
    if (!_initialized || _crypto == null) {
      throw StateError('CryptoProviderIO not initialized. Call init() first.');
    }
  }
}

/// Factory function for IO platform.
CryptoProvider createCryptoProvider() => CryptoProviderIO();
