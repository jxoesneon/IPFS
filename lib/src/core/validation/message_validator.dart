import 'package:dart_ipfs/src/proto/generated/validation.pb.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:dart_ipfs/src/proto/generated/config.pb.dart';

class MessageValidator {
  static ValidationResult validateMessage(
      IPFSMessage message, ProtocolConfig config) {
    final maxSize = config.maxMessageSize;

    if (message.payload.length > maxSize) {
      return ValidationResult()
        ..isValid = false
        ..errorMessage = 'Message exceeds size limit'
        ..code = ValidationResult_ValidationCode.INVALID_SIZE;
    }

    try {
      switch (message.type) {
        case IPFSMessage_MessageType.DHT:
          return _validateDHTMessage(message);
        case IPFSMessage_MessageType.BITSWAP:
          return _validateBitSwapMessage(message);
        default:
          return ValidationResult()
            ..isValid = false
            ..errorMessage = 'Unknown message type'
            ..code = ValidationResult_ValidationCode.INVALID_PROTOCOL;
      }
    } catch (e) {
      return ValidationResult()
        ..isValid = false
        ..errorMessage = e.toString()
        ..code = ValidationResult_ValidationCode.INVALID_FORMAT;
    }
  }

  static ValidationResult _validateDHTMessage(IPFSMessage message) {
    // Basic DHT message validation
    if (message.payload.isEmpty) {
      return ValidationResult()
        ..isValid = false
        ..errorMessage = 'Empty DHT message payload'
        ..code = ValidationResult_ValidationCode.INVALID_FORMAT;
    }

    return ValidationResult()..isValid = true;
  }

  static ValidationResult _validateBitSwapMessage(IPFSMessage message) {
    // Basic BitSwap message validation
    if (message.payload.isEmpty) {
      return ValidationResult()
        ..isValid = false
        ..errorMessage = 'Empty BitSwap message payload'
        ..code = ValidationResult_ValidationCode.INVALID_FORMAT;
    }

    return ValidationResult()..isValid = true;
  }
}
