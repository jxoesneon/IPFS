// Encrypted P2P PubSub Mesh — dart_ipfs sample.
//
// Demonstrates end-to-end-encrypted group messaging over IPFS PubSub:
//   * A shared AES-256-GCM key is derived from a room passphrase with
//     PBKDF2-HMAC-SHA256 (CryptoUtils.deriveKey). Everyone who knows the
//     passphrase can read the topic; everyone else sees only ciphertext.
//   * Messages are JSON frames {sender, body, sentAt}, encrypted, and carried
//     as raw bytes via `publishData` so ciphertext survives the wire intact.
//   * Incoming `pubsubMessages` are authenticated-decrypted; tampered frames
//     are rejected by the GCM tag check.
//
// Usage:
//   dart run bin/main.dart [--topic NAME] [--passphrase SECRET]
//                          [--connect /ip4/.../p2p/PEER_ID] [--message TEXT]
//
// Run two instances with the same --topic/--passphrase and connect them (or
// let mDNS/bootstrap discover each other) to see the encrypted mesh live.
//
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/dart_ipfs.dart';

/// Encrypts a UTF-8 payload into a wire envelope: [nonce ‖ ciphertext‖tag].
Future<Uint8List> _seal(String plaintext, Uint8List key) async {
  final encrypted = await CryptoUtils.encrypt(
    Uint8List.fromList(utf8.encode(plaintext)),
    key,
  );
  return encrypted.toBytes();
}

/// Authenticated-decrypts a wire envelope back to UTF-8, or throws.
Future<String> _open(Uint8List envelope, Uint8List key) async {
  final plaintext = await CryptoUtils.decrypt(
    EncryptedData.fromBytes(envelope),
    key,
  );
  return utf8.decode(plaintext);
}

String _argValue(List<String> args, String name, String fallback) {
  final index = args.indexOf(name);
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  return fallback;
}

Future<void> main(List<String> args) async {
  final topic = _argValue(args, '--topic', 'dart-ipfs-mesh-demo');
  final passphrase = _argValue(args, '--passphrase', 'mesh-demo-secret');
  final peerAddr = _argValue(args, '--connect', '');
  final message = _argValue(args, '--message', 'hello encrypted mesh');

  // Room key: PBKDF2(passphrase, salt=topic). In production exchange keys with
  // ECDH over the libp2p handshake instead of a shared passphrase.
  final salt = Uint8List.fromList(utf8.encode('dart_ipfs.mesh.$topic'));
  final roomKey = CryptoUtils.deriveKey(passphrase, salt);

  final node = await IPFSNode.create(
    IPFSConfig(
      offline: false,
      enablePubSub: true,
      debug: false,
      enableMetrics: false,
    ),
  );
  await node.start();
  print('Node started. Peer ID: ${node.peerId}');

  if (peerAddr.isNotEmpty) {
    print('Connecting to $peerAddr ...');
    await node.connectToPeer(peerAddr);
  }

  await node.subscribe(topic);
  print('Subscribed to "$topic" (AES-256-GCM encrypted channel)');

  // Decrypt-and-print loop for incoming frames.
  final done = Completer<void>();
  final subscription = node.pubsubMessages
      .where((m) => m.topic == topic)
      .listen((m) async {
        try {
          final frame =
              jsonDecode(await _open(m.data, roomKey))
                  as Map<String, dynamic>;
          print(
            '[${frame['sender']}] ${frame['body']}  '
            '(from ${m.sender.substring(0, 12)}…)',
          );
        } catch (_) {
          // Wrong passphrase or tampered ciphertext — GCM tag check failed.
          print('[${m.sender}] <undecryptable frame dropped>');
        }
      }, onDone: done.complete);

  // Give the mesh a moment to form, then publish an encrypted frame.
  await Future<void>.delayed(const Duration(seconds: 2));
  final frame = jsonEncode({
    'sender': 'node-${node.peerId.substring(0, 8)}',
    'body': message,
    'sentAt': DateTime.now().toUtc().toIso8601String(),
  });
  await node.publishData(topic, await _seal(frame, roomKey));
  print('Published encrypted frame (${utf8.encode(frame).length}B plaintext)');

  final peers = await node.pubsubPeers(topic);
  print('Mesh peers on topic: ${peers.length}');

  // Listen for replies briefly, then shut down cleanly.
  await Future<void>.delayed(const Duration(seconds: 8));
  await subscription.cancel();
  CryptoUtils.zeroMemory(roomKey);
  await node.stop();
}
