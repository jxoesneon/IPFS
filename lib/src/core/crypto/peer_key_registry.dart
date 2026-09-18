// lib/src/core/crypto/peer_key_registry.dart
import 'dart:typed_data';

import '../types/peer_id.dart';

/// Registry for caching and verifying bindings between [PeerId] strings and
/// their corresponding Ed25519 public keys.
///
/// In IPFS/libp2p, a peer's identity is derived from its public key
/// ([PeerId.fromPublicKey]). Because the SHA-256 derivation is one-way,
/// remote public keys must either be supplied alongside signed payloads or
/// discovered via the Identify protocol.
///
/// [PeerKeyRegistry] verifies that any supplied public key cryptographically
/// hashes to the peer ID before storing it, preventing identity spoofing.
class PeerKeyRegistry {
  /// Maximum verified key bindings retained. Keys arrive from remote peers
  /// (pubsub messages, identify) so the map must stay bounded; the
  /// oldest-registered binding is evicted when the cap is hit and will be
  /// re-registered on the peer's next message or identify exchange.
  static const int maxRegisteredKeys = 4096;

  final Map<String, Uint8List> _keys = {};

  /// Verifies that [publicKeyBytes] cryptographically derives to [peerId].
  ///
  /// Returns `true` if and only if [publicKeyBytes] is a valid 32-byte Ed25519
  /// key whose SHA-256 digest matches the peer ID.
  static bool verifyPeerBinding(String peerId, Uint8List publicKeyBytes) {
    if (publicKeyBytes.length != 32) return false;
    try {
      final derived = PeerId.fromPublicKey(
        publicKeyBytes,
        type: 'Ed25519',
      ).toBase58();
      return derived == peerId;
    } catch (_) {
      return false;
    }
  }

  /// Registers [publicKeyBytes] for [peerId] after verifying cryptographic binding.
  ///
  /// Returns `true` if the binding is valid and registered, `false` otherwise.
  bool registerPublicKey(String peerId, Uint8List publicKeyBytes) {
    if (!verifyPeerBinding(peerId, publicKeyBytes)) {
      return false;
    }
    if (!_keys.containsKey(peerId) && _keys.length >= maxRegisteredKeys) {
      _keys.remove(_keys.keys.first);
    }
    _keys[peerId] = Uint8List.fromList(publicKeyBytes);
    return true;
  }

  /// Retrieves the verified public key bytes for [peerId], or `null` if not registered.
  Uint8List? getPublicKey(String peerId) {
    final key = _keys[peerId];
    return key != null ? Uint8List.fromList(key) : null;
  }

  /// Checks if a verified public key is registered for [peerId].
  bool hasPublicKey(String peerId) => _keys.containsKey(peerId);

  /// Removes a stored key for [peerId].
  void removeKey(String peerId) {
    _keys.remove(peerId);
  }

  /// Clears all registered keys.
  void clear() {
    _keys.clear();
  }

  /// Number of registered peer keys.
  int get size => _keys.length;
}
