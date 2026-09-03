// Regression/documentation test for the PubSub message-tag forgery issue
// described on PubSubClient's class-level doc comment (SEC-008). Reported
// to the maintainer via responsible disclosure per SECURITY.md before this
// branch was opened.
//
// Demonstrates:
// 1. That PubSubClient''s legacy HMAC "signature" can be forged by any
//    party using only public fields in unauthenticated legacy mode.
// 2. That with the SEC-008 remediation (Ed25519 asymmetric signatures,
//    PeerKeyRegistry, and downgrade prevention), forgery attacks are
//    cryptographically prevented and rejected.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/crypto/peer_key_registry.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'pubsub_client_coverage_test.mocks.dart';

/// Recomputes PubSubClient''s legacy tag exactly as an outside attacker could:
/// using only the sender PeerID string, topic, and content -- all of which
/// are public and carried in cleartext by every message.
String _publiclyComputableTag(String sender, String topic, String content) {
  final key = utf8.encode(sender);
  final data = utf8.encode(''$topic:$content'');
  return Hmac(sha256, key).convert(data).toString();
}

void main() {
  late PubSubClient receiverClient;
  late MockRouterInterface mockRouter;

  const receiverPeerId = ''QmReceiver9K7mNpQrStUvWxYzABCDEFGH123'';
  const victimPeerId = ''QmVictim9K7mNpQrStUvWxYzABCDEFGH456'';

  setUp(() {
    mockRouter = MockRouterInterface();
    receiverClient = PubSubClient(mockRouter, receiverPeerId);
  });

  tearDown(() async {
    if (receiverClient.isStarted) await receiverClient.stop();
  });

  group(''SEC-008: PubSub message tag is forgeable (legacy unauthenticated mode)'', () {
    test(
      ''an unrelated attacker can impersonate a connected victim peer in legacy mode'',
      () async {
        await receiverClient.start();
        final capturedHandler =
            verify(
                  mockRouter.registerProtocolHandler(any, captureAny),
                ).captured.single
                as void Function(NetworkPacket);

        when(mockRouter.isConnectedPeer(victimPeerId)).thenReturn(true);

        const topic = ''general-chat'';
        const forgedContent =
            ''Attacker-controlled message the victim never sent'';

        final forgedTag = _publiclyComputableTag(
          victimPeerId,
          topic,
          forgedContent,
        );

        final forgedPacket = NetworkPacket(
          srcPeerId: ''attacker-own-connection-id'',
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                ''sender'': victimPeerId,
                ''topic'': topic,
                ''content'': forgedContent,
                ''signature'': forgedTag,
              }),
            ),
          ),
        );

        final received = receiverClient.messagesStream.first;
        capturedHandler(forgedPacket);

        final message = await received;
        expect(message.sender, equals(victimPeerId));
        expect(message.content, equals(forgedContent));
      },
    );

    test(
      ''the tag depends only on public fields, so an independent party ''
      ''reproduces the exact same tag without coordinating on a secret'',
      () {
        const topic = ''topicA'';
        const content = ''hello'';

        final victimsOwnClient = PubSubClient(
          MockRouterInterface(),
          victimPeerId,
        );
        final legitimateEncoded = victimsOwnClient.encodePublishRequest(
          topic,
          content,
        );
        final legitimateTag =
            (jsonDecode(utf8.decode(legitimateEncoded))
                    as Map<String, dynamic>)[''signature'']
                as String;

        final forgedTag = _publiclyComputableTag(
          victimPeerId,
          topic,
          content,
        );

        expect(
          forgedTag,
          equals(legitimateTag),
          reason:
              ''The HMAC key is derived entirely from the public `sender` ''
              ''field, so anyone can reproduce the exact same tag without ''
              ''ever holding a secret.'',
        );
      },
    );
  });

  group(''SEC-008 Remediation: Asymmetric Ed25519 authentication prevents forgery'', () {
    late Ed25519Signer signer;
    late SimpleKeyPair victimKeyPair;
    late Uint8List victimPubKeyBytes;
    late String realVictimPeerId;

    setUp(() async {
      signer = Ed25519Signer();
      victimKeyPair = await signer.generateKeyPair();
      victimPubKeyBytes = await signer.extractPublicKeyBytes(victimKeyPair);
      realVictimPeerId = PeerId.fromPublicKey(
        victimPubKeyBytes,
        type: ''Ed25519'',
      ).toBase58();
    });

    test(
      ''rejects forged HMAC message when victim peer has registered Ed25519 public key'',
      () async {
        await receiverClient.start();
        receiverClient.keyRegistry.registerPublicKey(
          realVictimPeerId,
          victimPubKeyBytes,
        );

        final capturedHandler =
            verify(
                  mockRouter.registerProtocolHandler(any, captureAny),
                ).captured.single
                as void Function(NetworkPacket);

        when(mockRouter.isConnectedPeer(realVictimPeerId)).thenReturn(true);

        const topic = ''general-chat'';
        const forgedContent = ''Spoofed message with legacy HMAC tag'';
        final forgedTag = _publiclyComputableTag(
          realVictimPeerId,
          topic,
          forgedContent,
        );

        final forgedPacket = NetworkPacket(
          srcPeerId: ''attacker-own-connection-id'',
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                ''sender'': realVictimPeerId,
                ''topic'': topic,
                ''content'': forgedContent,
                ''signature'': forgedTag,
              }),
            ),
          ),
        );

        var delivered = false;
        final sub = receiverClient.messagesStream.listen((_) => delivered = true);

        capturedHandler(forgedPacket);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          delivered,
          isFalse,
          reason: ''Downgrade protection must drop unauthenticated HMAC messages ''
              ''when an Ed25519 key is registered for that peer.'',
        );
        await sub.cancel();
      },
    );

    test(
      ''rejects forged messages in strict authentication mode'',
      () async {
        final strictClient = PubSubClient(
          mockRouter,
          receiverPeerId,
          strictAuthentication: true,
        );
        await strictClient.start();

        final capturedHandler =
            verify(
                  mockRouter.registerProtocolHandler(any, captureAny),
                ).captured.single
                as void Function(NetworkPacket);

        when(mockRouter.isConnectedPeer(victimPeerId)).thenReturn(true);

        final forgedPacket = NetworkPacket(
          srcPeerId: ''attacker'',
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                ''sender'': victimPeerId,
                ''topic'': ''strict-topic'',
                ''content'': ''attempted bypass'',
                ''signature'': _publiclyComputableTag(
                  victimPeerId,
                  ''strict-topic'',
                  ''attempted bypass'',
                ),
              }),
            ),
          ),
        );

        var delivered = false;
        final sub = strictClient.messagesStream.listen((_) => delivered = true);

        capturedHandler(forgedPacket);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(delivered, isFalse);
        await sub.cancel();
        await strictClient.stop();
      },
    );

    test(
      ''rejects spoofed message where attacker signs with own key but claims victim PeerId'',
      () async {
        await receiverClient.start();
        final capturedHandler =
            verify(
                  mockRouter.registerProtocolHandler(any, captureAny),
                ).captured.single
                as void Function(NetworkPacket);

        when(mockRouter.isConnectedPeer(realVictimPeerId)).thenReturn(true);

        // Attacker creates their own keypair
        final attackerKeyPair = await signer.generateKeyPair();
        final attackerPubKeyBytes =
            await signer.extractPublicKeyBytes(attackerKeyPair);

        const topic = ''security-announcements'';
        const attackPayload = ''Malicious message claiming to be from victim'';

        final sig = await signer.sign(
          Uint8List.fromList(utf8.encode(''$topic:$attackPayload'')),
          attackerKeyPair,
        );

        final spoofedPacket = NetworkPacket(
          srcPeerId: ''attacker-node'',
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                ''sender'': realVictimPeerId, // Attacker claims victim''s PeerId!
                ''topic'': topic,
                ''content'': attackPayload,
                ''signature'': _publiclyComputableTag(
                  realVictimPeerId,
                  topic,
                  attackPayload,
                ),
                ''ed25519_signature'': base64Encode(sig),
                ''pubkey'': base64Encode(attackerPubKeyBytes),
              }),
            ),
          ),
        );

        var delivered = false;
        final sub = receiverClient.messagesStream.listen((_) => delivered = true);

        capturedHandler(spoofedPacket);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          delivered,
          isFalse,
          reason:
              ''Must drop message when public key does not cryptographically ''
              ''derive to claimed sender PeerId.'',
        );
        await sub.cancel();
      },
    );

    test(
      ''accepts authentic Ed25519-signed message and registers peer public key'',
      () async {
        await receiverClient.start();
        final capturedHandler =
            verify(
                  mockRouter.registerProtocolHandler(any, captureAny),
                ).captured.single
                as void Function(NetworkPacket);

        when(mockRouter.isConnectedPeer(realVictimPeerId)).thenReturn(true);

        final victimClient = PubSubClient(
          MockRouterInterface(),
          realVictimPeerId,
          keyPair: victimKeyPair,
        );

        const topic = ''verified-channel'';
        const legitimateContent = ''Authentic message from legitimate key holder'';

        final legitimateDatagram = await victimClient.encodeSignedPublishRequest(
          topic,
          legitimateContent,
        );

        final authenticPacket = NetworkPacket(
          srcPeerId: ''any-mesh-relay'',
          datagram: legitimateDatagram,
        );

        final received = receiverClient.messagesStream.first;
        capturedHandler(authenticPacket);

        final message = await received;
        expect(message.sender, equals(realVictimPeerId));
        expect(message.content, equals(legitimateContent));

        // Verify that the receiver cached the peer''s verified public key
        expect(receiverClient.keyRegistry.hasPublicKey(realVictimPeerId), isTrue);
      },
    );
  });
}
