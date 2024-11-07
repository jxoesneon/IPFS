import 'dart:typed_data';

/// Base class for all network messages
abstract class BaseMessage {
  final Uint8List data;
  final String protocol;

  BaseMessage(this.data, this.protocol);

  // Add toBytes method that all messages must implement
  Uint8List toBytes() => data;
}

/// DHT specific messages
class DHTMessage extends BaseMessage {
  final String messageType; // e.g., 'FIND_NODE', 'STORE', etc.

  DHTMessage(Uint8List data, this.messageType) : super(data, 'dht');
}

/// BitSwap specific messages
class BitSwapMessage extends BaseMessage {
  final String operation; // e.g., 'WANT', 'HAVE', etc.

  BitSwapMessage(Uint8List data, this.operation) : super(data, 'bitswap');
}
