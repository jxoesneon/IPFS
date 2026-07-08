import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/utils/logger.dart';
import 'package:fixnum/fixnum.dart';

import 'gossipsub.pb.dart';
import 'gossipsub_config.dart';
import 'message_cache.dart';
import 'message_signing.dart';
import 'peer_score.dart';

/// A message received on a Gossipsub topic.
class GossipsubMessage {
  /// Creates a received Gossipsub message.
  GossipsubMessage({
    required this.topic,
    required this.data,
    required this.sender,
    required this.seqno,
    required this.signature,
  });

  /// The topic the message was published to.
  final String topic;

  /// The message payload bytes.
  final Uint8List data;

  /// The sender peer ID as a base58 string.
  final String sender;

  /// The 8-byte big-endian sequence number.
  final Uint8List seqno;

  /// The message signature bytes.
  final Uint8List signature;

  @override
  String toString() =>
      'GossipsubMessage(topic: $topic, sender: $sender, dataLength: ${data.length})';
}

/// Spec-compliant Gossipsub v1.1 handler.
///
/// Implements the canonical protobuf wire format, message signing and
/// verification, message history cache, peer scoring, and mesh/heartbeat
/// maintenance. This handler is intended to replace the legacy JSON/HMAC
/// [PubSubClient] for Kubo/Helia interoperability.
class GossipsubHandler {
  /// Creates a Gossipsub handler.
  ///
  /// [router] provides the underlying P2P transport. [signer] provides
  /// Ed25519 signing and verification for the local node. [peerId] is the
  /// local peer ID bytes. [config] controls protocol parameters.
  GossipsubHandler({
    required RouterInterface router,
    required Ed25519MessageSigner signer,
    required Uint8List peerId,
    PubSubConfig? config,
    Logger? logger,
  }) : _router = router,
       _signer = signer,
       _peerId = peerId,
       _config = config ?? const PubSubConfig(),
       _logger = logger ?? Logger('GossipsubHandler') {
    _messageController = StreamController<GossipsubMessage>.broadcast();
  }

  final RouterInterface _router;
  final Ed25519MessageSigner _signer;
  final Uint8List _peerId;
  final PubSubConfig _config;
  final Logger _logger;
  final Random _random = Random.secure();

  final Set<String> _subscriptions = {};
  final Map<String, Set<String>> _mesh = {};
  final Map<String, Set<String>> _fanout = {};
  final Map<String, Set<String>> _peerSubscriptions = {};
  final Map<String, DateTime> _pruneBackoffs = {};
  final MessageCache _cache = MessageCache();
  late PeerScoreTable _scores;

  Timer? _heartbeatTimer;
  late StreamController<GossipsubMessage> _messageController;
  int _seqno = 0;
  bool _started = false;

  /// Whether the handler has been started.
  bool get isStarted => _started;

  /// The configured protocol ID.
  String get protocolId => _config.protocolId;

  /// Starts the handler, registers the protocol, and begins the heartbeat.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _scores = PeerScoreTable(topicParams: _config.topicScoreParams);
    _router.registerProtocolHandler(_config.protocolId, _onRpc);
    _router.connectionEvents.listen(_onConnectionEvent);

    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: _config.heartbeatIntervalMs),
      (_) => _heartbeat(),
    );

    _logger.info(
      'Gossipsub handler started; protocol=${_config.protocolId}, peerId=${_base58(_peerId)}',
    );
  }

  /// Stops the handler and cancels background timers.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _messageController.close();
    _logger.info('Gossipsub handler stopped.');
  }

  /// Runs a single heartbeat iteration.
  ///
  /// Publicly exposed to enable deterministic tests; the production path is
  /// driven by the internal timer created in [start].
  void heartbeat() => _heartbeat();

  /// Subscribes to [topic].
  Future<void> subscribe(String topic) async {
    _validateTopic(topic);
    if (_subscriptions.contains(topic)) return;

    _subscriptions.add(topic);
    _mesh.putIfAbsent(topic, () => {});
    _fanout.putIfAbsent(topic, () => {});

    final rpc = RPC()
      ..subscriptions.add(Subscription(subscribe: true, topicid: topic));
    await _broadcastRpc(rpc);

    _logger.debug('Subscribed to topic: $topic');
  }

  /// Unsubscribes from [topic].
  Future<void> unsubscribe(String topic) async {
    _validateTopic(topic);
    if (!_subscriptions.contains(topic)) return;

    _subscriptions.remove(topic);

    // Notify mesh peers with PRUNE
    final peers = _mesh[topic]?.toList() ?? [];
    for (final peer in peers) {
      await _sendPrune(peer, topic);
    }
    _mesh.remove(topic);
    _fanout.remove(topic);

    final rpc = RPC()
      ..subscriptions.add(Subscription(subscribe: false, topicid: topic));
    await _broadcastRpc(rpc);

    _logger.debug('Unsubscribed from topic: $topic');
  }

  /// Publishes [data] to [topic].
  Future<void> publish(String topic, Uint8List data) async {
    _validateTopic(topic);
    if (!_started) throw StateError('Gossipsub handler must be started');
    if (data.length > _config.maxMessageSize) {
      throw ArgumentError('Message exceeds maxMessageSize');
    }

    final message = await _createMessage(topic, data);
    _cache.add(message);
    _scores.scoreFor(_base58(_peerId)).addMeshMessageDelivery(topic);

    await _publishMessage(message, topic);
    _logger.debug('Published message to topic: $topic');
  }

  /// Returns a stream of messages on [topic].
  Stream<GossipsubMessage> onMessage(String topic) {
    return _messageController.stream.where((msg) => msg.topic == topic);
  }

  /// Returns the current [PeerScore] for [peerId].
  PeerScore getPeerScore(String peerId) {
    return _scores.scoreFor(peerId);
  }

  /// Returns the current mesh peers for [topic].
  Set<String> meshPeers(String topic) => Set<String>.from(_mesh[topic] ?? {});

  /// Returns the current fanout peers for [topic].
  Set<String> fanoutPeers(String topic) =>
      Set<String>.from(_fanout[topic] ?? {});

  /// Returns the list of subscribed topics.
  Set<String> get subscriptions => Set<String>.from(_subscriptions);

  // --- Internal message creation ---

  Future<Message> _createMessage(String topic, Uint8List data) async {
    _seqno++;
    final seqnoBytes = ByteData(8)..setUint64(0, _seqno);
    final message = Message()
      ..from = _peerId
      ..data = data
      ..seqno = seqnoBytes.buffer.asUint8List()
      ..topic = topic;

    if (_config.signMessages) {
      message.signature = await _signer.signMessage(message);
      // Only attach key if the peer ID cannot be decoded to a key.
      // For this implementation we always attach the public key for
      // robustness and compatibility with strict verification paths.
      message.key = await _signer.publicKey;
    }

    return message;
  }

  // --- RPC processing ---

  void _onRpc(NetworkPacket packet) {
    try {
      if (packet.datagram.length > _config.maxMessageSize) {
        _logger.warning('Dropping oversized RPC from ${packet.srcPeerId}');
        return;
      }

      final rpc = RPC.fromBuffer(packet.datagram);
      _processSubscriptions(packet.srcPeerId, rpc.subscriptions);
      _processPublish(packet.srcPeerId, rpc.publish);
      _processControl(packet.srcPeerId, rpc.control);
    } catch (e, stackTrace) {
      _logger.error('Error processing Gossipsub RPC', e, stackTrace);
    }
  }

  void _processSubscriptions(String peerId, List<Subscription> subscriptions) {
    for (final sub in subscriptions) {
      final topic = sub.topicid;
      if (topic.isEmpty) continue;
      final set = _peerSubscriptions.putIfAbsent(topic, () => {});
      if (sub.subscribe) {
        set.add(peerId);
      } else {
        set.remove(peerId);
      }
    }
  }

  Future<void> _processPublish(String sender, List<Message> messages) async {
    for (final message in messages) {
      await _processMessage(sender, message);
    }
  }

  Future<void> _processMessage(String sender, Message message) async {
    final topic = message.topic;
    if (topic.isEmpty) {
      _logger.warning('Received message with empty topic from $sender');
      return;
    }

    if (message.data.length > _config.maxMessageSize) {
      _logger.warning('Dropping oversized message from $sender');
      _scores.scoreFor(sender).addInvalidMessageDelivery(topic);
      return;
    }

    final msgId = MessageCache.messageId(message);
    if (_cache.containsId(msgId)) {
      return; // duplicate
    }

    // Signature verification
    if (_config.strictSign || message.signature.isNotEmpty) {
      final publicKey = message.key.isNotEmpty ? message.key : null;
      if (publicKey == null || publicKey.isEmpty) {
        _logger.warning('Missing public key for signed message from $sender');
        _scores.scoreFor(sender).addInvalidMessageDelivery(topic);
        return;
      }
      final valid = await _signer.verifyMessage(
        message,
        Uint8List.fromList(publicKey),
      );
      if (!valid) {
        _logger.warning('Invalid signature from $sender on topic $topic');
        _scores.scoreFor(sender).addInvalidMessageDelivery(topic);
        return;
      }
    }

    _cache.add(message);
    _scores.scoreFor(sender).addFirstMessageDelivery(topic);

    _messageController.add(
      GossipsubMessage(
        topic: topic,
        data: Uint8List.fromList(message.data),
        sender: _base58(Uint8List.fromList(message.from)),
        seqno: Uint8List.fromList(message.seqno),
        signature: Uint8List.fromList(message.signature),
      ),
    );

    // Forward to mesh and fanout peers, excluding the sender.
    await _forwardMessage(message, sender);
  }

  Future<void> _forwardMessage(Message message, String excludePeer) async {
    final topic = message.topic;
    final senderSet = {excludePeer};
    final targets = <String>{};

    // Forward only to mesh peers for received messages.
    targets.addAll(_mesh[topic] ?? {});
    targets.removeAll(senderSet);

    if (targets.isEmpty) return;

    final rpc = RPC()..publish.add(message);
    for (final peer in targets) {
      try {
        await _sendRpc(peer, rpc);
      } catch (e) {
        _logger.debug('Failed to forward message to $peer: $e');
      }
    }
  }

  Future<void> _processControl(String sender, ControlMessage control) async {
    for (final ihave in control.ihave) {
      await _handleIHave(sender, ihave);
    }
    for (final iwant in control.iwant) {
      await _handleIWant(sender, iwant);
    }
    for (final graft in control.graft) {
      _handleGraft(sender, graft);
    }
    for (final prune in control.prune) {
      _handlePrune(sender, prune);
    }
  }

  Future<void> _handleIHave(String sender, ControlIHave ihave) async {
    final topic = ihave.topicID;
    if (topic.isEmpty) return;

    final wantIds = <String>[];
    for (final id in ihave.messageIDs) {
      if (!_cache.containsId(id)) {
        wantIds.add(id);
      }
    }

    if (wantIds.length > _config.maxIWantLength) {
      wantIds.length = _config.maxIWantLength;
    }

    if (wantIds.isNotEmpty) {
      final control = ControlMessage()
        ..iwant.add(ControlIWant()..messageIDs.addAll(wantIds));
      final rpc = RPC()..control = control;
      await _sendRpc(sender, rpc);
    }
  }

  Future<void> _handleIWant(String sender, ControlIWant iwant) async {
    // IWANT does not specify a topic in the protobuf, so we search all topics.
    final all = <String>{};
    all.addAll(_subscriptions);
    all.addAll(_mesh.keys);

    final messages = <Message>[];
    for (final topic in all) {
      messages.addAll(_cache.getForIWant(topic, iwant.messageIDs));
    }

    if (messages.isNotEmpty) {
      final rpc = RPC()..publish.addAll(messages);
      await _sendRpc(sender, rpc);
    }
  }

  void _handleGraft(String sender, ControlGraft graft) {
    final topic = graft.topicID;
    if (topic.isEmpty) return;
    if (!_subscriptions.contains(topic)) return;

    final backoffKey = '$topic:$sender';
    final backoff = _pruneBackoffs[backoffKey];
    if (backoff != null &&
        DateTime.now().toUtc().difference(backoff).inSeconds <
            _config.pruneBackoffSeconds) {
      _scores.scoreFor(sender).addBehaviourPenalty(1.0);
      _sendPrune(sender, topic);
      return;
    }

    _mesh.putIfAbsent(topic, () => {}).add(sender);
    _scores.scoreFor(sender).addMeshMessageDelivery(topic);
  }

  void _handlePrune(String sender, ControlPrune prune) {
    final topic = prune.topicID;
    if (topic.isEmpty) return;
    _mesh[topic]?.remove(sender);
    _pruneBackoffs['$topic:$sender'] = DateTime.now().toUtc();
  }

  // --- Sending helpers ---

  Future<void> _sendRpc(String peerId, RPC rpc) async {
    final bytes = rpc.writeToBuffer();
    if (bytes.length > _config.maxMessageSize) {
      _logger.warning('RPC too large for $peerId');
      return;
    }
    await _router.sendMessage(peerId, bytes, protocolId: _config.protocolId);
  }

  Future<void> _broadcastRpc(RPC rpc) async {
    final peers = _router.connectedPeers.toList();
    for (final peer in peers) {
      try {
        await _sendRpc(peer, rpc);
      } catch (e) {
        _logger.debug('Failed to broadcast RPC to $peer: $e');
      }
    }
  }

  Future<void> _publishMessage(Message message, String topic) async {
    final rpc = RPC()..publish.add(message);

    final targets = <String>{};
    if (_subscriptions.contains(topic)) {
      // Subscribed: publish to the mesh.
      targets.addAll(_mesh[topic] ?? {});
    } else {
      // Not subscribed: publish to the fanout.
      targets.addAll(_fanout[topic] ?? {});
    }

    // If no topic peers are known and flood publishing is enabled, send to
    // all connected peers with an acceptable score.
    if (targets.isEmpty && _config.floodPublish) {
      for (final peer in _router.connectedPeers) {
        if (_scores.score(peer) > -1000) {
          targets.add(peer);
        }
      }
    }

    for (final peer in targets) {
      try {
        await _sendRpc(peer, rpc);
      } catch (e) {
        _logger.debug('Failed to publish to $peer: $e');
      }
    }
  }

  Future<void> _sendPrune(String peerId, String topic) async {
    final control = ControlMessage()
      ..prune.add(
        ControlPrune(
          topicID: topic,
          backoff: Int64(_config.pruneBackoffSeconds),
        ),
      );
    final rpc = RPC()..control = control;
    await _sendRpc(peerId, rpc);
  }

  // --- Heartbeat ---

  void _heartbeat() {
    _scores.heartbeat();

    for (final topic in _subscriptions) {
      _maintainMesh(topic);
      _emitGossip(topic);
    }

    _scores.decay();
  }

  void _maintainMesh(String topic) {
    final mesh = _mesh.putIfAbsent(topic, () => {});
    final candidates =
        _peerSubscriptions[topic]
            ?.where((p) => !mesh.contains(p) && _router.isConnectedPeer(p))
            .toList() ??
        [];

    // Graft until we have at least dLow peers.
    while (mesh.length < _config.dLow && candidates.isNotEmpty) {
      final idx = _random.nextInt(candidates.length);
      final peer = candidates.removeAt(idx);
      mesh.add(peer);
      _sendGraft(peer, topic);
    }

    // Prune if we have too many peers.
    if (mesh.length > _config.dHigh) {
      final sorted = mesh.toList()
        ..sort((a, b) => _scores.score(a).compareTo(_scores.score(b)));
      while (mesh.length > _config.d && sorted.isNotEmpty) {
        final peer = sorted.removeAt(0);
        mesh.remove(peer);
        _sendPrune(peer, topic);
      }
    }
  }

  Future<void> _sendGraft(String peerId, String topic) async {
    final control = ControlMessage()..graft.add(ControlGraft(topicID: topic));
    final rpc = RPC()..control = control;
    await _sendRpc(peerId, rpc);
  }

  void _emitGossip(String topic) {
    final gossipIds = _cache.recentMessageIds(topic, _config.historyLength);
    if (gossipIds.isEmpty) return;

    // Target gossip peers: connected peers not in the mesh for this topic.
    final meshSet = _mesh[topic] ?? {};
    final gossipPeers = _router.connectedPeers
        .where((p) => !meshSet.contains(p) && _scores.score(p) > -1000)
        .toList();

    if (gossipPeers.isEmpty) return;

    // Select gossipFactor peers (or all if fewer).
    final count = min(_config.gossipFactor, gossipPeers.length);
    gossipPeers.shuffle(_random);
    final selected = gossipPeers.take(count);

    final ihave = ControlIHave()
      ..topicID = topic
      ..messageIDs.addAll(gossipIds);
    final control = ControlMessage()..ihave.add(ihave);
    final rpc = RPC()..control = control;

    for (final peer in selected) {
      try {
        _sendRpc(peer, rpc);
      } catch (e) {
        _logger.debug('Failed to emit gossip to $peer: $e');
      }
    }
  }

  // --- Connection events ---

  void _onConnectionEvent(ConnectionEvent event) {
    if (event.type == ConnectionEventType.disconnected) {
      final peerId = event.peerId;
      for (final topic in _subscriptions) {
        _mesh[topic]?.remove(peerId);
        _fanout[topic]?.remove(peerId);
      }
      for (final set in _peerSubscriptions.values) {
        set.remove(peerId);
      }
    }
  }

  // --- Utilities ---

  void _validateTopic(String topic) {
    if (topic.isEmpty) {
      throw ArgumentError('Topic cannot be empty');
    }
    try {
      utf8.encode(topic);
    } catch (e) {
      throw ArgumentError('Topic must be valid UTF-8: $topic');
    }
  }

  final Base58 _base58Codec = Base58();

  String _base58(Uint8List bytes) => _base58Codec.encode(bytes);
}
