import 'dart:typed_data';

/// Base class for all network messages.
abstract class BaseMessage {
  /// Creates a message with [data] and [protocol].
  BaseMessage(this.data, this.protocol);

  /// The message payload.
  final Uint8List data;

  /// The protocol identifier.
  final String protocol;

  /// Serializes the message to bytes.
  Uint8List toBytes() => data;
}

/// DHT specific messages.
class DHTMessage extends BaseMessage {
  /// Creates a DHT message with [messageType].
  DHTMessage(Uint8List data, this.messageType) : super(data, 'dht');

  /// The DHT message type (e.g., 'FIND_NODE', 'STORE').
  final String messageType;
}

/// BitSwap specific messages.
class BitSwapMessage extends BaseMessage {
  /// Creates a BitSwap message with [operation].
  BitSwapMessage(Uint8List data, this.operation) : super(data, 'bitswap');

  /// The BitSwap operation (e.g., 'WANT', 'HAVE').
  final String operation;
}
