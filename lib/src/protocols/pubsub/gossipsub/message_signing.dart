import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'gossipsub.pb.dart';

/// The canonical prefix used by libp2p Gossipsub when signing messages.
const String _signPrefix = 'libp2p-pubsub:';

/// Provides Ed25519 signing and verification for Gossipsub messages.
///
/// This abstracts the key material so that the handler can be tested with
/// injected keys and remains compatible with the existing project keystore
/// which stores Ed25519 keys.
class Ed25519MessageSigner {
  /// Creates a signer from a [SimpleKeyPair] obtained from the
  /// `package:cryptography` Ed25519 implementation.
  Ed25519MessageSigner(this._keyPair) : _ed25519 = Ed25519();

  final SimpleKeyPair _keyPair;
  final Ed25519 _ed25519;

  /// The public key bytes (32 bytes for Ed25519).
  Future<Uint8List> get publicKey async {
    final keyData = await _keyPair.extractPublicKey();
    return Uint8List.fromList(keyData.bytes);
  }

  /// Signs the canonical Gossipsub message envelope.
  ///
  /// The signed payload is `libp2p-pubsub:` + protobuf(Message) where the
  /// `signature` and `key` fields are cleared, matching go-libp2p-pubsub
  /// and js-libp2p-gossipsub.
  Future<Uint8List> signMessage(Message message) async {
    final messageToSign = _messageWithoutSigAndKey(message);
    final bytes = messageToSign.writeToBuffer();
    final payload = Uint8List(bytes.length + _signPrefix.length);
    payload.setAll(0, utf8.encode(_signPrefix));
    payload.setAll(_signPrefix.length, bytes);

    final signature = await _ed25519.sign(payload, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verifies a Gossipsub message signature using the provided [publicKey].
  ///
  /// Returns `false` for malformed signatures or keys instead of throwing,
  /// so callers can treat verification failures as invalid messages.
  Future<bool> verifyMessage(Message message, Uint8List publicKey) async {
    final signature = message.signature;
    if (signature.isEmpty) return false;
    if (publicKey.length != 32) return false;

    final messageToVerify = _messageWithoutSigAndKey(message);
    final bytes = messageToVerify.writeToBuffer();
    final payload = Uint8List(bytes.length + _signPrefix.length);
    payload.setAll(0, utf8.encode(_signPrefix));
    payload.setAll(_signPrefix.length, bytes);

    try {
      final publicKeyObj = SimplePublicKey(
        publicKey,
        type: KeyPairType.ed25519,
      );
      final sig = Signature(signature, publicKey: publicKeyObj);
      return await _ed25519.verify(payload, signature: sig);
    } on ArgumentError {
      return false;
    } on Exception {
      return false;
    }
  }

  /// Signs arbitrary data (used for compatibility tests).
  Future<Uint8List> signData(Uint8List data) async {
    final signature = await _ed25519.sign(data, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  Message _messageWithoutSigAndKey(Message message) {
    final copy = Message();
    copy.mergeFromMessage(message);
    copy.clearSignature();
    copy.clearKey();
    return copy;
  }
}

/// Generates a fresh Ed25519 key pair suitable for [Ed25519MessageSigner].
Future<SimpleKeyPair> generateEd25519KeyPair() async {
  return await Ed25519().newKeyPair();
}
