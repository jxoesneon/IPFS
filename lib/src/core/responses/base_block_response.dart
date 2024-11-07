import 'package:protobuf/protobuf.dart';

abstract class BaseBlockResponse extends GeneratedMessage {
  bool get success;
  set success(bool value);

  String get message;
  set message(String value);

  // Common validation logic
  bool validate() {
    if (message.isEmpty) {
      return false;
    }
    return true;
  }
}
