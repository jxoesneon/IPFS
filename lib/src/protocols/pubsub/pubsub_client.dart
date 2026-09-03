import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' show SimpleKeyPair;
import 'package:http/http.dart' as http;

import '../../core/crypto/ed25519_signer.dart';
import '../../core/crypto/peer_key_registry.dart';
import '../../core/data_structures/node_stats.dart';
import '../../core/types/peer_id.dart';
import '../../transport/router_interface.dart';
import '../../utils/base58.dart';
import '../../utils/logger.dart';
import 'pubsub_interface.dart';
import 'pubsub_message.dart';

/// Handles PubSub operations for an IPFS node with Gossipsub-like features.
///
/// Implements message propagation, peer mesh maintenance, and message signing.
///
/// **Security (SEC-008):**
/// PubSubClient supports genuine cryptographic authenticity using asymmetric
/// Ed25519 signatures. Outgoing messages signed with the node's Ed25519
/// [SimpleKeyPair] carry an `ed25519_signature` and the sender's `pubkey`.
///
/// Receiving nodes verify that:
/// 1. The message's `pubkey` cryptographically derives to the claimed `sender`
///    [PeerId] via [PeerKeyRegistry.verifyPeerBinding] (preventing impersonation).
/// 2. The Ed25519 signature is valid for `$topic:$content`.
/// 3. If a peer's Ed25519 public key is known or [strictAuthentication] is active,
///    unauthenticated or forged legacy HMAC tags are rejected (downgrade prevention).
///
/// Legacy messages carrying only HMAC tags remain supported in non-strict mode
/// for backward compatibility with older nodes, functioning as bit-corruption
/// and deduplication tags only.
class PubSubClient implements IPubSub {
  /// Creates a [PubSubClient] with the provided [_router] and peer identifier.
  ///
  /// Parameters:
  /// - [_router]: The network router for sending and receiving protocol messages.
  /// - [peerIdStr]: The Base58 encoded string representation of the local PeerID.
  /// - [keyPair]: Optional Ed25519 key pair for authentic message signing.
  /// - [keyRegistry]: Optional peer key registry for caching and validating peer public keys.
  /// - [strictAuthentication]: If `true`, requires valid Ed25519 signatures on all messages.
  PubSubClient(
    this._router,
    String peerIdStr, {
    SimpleKeyPair? keyPair,
    PeerKeyRegistry? keyRegistry,
    bool strictAuthentication = false,
  })  : _peerId = PeerId(value: Base58().base58Decode(peerIdStr)),
        _keyPair = keyPair,
        _keyRegistry = keyRegistry ?? PeerKeyRegistry(),
        _strictAuthentication = strictAuthentication,
        _logger = Logger('PubSubClient');

  final RouterInterface _router;
  final StreamController<PubSubMessage> _messageController =
      StreamController<PubSubMessage>.broadcast();
  final PeerId _peerId;
  final Logger _logger;
  final SimpleKeyPair? _keyPair;
  final PeerKeyRegistry _keyRegistry;
  final bool _strictAuthentication;
  final Ed25519Signer _ed25519Signer = Ed25519Signer();
  Uint8List? _cachedPublicKeyBytes;

  /// The peer key registry used by this client.
  PeerKeyRegistry get keyRegistry => _keyRegistry;

  /// Whether strict Ed25519 authentication is enforced.
  bool get isStrictAuthentication => _strictAuthentication;

  // Gossipsub state
  final Set<String> _mesh = {};
  final Map<String, double> _scores = {};
  final Map<String, Set<String>> _seenMessages = {};
  final Map<String, Map<String, String>> _messageCache = {};
  final Set<String> _subscriptions = {};

  bool _isStarted = false;
  Timer? _heartbeatTimer;

  // Constants
  static const int _targetMeshDegree = 6;
  static const Duration _heartbeatInterval = Duration(seconds: 1);
  static const String _protocolName = 'pubsub';

  /// Indicates whether the PubSub client is currently active.
  bool get isStarted => _isStarted;

  /// Starts the PubSub client, registering protocol handlers and starting heartbeat.
  ///
  /// Throws [StateError] if the client is already started.
  Future<void> start() async {
    if (_isStarted) {
      _logger.warning('PubSub client is already started.');
      return;
    }

    _isStarted = true;

    final keyPair = _keyPair;
    if (keyPair != null) {
      try {
        final pubKeyBytes =
            await _ed25519Signer.extractPublicKeyBytes(keyPair);
        _cachedPublicKeyBytes = pubKeyBytes;
        _keyRegistry.registerPublicKey(
          Base58().encode(_peerId.value),
          pubKeyBytes,
        );
      } catch (e) {
        _logger.warning('Failed to extract public key from local keyPair: $e');
      }
    }

    _router.registerProtocolHandler(_protocolName, (packet) {
      if (packet.datagram.isNotEmpty) {
        _processIncomingPacket(packet);
      }
    });

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, _heartbeat);

    _logger.info(
      'PubSub client started with peer ID: ${Base58().encode(_peerId.value)}',
    );
  }

  /// Processes an incoming network packet for the PubSub protocol.
  Future<void> _processIncomingPacket(NetworkPacket packet) async {
    try {
      final String decodedData = utf8.decode(packet.datagram);
      final Map<String, dynamic> msgMap =
          jsonDecode(decodedData) as Map<String, dynamic>;

      final String? action = msgMap['action'] as String?;
      final String? sender = msgMap['sender'] as String?;
      final String? topic = msgMap['topic'] as String?;

      if (sender == null) {
        _logger.warning('Received PubSub message without sender information.');
        return;
      }

      // Handle Gossipsub control actions
      if (action != null) {
        switch (action) {
          case 'ihave':
            _handleIHave(msgMap);
            return;
          case 'iwant':
            await _handleIWant(msgMap);
            return;
          case 'graft':
            graftPeer(sender);
            return;
          case 'prune':
            prunePeer(sender);
            return;
        }
      }

      // Handle content messages (publish)
      if (topic == null) {
        _logger.warning('Received content message without topic.');
        return;
      }

      final String? content = msgMap['content'] as String?;
      if (content == null) {
        _logger.warning('Received content message without data.');
        return;
      }

      // SEC-008: Authenticate message origin and verify integrity
      final String? ed25519SigBase64 =
          (msgMap['ed25519_signature'] ?? msgMap['ed25519Signature'])
              as String?;
      final String? pubKeyBase64 =
          (msgMap['pubkey'] ?? msgMap['publicKey']) as String?;
      final String? signature = msgMap['signature'] as String?;

      if (ed25519SigBase64 != null && ed25519SigBase64.isNotEmpty) {
        // --- Asymmetric Ed25519 verification path ---
        Uint8List? pubKeyBytes;
        if (pubKeyBase64 != null && pubKeyBase64.isNotEmpty) {
          try {
            pubKeyBytes = base64Decode(pubKeyBase64);
          } catch (_) {
            _logger.warning(
              'Malformed base64 public key in message from $sender',
            );
            return;
          }
          // Validate that public key cryptographically derives to claimed sender PeerID
          if (!PeerKeyRegistry.verifyPeerBinding(sender, pubKeyBytes)) {
            _logger.warning(
              'Rejected spoofed message: public key does not derive to claimed sender $sender',
            );
            return;
          }
          _keyRegistry.registerPublicKey(sender, pubKeyBytes);
        } else {
          pubKeyBytes = _keyRegistry.getPublicKey(sender);
          if (pubKeyBytes == null) {
            _logger.warning(
              'Rejected message: Ed25519 signature present but missing public key for $sender',
            );
            return;
          }
        }

        Uint8List sigBytes;
        try {
          sigBytes = base64Decode(ed25519SigBase64);
        } catch (_) {
          _logger.warning(
            'Malformed base64 Ed25519 signature in message from $sender',
          );
          return;
        }

        final bool isValid = await _verifyEd25519Signature(
          pubKeyBytes,
          sigBytes,
          '$topic:$content',
        );
        if (!isValid) {
          _logger.warning(
            'Rejected message with invalid Ed25519 signature from $sender on topic $topic',
          );
          return;
        }
        _logger.debug(
          'Verified authentic Ed25519 signature from $sender on topic $topic',
        );
      } else {
        // --- Unauthenticated / legacy HMAC path ---
        // If a verified Ed25519 public key is already known for this sender,
        // reject unauthenticated messages to prevent downgrade attacks.
        if (_keyRegistry.hasPublicKey(sender)) {
          _logger.warning(
            'Rejected unauthenticated message: peer $sender has a known Ed25519 key (downgrade attack prevention)',
          );
          return;
        }

        if (_strictAuthentication) {
          _logger.warning(
            'Rejected unauthenticated message from $sender in strict authentication mode',
          );
          return;
        }

        // Check legacy HMAC tag (guards against bit corruption only, NOT spoofing)
        if (signature != null) {
          final String expectedSig = _computeSignature(sender, content, topic);
          if (signature != expectedSig) {
            _logger.warning(
              'Rejected message with invalid signature from $sender on topic $topic',
            );
            return;
          }
        } else {
          _logger.verbose(
            'Received unsigned message from $sender on topic $topic',
          );
        }
      }

      // Dedup messages
      final String msgId =
          ed25519SigBase64 ?? signature ?? content.hashCode.toString();
      if (_seenMessages[topic]?.contains(msgId) ?? false) {
        return;
      }
      _seenMessages.putIfAbsent(topic, () => {}).add(msgId);

      // Update peer score and process message if from a connected peer
      if (_router.isConnectedPeer(sender)) {
        _scores[sender] = (_scores[sender] ?? 0.0) + 1.0;

        // Cache message for IWANT requests
        _messageCache.putIfAbsent(topic, () => {})[msgId] = content;

        _messageController.add(
          PubSubMessage(topic: topic, content: content, sender: sender),
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error processing incoming PubSub packet', e, stackTrace);
    }
  }

  /// Stops the PubSub client, cancelling timers and closing streams.
  Future<void> stop() async {
    if (!_isStarted) return;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _messageController.close();
    _isStarted = false;
    _logger.info('PubSub client stopped.');
  }

  @override
  Future<void> subscribe(String topic) async {
    if (_subscriptions.contains(topic)) return;

    _subscriptions.add(topic);
    _router.registerProtocol(topic);
    _logger.debug('Subscribed to topic: $topic');
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (!_subscriptions.contains(topic)) return;

    _subscriptions.remove(topic);
    _router.removeMessageHandler(topic);
    _logger.debug('Unsubscribed from topic: $topic');
  }

  @override
  Future<void> publish(String topic, String message) async {
    if (!_isStarted) {
      throw StateError('PubSub client must be started before publishing.');
    }

    try {
      final Uint8List encodedMessage =
          await encodeSignedPublishRequest(topic, message);

      if (_mesh.isEmpty) {
        _logger.warning('No peers in mesh to publish message to topic: $topic');
      }

      final List<Future<void>> publishFutures = [];
      for (final String peerId in _mesh) {
        publishFutures.add(
          (() async {
            try {
              await _router.sendMessage(peerId, encodedMessage);
            } catch (e) {
              _logger.debug('Failed to send PubSub message to $peerId: $e');
            }
          })(),
        );
      }

      await Future.wait(publishFutures);
      _logger.info('Published message to topic: $topic');
    } catch (e, stackTrace) {
      _logger.error('Critical error publishing to topic $topic', e, stackTrace);
      rethrow;
    }
  }

  /// Returns a stream of all incoming PubSub messages.
  Stream<PubSubMessage> get messagesStream => _messageController.stream;

  @override
  void onMessage(String topic, void Function(String) handler) {
    messagesStream.listen((PubSubMessage message) {
      if (message.topic == topic) {
        handler(message.content);
      }
    });
  }

  /// Encodes a subscription request for a topic.
  Uint8List encodeSubscribeRequest(String topic) {
    return Uint8List.fromList(utf8.encode('subscribe:$topic'));
  }

  /// Encodes an unsubscription request for a topic.
  Uint8List encodeUnsubscribeRequest(String topic) {
    return Uint8List.fromList(utf8.encode('unsubscribe:$topic'));
  }

  /// Encodes a content message for publishing.
  ///
  /// Includes the legacy HMAC-SHA256 tag for backward compatibility and,
  /// when available, an authentic Ed25519 signature and public key.
  Uint8List encodePublishRequest(
    String topic,
    String message, {
    Uint8List? ed25519Signature,
    Uint8List? publicKey,
  }) {
    final String senderStr = Base58().encode(_peerId.value);
    final String signature = _computeSignature(senderStr, message, topic);

    final Map<String, dynamic> messageWithSender = {
      'sender': senderStr,
      'topic': topic,
      'content': message,
      'signature': signature,
    };

    if (ed25519Signature != null && ed25519Signature.isNotEmpty) {
      messageWithSender['ed25519_signature'] = base64Encode(ed25519Signature);
    }
    final effectivePubKey = publicKey ?? _cachedPublicKeyBytes;
    if (effectivePubKey != null && effectivePubKey.isNotEmpty) {
      messageWithSender['pubkey'] = base64Encode(effectivePubKey);
    }

    return Uint8List.fromList(utf8.encode(jsonEncode(messageWithSender)));
  }

  /// Asynchronously prepares and encodes an authentic, Ed25519-signed publish request.
  Future<Uint8List> encodeSignedPublishRequest(
    String topic,
    String message,
  ) async {
    if (_keyPair != null) {
      final pubKey = await _getLocalPublicKeyBytes();
      final sig = await _signPayload('$topic:$message');
      return encodePublishRequest(
        topic,
        message,
        ed25519Signature: sig,
        publicKey: pubKey,
      );
    }
    return encodePublishRequest(topic, message);
  }

  Future<bool> _verifyEd25519Signature(
    Uint8List publicKeyBytes,
    Uint8List signatureBytes,
    String payload,
  ) async {
    try {
      final publicKey = _ed25519Signer.publicKeyFromBytes(publicKeyBytes);
      return await _ed25519Signer.verify(
        Uint8List.fromList(utf8.encode(payload)),
        signatureBytes,
        publicKey,
      );
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> _signPayload(String payload) async {
    final keyPair = _keyPair;
    if (keyPair == null) return null;
    try {
      return await _ed25519Signer.sign(
        Uint8List.fromList(utf8.encode(payload)),
        keyPair,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _getLocalPublicKeyBytes() async {
    final cached = _cachedPublicKeyBytes;
    if (cached != null) return cached;
    final keyPair = _keyPair;
    if (keyPair == null) return null;
    _cachedPublicKeyBytes =
        await _ed25519Signer.extractPublicKeyBytes(keyPair);
    return _cachedPublicKeyBytes;
  }

  /// Computes an HMAC-SHA256 tag for message integrity — NOT authenticity.
  ///
  /// The HMAC key is `sender`, i.e. the public PeerID string, which is also
  /// transmitted in cleartext in the message this tag accompanies. Since
  /// the "key" is not secret, this tag can be recomputed by anyone for any
  /// (sender, topic, content) triple; it only guards against accidental
  /// corruption, not deliberate forgery. See the class-level doc comment.
  String _computeSignature(String sender, String content, String topic) {
    final List<int> key = utf8.encode(sender);
    final List<int> data = utf8.encode('$topic:$content');
    final Hmac hmac = Hmac(sha256, key);
    final Digest digest = hmac.convert(data);
    return digest.toString();
  }

  /// Decodes raw bytes into a UTF-8 string.
  String decodeMessage(Uint8List messageBytes) {
    return utf8.decode(messageBytes);
  }

  /// Retrieves current node statistics from the local API.
  ///
  /// Throws [Exception] if statistics cannot be retrieved.
  Future<NodeStats> getNodeStats() async {
    try {
      final http.Response response = await http.get(
        Uri.parse('http://localhost:5001/stats'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return NodeStats.fromJson(data);
      } else {
        throw Exception(
          'Failed to load node stats: Status ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error retrieving node statistics', e, stackTrace);
      rethrow;
    }
  }

  /// Periodic heartbeat task for maintaining Gossipsub state.
  void _heartbeat(Timer timer) {
    if (_mesh.length < _targetMeshDegree) {
      // In a full implementation, we would graft new peers here
    } else if (_mesh.length > _targetMeshDegree + 3) {
      _pruneLowScoringPeers();
    }

    // Decay scores over time
    _scores.updateAll((String peer, double score) => score * 0.9);
  }

  /// Prunes peers with the lowest scores from the active mesh.
  void _pruneLowScoringPeers() {
    final List<String> sortedPeers = _mesh.toList()
      ..sort((a, b) => (_scores[a] ?? 0.0).compareTo(_scores[b] ?? 0.0));

    while (_mesh.length > _targetMeshDegree && sortedPeers.isNotEmpty) {
      final String peerToPrune = sortedPeers.removeAt(0);
      prunePeer(peerToPrune);
    }
  }

  /// Adds a peer to the active mesh.
  void graftPeer(String peerId) {
    if (!_mesh.contains(peerId)) {
      _mesh.add(peerId);
      _scores[peerId] = (_scores[peerId] ?? 0.0) + 10.0;
      _logger.verbose('Grafted peer $peerId into mesh');
    }
  }

  /// Removes a peer from the active mesh.
  void prunePeer(String peerId) {
    if (_mesh.remove(peerId)) {
      _logger.verbose('Pruned peer $peerId from mesh');
    }
  }

  /// Handles 'ihave' control messages by requesting missing messages.
  void _handleIHave(Map<String, dynamic> msg) {
    final String? topic = msg['topic'] as String?;
    final List<dynamic>? msgIdsRaw = msg['msgIds'] as List<dynamic>?;
    final String? sender = msg['sender'] as String?;

    if (topic == null || msgIdsRaw == null || sender == null) return;

    final List<String> msgIds = msgIdsRaw.cast<String>();
    final List<String> wantIds = [];

    for (final String id in msgIds) {
      if (!(_seenMessages[topic]?.contains(id) ?? false)) {
        wantIds.add(id);
      }
    }

    if (wantIds.isNotEmpty) {
      final Map<String, dynamic> iwant = {
        'action': 'iwant',
        'topic': topic,
        'msgIds': wantIds,
        'sender': Base58().encode(_peerId.value),
      };

      try {
        _router.sendMessage(
          sender,
          Uint8List.fromList(utf8.encode(jsonEncode(iwant))),
        );
      } catch (e) {
        _logger.warning('Failed to send IWANT request to $sender: $e');
      }
    }
  }

  /// Handles 'iwant' control messages by serving cached messages.
  Future<void> _handleIWant(Map<String, dynamic> msg) async {
    final String? topic = msg['topic'] as String?;
    final List<dynamic>? msgIdsRaw = msg['msgIds'] as List<dynamic>?;
    final String? sender = msg['sender'] as String?;

    if (topic == null || msgIdsRaw == null || sender == null) return;

    final List<String> msgIds = msgIdsRaw.cast<String>();

    try {
      for (final String id in msgIds) {
        final String? content = _messageCache[topic]?[id];
        if (content != null) {
          final Uint8List encoded = encodePublishRequest(topic, content);
          try {
            await _router.sendMessage(sender, encoded);
          } catch (e) {
            _logger.debug('Failed to serve IWANT content to $sender: $e');
          }
        }
      }
    } catch (e) {
      _logger.warning('Error handling IWANT request from $sender: $e');
    }
  }
}
