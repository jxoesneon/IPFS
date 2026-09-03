import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/crypto/peer_key_registry.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/pubsub/gossipsub/gossipsub.pb.dart';
import 'package:dart_ipfs/src/protocols/pubsub/gossipsub/gossipsub_config.dart';
import 'package:dart_ipfs/src/protocols/pubsub/gossipsub/gossipsub_handler.dart';
import 'package:dart_ipfs/src/protocols/pubsub/gossipsub/message_signing.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'pubsub_client_coverage_test.mocks.dart';

void main() {
  group(''PeerKeyRegistry'', () {
    late Ed25519Signer signer;
    late SimpleKeyPair keyPair;
    late Uint8List pubKeyBytes;
    late String peerIdStr;

    setUp(() async {
      signer = Ed25519Signer();
      keyPair = await signer.generateKeyPair();
      pubKeyBytes = await signer.extractPublicKeyBytes(keyPair);
      peerIdStr = PeerId.fromPublicKey(pubKeyBytes, type: ''Ed25519'').toBase58();
    });

    test(''verifies correct peer binding'', () {
      expect(PeerKeyRegistry.verifyPeerBinding(peerIdStr, pubKeyBytes), isTrue);
    });

    test(''rejects binding when public key does not match peer ID'', () async {
      final otherKeyPair = await signer.generateKeyPair();
      final otherPubKey = await signer.extractPublicKeyBytes(otherKeyPair);

      expect(PeerKeyRegistry.verifyPeerBinding(peerIdStr, otherPubKey), isFalse);
    });

    test(''rejects invalid key lengths'', () {
      expect(
        PeerKeyRegistry.verifyPeerBinding(peerIdStr, Uint8List(16)),
        isFalse,
      );
      expect(
        PeerKeyRegistry.verifyPeerBinding(peerIdStr, Uint8List(64)),
        isFalse,
      );
    });

    test(''registers and retrieves valid public keys'', () {
      final registry = PeerKeyRegistry();
      expect(registry.hasPublicKey(peerIdStr), isFalse);

      final registered = registry.registerPublicKey(peerIdStr, pubKeyBytes);
      expect(registered, isTrue);
      expect(registry.hasPublicKey(peerIdStr), isTrue);
      expect(registry.getPublicKey(peerIdStr), equals(pubKeyBytes));
      expect(registry.size, equals(1));

      registry.removeKey(peerIdStr);
      expect(registry.hasPublicKey(peerIdStr), isFalse);
    });
  });

  group(''GossipsubHandler Author Cryptographic Binding (SEC-008)'', () {
    late MockRouterInterface mockRouter;
    late SimpleKeyPair localKeyPair;
    late Ed25519MessageSigner localSigner;
    late Uint8List localPeerIdBytes;
    late GossipsubHandler handler;

    setUp(() async {
      mockRouter = MockRouterInterface();
      localKeyPair = await Ed25519().newKeyPair();
      localSigner = Ed25519MessageSigner(localKeyPair);
      final pubKey = await localSigner.publicKey;
      localPeerIdBytes = PeerId.fromPublicKey(pubKey, type: ''Ed25519'').value;

      handler = GossipsubHandler(
        router: mockRouter,
        signer: localSigner,
        peerId: localPeerIdBytes,
        config: const PubSubConfig(strictSign: true),
      );
    });

    test(''rejects message when message.key does not derive to message.from'', () async {
      await handler.start();

      final capturedHandler =
          verify(mockRouter.registerProtocolHandler(any, captureAny))
              .captured
              .single as void Function(NetworkPacket);

      // Victim identity
      final victimKeyPair = await Ed25519().newKeyPair();
      final victimPubKey = await victimKeyPair.extractPublicKey();
      final victimPeerIdBytes = PeerId.fromPublicKey(
        Uint8List.fromList(victimPubKey.bytes),
        type: ''Ed25519'',
      ).value;

      // Attacker identity
      final attackerKeyPair = await Ed25519().newKeyPair();
      final attackerSigner = Ed25519MessageSigner(attackerKeyPair);
      final attackerPubKey = await attackerSigner.publicKey;

      // Attacker crafts a message claiming from = victim, but key = attackerPubKey
      final message = Message()
        ..from = victimPeerIdBytes
        ..topic = ''general''
        ..data = utf8.encode(''Attacker forged payload'')
        ..seqno = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 1])
        ..key = attackerPubKey;

      message.signature = await attackerSigner.signMessage(message);

      final rpc = RPC()..publish.add(message);
      final packet = NetworkPacket(
        srcPeerId: ''sender-peer'',
        datagram: rpc.writeToBuffer(),
      );

      var delivered = false;
      handler.messages.listen((_) => delivered = true);

      capturedHandler(packet);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        delivered,
        isFalse,
        reason:
            ''GossipsubHandler must drop messages where key does not derive to message.from'',
      );
    });
  });

  group(''PubSubClient Tamper Resistance'', () {
    late MockRouterInterface mockRouter;
    late SimpleKeyPair senderKeyPair;
    late Uint8List senderPubKeyBytes;
    late String senderPeerId;
    late Ed25519Signer signer;

    setUp(() async {
      mockRouter = MockRouterInterface();
      signer = Ed25519Signer();
      senderKeyPair = await signer.generateKeyPair();
      senderPubKeyBytes = await signer.extractPublicKeyBytes(senderKeyPair);
      senderPeerId = PeerId.fromPublicKey(
        senderPubKeyBytes,
        type: ''Ed25519'',
      ).toBase58();
    });

    test(''rejects message when content is tampered with after signing'', () async {
      final client = PubSubClient(mockRouter, ''QmLocalReceiver123'');
      await client.start();

      final capturedHandler =
          verify(mockRouter.registerProtocolHandler(any, captureAny))
              .captured
              .single as void Function(NetworkPacket);

      when(mockRouter.isConnectedPeer(senderPeerId)).thenReturn(true);

      const topic = ''trade-signals'';
      const originalContent = ''Buy order 100 shares'';
      const tamperedContent = ''Sell order 1000 shares'';

      final validSig = await signer.sign(
        Uint8List.fromList(utf8.encode(''$topic:$originalContent'')),
        senderKeyPair,
      );

      // Tampered packet: signature was for originalContent, but content was changed
      final tamperedPacket = NetworkPacket(
        srcPeerId: ''relay'',
        datagram: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              ''sender'': senderPeerId,
              ''topic'': topic,
              ''content'': tamperedContent,
              ''ed25519_signature'': base64Encode(validSig),
              ''pubkey'': base64Encode(senderPubKeyBytes),
            }),
          ),
        ),
      );

      var delivered = false;
      final sub = client.messagesStream.listen((_) => delivered = true);

      capturedHandler(tamperedPacket);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        delivered,
        isFalse,
        reason: ''Must reject message when content does not match signature'',
      );
      await sub.cancel();
      await client.stop();
    });
  });
}
