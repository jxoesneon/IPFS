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
/// Control messages (subscribe/unsubscribe/graft/prune/ihave/iwant) are never
/// relayed, so their `sender` must equal the transport-level peer ID. In
/// strict authentication mode they must additionally carry a valid Ed25519
/// signature over `'$action:$topic'`; unsigned plain-text announcements are
/// rejected.
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
  /// - [strictAuthentication]: If `true` (the default), requires valid Ed25519
  ///   signatures on all content messages and control announcements. Pass
  ///   `false` to accept legacy unsigned messages.
  PubSubClient(
    this._router,
    String peerIdStr, {
    SimpleKeyPair? keyPair,
    PeerKeyRegistry? keyRegistry,
    bool strictAuthentication = true,
  }) : _peerId = PeerId(value: Base58().base58Decode(peerIdStr)),
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

  /// Remote peers known to be subscribed to each topic.
  ///
  /// Populated from inbound subscribe announcements and GRAFT control
  /// messages; entries are removed on unsubscribe announcements and PRUNE.
  final Map<String, Set<String>> _topicPeers = {};

  bool _isStarted = false;
  Timer? _heartbeatTimer;

  // Constants
  static const int _targetMeshDegree = 6;
  static const Duration _heartbeatInterval = Duration(seconds: 1);
  static const String _protocolName = 'pubsub';

  /// Maximum message IDs retained per topic for dedup and IWANT serving.
  static const int _maxEntriesPerTopic = 512;

  /// Maximum topics tracked in peer/dedup state before the oldest are dropped.
  static const int _maxTrackedTopics = 256;

  /// Maximum peers retained per topic.
  static const int _maxPeersPerTopic = 128;

  /// Maximum peer score entries retained; lowest-scored peers are evicted.
  static const int _maxScoredPeers = 1024;

  /// Indicates whether the PubSub client is currently active.
  bool get isStarted => _isStarted;

  /// Returns the topics this node is currently subscribed to.
  ///
  /// The returned list is an unmodifiable snapshot; subsequent [subscribe]
  /// and [unsubscribe] calls do not affect it.
  @override
  List<String> get subscribedTopics =>
      List<String>.unmodifiable(_subscriptions);

  /// Returns the peers known to be subscribed to [topic].
  ///
  /// Topic peers are learned from inbound subscribe announcements and
  /// GRAFT control messages. When no per-topic information has been
  /// recorded for [topic], the global gossipsub mesh is returned instead,
  /// as mesh peers are the best available approximation of that topic's
  /// peer set.
  @override
  Set<String> peersForTopic(String topic) {
    final Set<String>? peers = _topicPeers[topic];
    if (peers == null) {
      return Set<String>.unmodifiable(_mesh);
    }
    return Set<String>.unmodifiable(peers);
  }

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
        final pubKeyBytes = await _ed25519Signer.extractPublicKeyBytes(keyPair);
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

      // Plain-text subscription announcements produced by
      // [encodeSubscribeRequest] and [encodeUnsubscribeRequest]. They carry
      // no signature, so strict authentication mode rejects them; signed
      // JSON announcements (see [encodeSignedAnnouncement]) are required
      // instead.
      if (decodedData.startsWith('subscribe:')) {
        if (_strictAuthentication) {
          _logger.warning(
            'Rejected unsigned subscribe announcement from ${packet.srcPeerId} '
            'in strict authentication mode',
          );
          return;
        }
        _trackTopicPeer(
          packet.srcPeerId,
          decodedData.substring('subscribe:'.length),
        );
        return;
      }
      if (decodedData.startsWith('unsubscribe:')) {
        if (_strictAuthentication) {
          _logger.warning(
            'Rejected unsigned unsubscribe announcement from ${packet.srcPeerId} '
            'in strict authentication mode',
          );
          return;
        }
        _untrackTopicPeer(
          packet.srcPeerId,
          decodedData.substring('unsubscribe:'.length),
        );
        return;
      }

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
        // Control messages are exchanged only between directly connected
        // peers — never relayed — so a sender field that does not match the
        // transport-level peer is a forgery.
        if (sender != packet.srcPeerId) {
          _logger.warning(
            'Rejected $action control message: sender $sender does not match '
            'transport peer ${packet.srcPeerId}',
          );
          return;
        }
        if (_strictAuthentication &&
            !await _verifySignedAnnouncement(action, topic, sender, msgMap)) {
          _logger.warning(
            'Rejected unsigned $action announcement from $sender in strict '
            'authentication mode',
          );
          return;
        }
        switch (action) {
          case 'ihave':
            await _handleIHave(msgMap);
            return;
          case 'iwant':
            await _handleIWant(msgMap);
            return;
          case 'graft':
            graftPeer(sender);
            _trackTopicPeer(sender, topic);
            return;
          case 'prune':
            prunePeer(sender);
            _untrackTopicPeer(sender, topic);
            return;
          case 'subscribe':
            _trackTopicPeer(sender, topic);
            return;
          case 'unsubscribe':
            _untrackTopicPeer(sender, topic);
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
          // Register verifies the binding cryptographically (public key must
          // derive to the claimed sender PeerID) before storing.
          if (!_keyRegistry.registerPublicKey(sender, pubKeyBytes)) {
            _logger.warning(
              'Rejected spoofed message: public key does not derive to claimed sender $sender',
            );
            return;
          }
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
      _boundedSetAdd(_seenMessages, topic, msgId, _maxEntriesPerTopic);

      // Update peer score and process message if from a connected peer
      if (_router.isConnectedPeer(sender)) {
        _scores[sender] = (_scores[sender] ?? 0.0) + 1.0;
        _evictLowestScores();

        // Cache message for IWANT requests
        final cache = _messageCache.putIfAbsent(
          topic,
          () => <String, String>{},
        );
        cache[msgId] = content;
        while (cache.length > _maxEntriesPerTopic) {
          cache.remove(cache.keys.first);
        }
        while (_messageCache.length > _maxTrackedTopics) {
          _messageCache.remove(_messageCache.keys.first);
        }

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
    _seenMessages.clear();
    _messageCache.clear();
    _scores.clear();
    _topicPeers.clear();
    _mesh.clear();
    // _messageController is `final` and must survive a stop/start cycle; it
    // is released with the client.
    _isStarted = false;
    _logger.info('PubSub client stopped.');
  }

  @override
  Future<void> subscribe(String topic) async {
    if (_subscriptions.contains(topic)) return;

    _subscriptions.add(topic);
    _router.registerProtocol(topic);

    // Peers already known to subscribe to this topic become mesh candidates:
    // without this, the mesh stays empty forever (no dart_ipfs peer emits
    // GRAFT) and publish has nowhere to send.
    for (final peerId in _topicPeers[topic] ?? const <String>{}) {
      graftPeer(peerId);
    }

    await _announce(await encodeSignedAnnouncement('subscribe', topic));
    _logger.debug('Subscribed to topic: $topic');
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (!_subscriptions.contains(topic)) return;

    _subscriptions.remove(topic);
    _router.removeMessageHandler(topic);
    await _announce(await encodeSignedAnnouncement('unsubscribe', topic));
    _logger.debug('Unsubscribed from topic: $topic');
  }

  /// Broadcasts a control announcement to every connected peer.
  ///
  /// Announcement failures are logged but never thrown: subscription state
  /// is local truth, and a single unreachable peer must not break it.
  Future<void> _announce(Uint8List announcement) async {
    for (final peerId in _router.connectedPeers) {
      try {
        await _router.sendMessage(
          peerId,
          announcement,
          protocolId: _protocolName,
        );
      } catch (e) {
        _logger.debug('Failed to announce to $peerId: $e');
      }
    }
  }

  @override
  Future<void> publish(String topic, String message) async {
    if (!_isStarted) {
      throw StateError('PubSub client must be started before publishing.');
    }

    try {
      final Uint8List encodedMessage = await encodeSignedPublishRequest(
        topic,
        message,
      );

      // Fanout: mesh peers plus every peer known to subscribe to the topic.
      // Mesh alone is insufficient — a peer that announced its subscription
      // but has not been grafted would otherwise never receive the message.
      final targets = {..._mesh, ...?_topicPeers[topic]};
      if (targets.isEmpty) {
        _logger.warning('No peers in mesh to publish message to topic: $topic');
      }

      final List<Future<void>> publishFutures = [];
      for (final String peerId in targets) {
        publishFutures.add(
          (() async {
            try {
              await _router.sendMessage(
                peerId,
                encodedMessage,
                protocolId: _protocolName,
              );
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

  /// Encodes a subscription announcement for a topic.
  ///
  /// When an Ed25519 [SimpleKeyPair] is configured, the announcement is a
  /// signed JSON control message (`ed25519_signature` over
  /// `'$action:$topic'` plus the sender `pubkey`), which strict-mode peers
  /// require. Without a key pair the legacy plain-text form is produced.
  Future<Uint8List> encodeSignedAnnouncement(
    String action,
    String topic,
  ) async {
    final sig = await _signPayload('$action:$topic');
    final pubKey = await _getLocalPublicKeyBytes();
    if (sig != null && sig.isNotEmpty && pubKey != null && pubKey.isNotEmpty) {
      final String senderStr = Base58().encode(_peerId.value);
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'action': action,
            'sender': senderStr,
            'topic': topic,
            'ed25519_signature': base64Encode(sig),
            'pubkey': base64Encode(pubKey),
          }),
        ),
      );
    }
    return action == 'unsubscribe'
        ? encodeUnsubscribeRequest(topic)
        : encodeSubscribeRequest(topic);
  }

  /// Verifies the Ed25519 signature on a signed control message.
  ///
  /// The signature must cover `'$action:$topic'` and verify under a public
  /// key that cryptographically derives to [sender] — either carried inline
  /// in [msgMap] (`pubkey`) or already registered in the key registry.
  Future<bool> _verifySignedAnnouncement(
    String action,
    String? topic,
    String sender,
    Map<String, dynamic> msgMap,
  ) async {
    final String? sigBase64 =
        (msgMap['ed25519_signature'] ?? msgMap['ed25519Signature']) as String?;
    if (sigBase64 == null || sigBase64.isEmpty) return false;

    Uint8List? pubKeyBytes;
    final String? pubKeyBase64 =
        (msgMap['pubkey'] ?? msgMap['publicKey']) as String?;
    if (pubKeyBase64 != null && pubKeyBase64.isNotEmpty) {
      try {
        pubKeyBytes = base64Decode(pubKeyBase64);
      } catch (_) {
        return false;
      }
      // Registration verifies the public key derives to the claimed sender.
      if (!_keyRegistry.registerPublicKey(sender, pubKeyBytes)) {
        return false;
      }
    } else {
      pubKeyBytes = _keyRegistry.getPublicKey(sender);
      if (pubKeyBytes == null) return false;
    }

    final Uint8List sigBytes;
    try {
      sigBytes = base64Decode(sigBase64);
    } catch (_) {
      return false;
    }
    return _verifyEd25519Signature(pubKeyBytes, sigBytes, '$action:$topic');
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
    _cachedPublicKeyBytes = await _ed25519Signer.extractPublicKeyBytes(keyPair);
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
      _evictLowestScores();
      _logger.verbose('Grafted peer $peerId into mesh');
    }
  }

  /// Removes a peer from the active mesh.
  void prunePeer(String peerId) {
    if (_mesh.remove(peerId)) {
      _logger.verbose('Pruned peer $peerId from mesh');
    }
  }

  /// Records that [peerId] is subscribed to [topic].
  ///
  /// Called when a subscribe announcement or GRAFT control message
  /// referencing [topic] is received from [peerId].
  void _trackTopicPeer(String peerId, String? topic) {
    if (topic == null || topic.isEmpty) return;
    _boundedSetAdd(_topicPeers, topic, peerId, _maxPeersPerTopic);
  }

  /// Adds [value] to the insertion-ordered set stored under [key] in [map],
  /// evicting the oldest values beyond [maxPerKey] and dropping the oldest
  /// keys beyond [_maxTrackedTopics].
  static void _boundedSetAdd<K>(
    Map<String, Set<K>> map,
    String key,
    K value,
    int maxPerKey,
  ) {
    final set = map.putIfAbsent(key, () => <K>{});
    set.add(value);
    while (set.length > maxPerKey) {
      set.remove(set.first);
    }
    while (map.length > _maxTrackedTopics) {
      map.remove(map.keys.first);
    }
  }

  /// Evicts the lowest-scored peers when the score table exceeds
  /// [_maxScoredPeers].
  void _evictLowestScores() {
    while (_scores.length > _maxScoredPeers) {
      String? lowest;
      for (final entry in _scores.entries) {
        if (lowest == null || entry.value < _scores[lowest]!) {
          lowest = entry.key;
        }
      }
      if (lowest == null) break;
      _scores.remove(lowest);
    }
  }

  /// Records that [peerId] is no longer subscribed to [topic].
  ///
  /// Called when an unsubscribe announcement or PRUNE control message
  /// referencing [topic] is received from [peerId].
  void _untrackTopicPeer(String peerId, String? topic) {
    if (topic == null || topic.isEmpty) return;
    _topicPeers[topic]?.remove(peerId);
  }

  /// Handles 'ihave' control messages by requesting missing messages.
  Future<void> _handleIHave(Map<String, dynamic> msg) async {
    final String? topic = msg['topic'] as String?;
    final List<dynamic>? msgIdsRaw = msg['msgIds'] as List<dynamic>?;
    final String? sender = msg['sender'] as String?;

    if (topic == null || msgIdsRaw == null || sender == null) return;

    // A peer gossiping messages for a topic participates in that topic.
    _trackTopicPeer(sender, topic);

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

      // Sign the control message so strict-mode peers accept it.
      final sig = await _signPayload('iwant:$topic');
      final pubKey = await _getLocalPublicKeyBytes();
      if (sig != null && sig.isNotEmpty) {
        iwant['ed25519_signature'] = base64Encode(sig);
      }
      if (pubKey != null && pubKey.isNotEmpty) {
        iwant['pubkey'] = base64Encode(pubKey);
      }

      try {
        await _router.sendMessage(
          sender,
          Uint8List.fromList(utf8.encode(jsonEncode(iwant))),
          protocolId: _protocolName,
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
          final Uint8List encoded = await encodeSignedPublishRequest(
            topic,
            content,
          );
          try {
            await _router.sendMessage(
              sender,
              encoded,
              protocolId: _protocolName,
            );
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
