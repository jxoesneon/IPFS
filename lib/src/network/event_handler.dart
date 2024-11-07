import '../generated/base_messages.pb.dart';
import '../generated/metrics.pb.dart';

class NetworkEventHandler {
  final StreamController<NetworkEvent> _eventController =
      StreamController<NetworkEvent>.broadcast();

  void handlePeerEvent(LibP2PPeerId peerId, String eventType) {
    final event = NetworkEvent()
      ..timestamp = Int64.now()
      ..eventType = eventType
      ..peerId = peerId.toString();

    _eventController.add(event);
  }

  void handleMessageEvent(IPFSMessage message) {
    final metrics = NetworkMetrics()
      ..timestamp = Int64.now()
      ..peerMetrics[message.senderId] = PeerMetrics()
      ..messagesSent = 1
      ..bytesReceived = message.payload.length;

    _updateMetrics(metrics);
    _eventController.add(NetworkEvent()
      ..timestamp = Int64.now()
      ..eventType = 'MESSAGE_RECEIVED'
      ..peerId = message.senderId
      ..data = message.payload);
  }

  Stream<NetworkEvent> get events => _eventController.stream;
}
