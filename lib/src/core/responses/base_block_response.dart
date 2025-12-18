import 'package:protobuf/protobuf.dart';

/// Base class for protobuf block responses with validation.
abstract class BaseBlockResponse extends GeneratedMessage {
  /// Whether the operation succeeded.
  bool get success;

  /// Sets the success status.
  set success(bool value);

  /// Human-readable message.
  String get message;

  /// Sets the message.
  set message(String value);

  /// Validates the response.
  bool validate() {
    if (message.isEmpty) {
      return false;
    }
    return true;
  }
}
