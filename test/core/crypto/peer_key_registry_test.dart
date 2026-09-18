// test/core/crypto/peer_key_registry_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/crypto/peer_key_registry.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:test/test.dart';

void main() {
  group('PeerKeyRegistry', () {
    test('registers and retrieves a verified binding', () async {
      final registry = PeerKeyRegistry();
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKey = await signer.extractPublicKeyBytes(keyPair);
      final peerId = PeerId.fromPublicKey(
        publicKey,
        type: 'Ed25519',
      ).toBase58();

      expect(registry.registerPublicKey(peerId, publicKey), isTrue);
      expect(registry.hasPublicKey(peerId), isTrue);
      expect(registry.getPublicKey(peerId), equals(publicKey));
    });

    test('rejects a key that does not derive to the peer ID', () async {
      final registry = PeerKeyRegistry();
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKey = await signer.extractPublicKeyBytes(keyPair);

      final otherKeyPair = await signer.generateKeyPair();
      final otherPublicKey = await signer.extractPublicKeyBytes(otherKeyPair);
      final otherPeerId = PeerId.fromPublicKey(
        otherPublicKey,
        type: 'Ed25519',
      ).toBase58();

      // publicKey does not hash to otherPeerId — spoofing is rejected.
      expect(registry.registerPublicKey(otherPeerId, publicKey), isFalse);
      expect(registry.hasPublicKey(otherPeerId), isFalse);
    });

    test('rejects malformed public keys', () {
      final registry = PeerKeyRegistry();
      expect(
        registry.registerPublicKey('peer', Uint8List.fromList([1, 2, 3])),
        isFalse,
      );
    });

    test('removeKey and clear drop registered bindings', () async {
      final registry = PeerKeyRegistry();
      final signer = Ed25519Signer();
      final keyPair = await signer.generateKeyPair();
      final publicKey = await signer.extractPublicKeyBytes(keyPair);
      final peerId = PeerId.fromPublicKey(
        publicKey,
        type: 'Ed25519',
      ).toBase58();

      expect(registry.registerPublicKey(peerId, publicKey), isTrue);
      expect(registry.size, equals(1));

      registry.removeKey(peerId);
      expect(registry.hasPublicKey(peerId), isFalse);
      expect(registry.size, equals(0));

      expect(registry.registerPublicKey(peerId, publicKey), isTrue);
      registry.clear();
      expect(registry.hasPublicKey(peerId), isFalse);
      expect(registry.size, equals(0));
    });

    test(
      'evicts the oldest binding when maxRegisteredKeys is reached',
      () async {
        final registry = PeerKeyRegistry();
        final signer = Ed25519Signer();

        Future<String> registerNewKey() async {
          final keyPair = await signer.generateKeyPair();
          final publicKey = await signer.extractPublicKeyBytes(keyPair);
          final peerId = PeerId.fromPublicKey(
            publicKey,
            type: 'Ed25519',
          ).toBase58();
          expect(registry.registerPublicKey(peerId, publicKey), isTrue);
          return peerId;
        }

        final peerIds = <String>[];
        // Fill the registry to capacity. Keys are generated in parallel
        // batches to keep the test fast.
        const batchSize = 256;
        while (peerIds.length < PeerKeyRegistry.maxRegisteredKeys) {
          peerIds.addAll(
            await Future.wait([
              for (var i = 0; i < batchSize; i++) registerNewKey(),
            ]),
          );
        }
        expect(registry.size, equals(PeerKeyRegistry.maxRegisteredKeys));

        // The next registration must evict the oldest-inserted binding.
        final overflowPeerId = await registerNewKey();

        expect(registry.size, equals(PeerKeyRegistry.maxRegisteredKeys));
        expect(registry.hasPublicKey(peerIds.first), isFalse);
        expect(registry.hasPublicKey(peerIds[1]), isTrue);
        expect(registry.hasPublicKey(overflowPeerId), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
