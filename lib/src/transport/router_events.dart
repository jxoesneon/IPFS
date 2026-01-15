import 'dart:typed_data';

/// Interface for router implementations to handle multiaddresses
mixin MultiAddressHandler {
  /// Gets the multiaddress of the router
  String get multiaddr;

  /// Sets the multiaddress of the router
  void setMultiaddr(String addr);
}

/// A wrapper for raw bytes sent over the network
class NetworkMessage {
  /// Creates a new network message from bytes
  NetworkMessage(this.data);

  /// The raw data of the message
  final Uint8List data;

  /// Creates a network message from a byte array
  static NetworkMessage fromBytes(Uint8List bytes) {
    return NetworkMessage(bytes);
  }
}

/// Represents a network packet with source/destination info.
class NetworkPacket {
  /// Creates a network packet.
  NetworkPacket({
    required this.srcPeerId,
    required this.datagram,
    this.responder,
  });

  /// The source peer ID.
  final String srcPeerId;

  /// The raw datagram bytes.
  final Uint8List datagram;

  /// Optional responder function for synchronous request/response
  final Future<void> Function(Uint8List)? responder;
}

/// Represents a change in peer connection state
class ConnectionEvent {
  /// Creates a connection event
  ConnectionEvent({required this.type, required this.peerId});

  /// The type of connection event (connected/disconnected)
  final ConnectionEventType type;

  /// The unique identifier of the peer
  final String peerId;
}

/// Types of connection events
enum ConnectionEventType {
  /// Peer connected successfully
  connected,

  /// Peer disconnected
  disconnected,
}

/// Represents an incoming message from a peer
class MessageEvent {
  /// Creates a message event
  MessageEvent({required this.peerId, required this.message});

  /// The unique identifier of the sender
  final String peerId;

  /// The raw message payload
  final Uint8List message;
}

/// Data from a DHT operation
class DHTEvent {
  /// Creates a DHT event
  DHTEvent({required this.type, required this.data});

  /// The type of DHT event
  final DHTEventType type;

  /// The payload data returned by the DHT
  final Map<String, dynamic> data;
}

/// Types of DHT search results
enum DHTEventType {
  /// A value was found for the requested key
  valueFound,

  /// A provider was found for the requested CID
  providerFound,
}

/// Content or metadata from a PubSub subscription
class PubSubEvent {
  /// Creates a PubSub event
  PubSubEvent({
    required this.topic,
    required this.message,
    required this.publisher,
    required this.eventType,
  });

  /// The subscription topic
  final String topic;

  /// The raw message payload
  final Uint8List message;

  /// The identifier of the publisher
  final String publisher;

  /// The type of event (e.g., 'message', 'join', 'leave')
  final String eventType;
}

/// Represents a protocol or network error
class ErrorEvent {
  /// Creates an error event
  ErrorEvent({required this.type, required this.message});

  /// The classification of the error
  final ErrorEventType type;

  /// A human-readable error message
  final String message;
}

/// Classifications for network errors
enum ErrorEventType {
  /// Failure during connection establishment
  connectionError,

  /// Failure during disconnection
  disconnectionError,

  /// Failure during message processing or transport
  messageError,
}

/// Lifecycle or data event for a multi-stream
class StreamEvent {
  /// Creates a stream event
  StreamEvent({required this.type, required this.streamId, this.data});

  /// The type of stream event
  final StreamEventType type;

  /// The unique identifier for the stream
  final String streamId;

  /// Optional data payload for 'data' events
  final Uint8List? data;
}

/// Types of stream transitions
enum StreamEventType {
  /// Stream was opened by a peer
  opened,

  /// Stream was closed
  closed,

  /// Data was received on the stream
  data,
}
