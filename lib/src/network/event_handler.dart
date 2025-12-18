import 'dart:async';

import 'package:dart_ipfs/src/core/types/p2p_types.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:dart_ipfs/src/proto/generated/metrics.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart';

/// Handles network events and broadcasts them to listeners.
///
/// Processes peer connection events and message events, updating
/// metrics and emitting events via stream.
class NetworkEventHandler {
  final StreamController<NetworkEvent> _eventController =
      StreamController<NetworkEvent>.broadcast();

  void handlePeerEvent(LibP2PPeerId peerId, String eventType) {
    final now = DateTime.now();
    final timestamp = Timestamp()
      ..seconds = Int64(now.millisecondsSinceEpoch ~/ 1000)
      ..nanos = (now.millisecondsSinceEpoch % 1000) * 1000000;

    final event = NetworkEvent()
      ..timestamp = timestamp
      ..eventType = eventType
      ..peerId = peerId.toString();

    _eventController.add(event);
  }

  void handleMessageEvent(IPFSMessage message) {
    final now = DateTime.now();
    final timestamp = Timestamp()
      ..seconds = Int64(now.millisecondsSinceEpoch ~/ 1000)
      ..nanos = (now.millisecondsSinceEpoch % 1000) * 1000000;

    final peerMetrics = PeerMetrics()
      ..messagesSent = Int64(1)
      ..bytesReceived = Int64(message.payload.length);

    final metrics = NetworkMetrics()
      ..timestamp = timestamp
      ..peerMetrics[message.senderId] = peerMetrics;

    _updateMetrics(metrics);
    _eventController.add(
      NetworkEvent()
        ..timestamp = timestamp
        ..eventType = 'MESSAGE_RECEIVED'
        ..peerId = message.senderId
        ..data = message.payload,
    );
  }

  void _updateMetrics(NetworkMetrics metrics) {
    final now = DateTime.now();
    final timestamp = Timestamp()
      ..seconds = Int64(now.millisecondsSinceEpoch ~/ 1000)
      ..nanos = (now.millisecondsSinceEpoch % 1000) * 1000000;

    final event = NetworkEvent()
      ..timestamp = timestamp
      ..eventType = 'METRICS_UPDATED';

    _eventController.add(event);
  }

  Stream<NetworkEvent> get events => _eventController.stream;
}
