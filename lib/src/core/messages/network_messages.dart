import 'dart:typed_data';

/// Base class for all network messages
abstract class BaseMessage {

  BaseMessage(this.data, this.protocol);
  final Uint8List data;
  final String protocol;

  // Add toBytes method that all messages must implement
  Uint8List toBytes() => data;
}

/// DHT specific messages
class DHTMessage extends BaseMessage { // e.g., 'FIND_NODE', 'STORE', etc.

  DHTMessage(Uint8List data, this.messageType) : super(data, 'dht');
  final String messageType;
}

/// BitSwap specific messages
class BitSwapMessage extends BaseMessage { // e.g., 'WANT', 'HAVE', etc.

  BitSwapMessage(Uint8List data, this.operation) : super(data, 'bitswap');
  final String operation;
}
