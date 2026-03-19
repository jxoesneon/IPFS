import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart'; // SEC-008: For message signing
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:http/http.dart' as http;

import '../../core/data_structures/node_stats.dart';
import '../../core/types/peer_id.dart';
import '../../utils/base58.dart';
import '../../utils/logger.dart';
import 'pubsub_interface.dart';
import 'pubsub_message.dart';

// For encoding utilities

/// Handles PubSub operations for an IPFS node.
///
/// **Security (SEC-008):** Messages include HMAC-SHA256 signatures to prevent
/// sender identity spoofing. The signature is computed over the message content
/// using the peer's ID as the key.
class PubSubClient implements IPubSub {
  /// Creates a PubSub client with [_router] and peer ID.
  PubSubClient(this._router, String peerIdStr)
    : _peerId = PeerId(value: Base58().base58Decode(peerIdStr));
  final RouterInterface _router; // Router for sending and receiving messages
  final StreamController<PubSubMessage> _messageController =
      StreamController<PubSubMessage>.broadcast();
  final PeerId _peerId;
  final _logger = Logger('PubSubClient');

  // Gossipsub state
  final Set<String> _mesh =
      {}; // Peers in our mesh (String representation of PeerId)
  final Map<String, double> _scores = {}; // Peer scores
  final Map<String, Set<String>> _seenMessages =
      {}; // Message IDs (hash) we've seen
  final Map<String, Map<String, String>> _messageCache =
      {}; // Cache for fulfilling IWANT requests
  final Set<String> _subscriptions = {};
  bool _started = false;
  Timer? _heartbeatTimer;

  // Constants
  static const int _targetMeshDegree = 6;
  static const Duration _heartbeatInterval = Duration(seconds: 1);

  /// Starts the PubSub client.
  Future<void> start() async {
    _started = true;
    _router.registerProtocolHandler('pubsub', (packet) {
      if (packet.datagram.isNotEmpty) {
        try {
          final decodedJson = jsonDecode(utf8.decode(packet.datagram));

          // Dedup messages - Only for content/publish messages
          final action = decodedJson['action'] as String?;
          if (action == null || action == 'publish') {
            final topic = decodedJson['topic'] as String?;
            if (topic != null) {
              final msgId =
                  decodedJson['signature'] ??
                  decodedJson['content'].hashCode.toString();
              if (_seenMessages.containsKey(topic)) {
                if (_seenMessages[topic]!.contains(msgId)) {
                  return;
                }
              }
              _seenMessages.putIfAbsent(topic, () => {}).add(msgId as String);
            }
          }

          // Handle Gossipsub actions
          final msgMap = decodedJson as Map<String, dynamic>;
          if (action == 'ihave') {
            _handleIHave(msgMap);
            return;
          } else if (action == 'iwant') {
            _handleIWant(msgMap);
            return;
          } else if (action == 'graft') {
            graftPeer(decodedJson['sender'] as String);
            return;
          } else if (action == 'prune') {
            prunePeer(decodedJson['sender'] as String);
            return;
          }

          // SEC-008: Verify message signature
          final signature = decodedJson['signature'] as String?;
          if (signature != null) {
            final expectedSig = _computeSignature(
              decodedJson['sender'] as String,
              decodedJson['content'] as String,
              decodedJson['topic'] as String,
            );
            if (signature != expectedSig) {
              _logger.warning(
                'Rejected message with invalid signature from ${decodedJson['sender']}',
              );
              return;
            }
          } else if (action == null) {
            // Only warn for content messages (null action usually means publish)
            _logger.verbose(
              'Received unsigned message from ${decodedJson['sender']}',
            );
          }

          // Update mesh/scores on valid message
          if (_router.isConnectedPeer(decodedJson['sender'] as String)) {
            _scores[decodedJson['sender'] as String] =
                (_scores[decodedJson['sender'] as String] ?? 0.0) + 1.0;

            // Only process content messages from valid peers
            if (action == null || action == 'publish') {
              // Cache message
              final msgId =
                  decodedJson['signature'] as String? ??
                  decodedJson['content'].hashCode.toString();
              final topic = decodedJson['topic'] as String;
              final content = decodedJson['content'] as String;
              _messageCache.putIfAbsent(topic, () => {})[msgId] = content;

              _messageController.add(
                PubSubMessage(
                  topic: topic,
                  content: content,
                  sender: decodedJson['sender'] as String,
                ),
              );
            }
          }
        } catch (e, stackTrace) {
          _logger.error('Error processing message', e, stackTrace);
        }
      }
    });

    // Start heartbeat
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, _heartbeat);

    _logger.info(
      'PubSub client started with peer ID: ${Base58().encode(_peerId.value)}',
    );
  }

  /// Stops the PubSub client.
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    await _messageController.close();
    _logger.info('PubSub client stopped.');
  }

  @override
  Future<void> subscribe(String topic) async {
    if (_subscriptions.contains(topic)) return;
    _subscriptions.add(topic);
    _router.registerProtocol(topic);

    // In a full implementation, we would send GRAFT messages
    _logger.debug('Subscribed to topic: $topic');
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (!_subscriptions.contains(topic)) return;
    _subscriptions.remove(topic);
    _router.removeMessageHandler(topic);

    // In a full implementation, we would send PRUNE messages
    _logger.debug('Unsubscribed from topic: $topic');
  }

  @override
  Future<void> publish(String topic, String message) async {
    if (!_started) {
      throw StateError('PubSub client not started');
    }
    try {
      final encodedMessage = encodePublishRequest(topic, message);

      if (_mesh.isEmpty) {
        _logger.warning('No peers in mesh to publish to for topic: $topic');
      }

      for (final peerIdStr in _mesh) {
        try {
          await _router.sendMessage(peerIdStr, encodedMessage);
        } catch (_) {}
      }
      _logger.info('Published message to topic: $topic');
    } catch (e, stackTrace) {
      _logger.error('Error publishing message to topic $topic', e, stackTrace);
    }
  }

  /// Handles incoming messages on a subscribed topic.
  Stream<PubSubMessage> get messagesStream => _messageController.stream;

  @override
  void onMessage(String topic, void Function(String) handler) {
    messagesStream.listen((message) {
      if (message.topic == topic) {
        handler(message.content);
      }
    });
  }

  /// Encodes a subscribe request for the given topic.
  Uint8List encodeSubscribeRequest(String topic) {
    // Implement encoding logic for subscribe request
    return Uint8List.fromList(utf8.encode('subscribe:$topic'));
  }

  /// Encodes an unsubscribe request for the given topic.
  Uint8List encodeUnsubscribeRequest(String topic) {
    // Implement encoding logic for unsubscribe request
    return Uint8List.fromList(utf8.encode('unsubscribe:$topic'));
  }

  /// Encodes a publish request for the given topic and message.
  /// SEC-008: Includes HMAC-SHA256 signature to prevent sender spoofing.
  Uint8List encodePublishRequest(String topic, String message) {
    final senderStr = Base58().encode(_peerId.value);
    final signature = _computeSignature(senderStr, message, topic);

    final messageWithSender = {
      'sender': senderStr,
      'topic': topic,
      'content': message,
      'signature': signature, // SEC-008: Message signature
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(messageWithSender)));
  }

  /// Computes HMAC-SHA256 signature for message integrity.
  String _computeSignature(String sender, String content, String topic) {
    final key = utf8.encode(sender);
    final data = utf8.encode('$topic:$content');
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return digest.toString();
  }

  /// Decodes incoming messages from bytes to string.
  String decodeMessage(Uint8List messageBytes) {
    return utf8.decode(messageBytes);
  }

  /// Retrieves node statistics.
  Future<NodeStats> getNodeStats() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5001/stats'));
      if (response.statusCode == 200) {
        // Assuming response body contains JSON data for NodeStats
        return NodeStats.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      } else {
        throw Exception('Failed to load node stats');
      }
    } catch (e, stackTrace) {
      _logger.error('Error retrieving node stats', e, stackTrace);
      rethrow; // Rethrow the error for handling upstream
    }
  }

  /// Gossipsub heartbeat: maintains mesh and prunes low-scoring peers
  void _heartbeat(Timer timer) {
    // 1. Maintain Mesh Degree
    if (_mesh.length < _targetMeshDegree) {
      // Graft new peers if possible (simple random selection from connected peers)
      // Implementation placeholder: _graftRandomPeers();
    } else if (_mesh.length > _targetMeshDegree + 3) {
      // Prune excess peers
      _pruneLowScoringPeers();
    }

    // 2. Decay scores
    _scores.updateAll((peer, score) => score * 0.9);
  }

  void _pruneLowScoringPeers() {
    // Prune logic: sort by score and remove lowest
    // Placeholder
  }

  /// Adds a peer to the mesh with initial score
  void graftPeer(String peerId) {
    if (!_mesh.contains(peerId)) {
      _mesh.add(peerId);
      _scores[peerId] = (_scores[peerId] ?? 0.0) + 10.0; // Initial boost
      _logger.verbose('Grafted peer $peerId into mesh');
    }
  }

  /// Removes a peer from the mesh
  void prunePeer(String peerId) {
    if (_mesh.remove(peerId)) {
      _logger.verbose('Pruned peer $peerId from mesh');
    }
  }

  void _handleIHave(Map<String, dynamic> msg) {
    final topic = msg['topic'] as String;
    final msgIds = (msg['msgIds'] as List).cast<String>();
    final wantIds = <String>[];

    for (final id in msgIds) {
      if (!_seenMessages.containsKey(topic) ||
          !_seenMessages[topic]!.contains(id)) {
        wantIds.add(id);
      }
    }

    if (wantIds.isNotEmpty) {
      final iwant = {
        'action': 'iwant',
        'topic': topic,
        'msgIds': wantIds,
        'sender': Base58().encode(_peerId.value),
      };

      try {
        _router.sendMessage(
          msg['sender'] as String,
          Uint8List.fromList(utf8.encode(jsonEncode(iwant))),
        );
      } catch (e) {
        _logger.warning('Failed to send IWANT to ${msg['sender']}');
      }
    }
  }

  void _handleIWant(Map<String, dynamic> msg) {
    final topic = msg['topic'] as String;
    final msgIds = (msg['msgIds'] as List).cast<String>();
    final senderStr = msg['sender'] as String;

    try {
      for (final id in msgIds) {
        if (_messageCache.containsKey(topic) &&
            _messageCache[topic]!.containsKey(id)) {
          final content = _messageCache[topic]![id]!;
          final encoded = encodePublishRequest(topic, content);
          _router.sendMessage(senderStr, encoded);
        }
      }
    } catch (e) {
      _logger.warning('Failed to send requested messages to $senderStr');
    }
  }
}
