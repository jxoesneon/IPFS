import 'dart:typed_data';
import 'package:protobuf/protobuf.dart';

/// Base class for protobuf message types with serialization helpers.
///
/// Provides common toBytes/fromBytes conversions and cloning.
abstract class BaseProtoMessage extends GeneratedMessage {
  /// Convert message to bytes
  Uint8List toBytes() {
    return writeToBuffer();
  }

  /// Create message from bytes
  static T fromBytes<T extends BaseProtoMessage>(
    Uint8List bytes,
    T Function() factory,
  ) {
    final message = factory();
    message.mergeFromBuffer(bytes);
    return message;
  }

  /// Create a deep copy of the message
  @override
  GeneratedMessage clone() {
    return deepCopy();
  }

  /// Type-safe clone method
  T cloneAs<T extends BaseProtoMessage>() {
    return clone() as T;
  }
}
