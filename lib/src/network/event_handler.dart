import 'dart:async';
import 'package:fixnum/fixnum.dart';
import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/proto/generated/metrics.pb.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';

class NetworkEventHandler {
  final StreamController<NetworkEvent> _eventController =
      StreamController<NetworkEvent>.broadcast();

  void handlePeerEvent(LibP2PPeerId peerId, String eventType) {
    final event = NetworkEvent()
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch)
      ..eventType = eventType
      ..peerId = peerId.toString();

    _eventController.add(event);
  }

  void handleMessageEvent(IPFSMessage message) {
    final peerMetrics = PeerMetrics()
      ..messagesSent = Int64(1)
      ..bytesReceived = Int64(message.payload.length);

    final metrics = NetworkMetrics()
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch)
      ..peerMetrics[message.senderId] = peerMetrics;

    _updateMetrics(metrics);
    _eventController.add(NetworkEvent()
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch)
      ..eventType = 'MESSAGE_RECEIVED'
      ..peerId = message.senderId
      ..data = message.payload);
  }

  void _updateMetrics(NetworkMetrics metrics) {
    final event = NetworkEvent()
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch)
      ..eventType = 'METRICS_UPDATED';

    _eventController.add(event);
  }

  Stream<NetworkEvent> get events => _eventController.stream;
}
