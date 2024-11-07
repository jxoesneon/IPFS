import '../generated/validation.pb.dart';
import '../generated/base_messages.pb.dart';

class MessageValidator {
  static ValidationResult validateMessage(IPFSMessage message) {
    if (message.payload.length > MAX_MESSAGE_SIZE) {
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
}
