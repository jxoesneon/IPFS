// src/core/errors/graphsync_errors.dart
/// Base class for all Graphsync-related errors
abstract class GraphsyncError implements Exception {
  final String message;
  final dynamic cause;

  GraphsyncError(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'GraphsyncError: $message (Cause: $cause)'
      : 'GraphsyncError: $message';
}

/// Error thrown when a Graphsync request times out
class GraphsyncTimeoutError extends GraphsyncError {
  final String requestId;
  final Duration timeout;

  GraphsyncTimeoutError(this.requestId, this.timeout)
      : super(
            'Request $requestId timed out after ${timeout.inSeconds} seconds');
}

/// Error thrown when a Graphsync request is cancelled
class GraphsyncCancelledError extends GraphsyncError {
  final String requestId;

  GraphsyncCancelledError(this.requestId)
      : super('Request $requestId was cancelled');
}

/// Error thrown when there's a protocol-level error
class GraphsyncProtocolError extends GraphsyncError {
  final String protocolId;

  GraphsyncProtocolError(this.protocolId, String message, [dynamic cause])
      : super('Protocol $protocolId error: $message', cause);
}

/// Error thrown when there's a problem with message encoding/decoding
class GraphsyncMessageError extends GraphsyncError {
  final int messageType;

  GraphsyncMessageError(this.messageType, String message, [dynamic cause])
      : super('Message type $messageType error: $message', cause);
}

/// Error thrown when there's a problem with block transfer
class GraphsyncTransferError extends GraphsyncError {
  final String requestId;
  final int bytesTransferred;
  final int totalBytes;

  GraphsyncTransferError(
      this.requestId, this.bytesTransferred, this.totalBytes, String message,
      [dynamic cause])
      : super(
            'Transfer error for request $requestId ($bytesTransferred/$totalBytes bytes): $message',
            cause);
}

/// Error thrown when there's a problem with request validation
class GraphsyncValidationError extends GraphsyncError {
  GraphsyncValidationError(String message, [dynamic cause])
      : super('Validation error: $message', cause);
}

/// Error thrown when there's a problem with response handling
class GraphsyncResponseError extends GraphsyncError {
  final String requestId;
  final int statusCode;

  GraphsyncResponseError(this.requestId, this.statusCode, String message,
      [dynamic cause])
      : super(
            'Response error for request $requestId (status $statusCode): $message',
            cause);
}

/// Error thrown when there's a problem with extension data
class GraphsyncExtensionError extends GraphsyncError {
  final String extensionName;

  GraphsyncExtensionError(this.extensionName, String message, [dynamic cause])
      : super('Extension $extensionName error: $message', cause);
}
