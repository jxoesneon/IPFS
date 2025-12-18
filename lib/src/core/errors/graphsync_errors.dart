// src/core/errors/graphsync_errors.dart
/// Base class for Graphsync protocol errors
abstract class GraphsyncError implements Exception {

  GraphsyncError(this.message, [this.cause]);
  final String message;
  final dynamic cause;

  @override
  String toString() => cause == null
      ? 'GraphsyncError: $message'
      : 'GraphsyncError: $message (Cause: $cause)';
}

/// Error when a block is not found
class BlockNotFoundError extends GraphsyncError {
  BlockNotFoundError(String cid) : super('Block not found: $cid');
}

/// Error when parsing block data fails
class BlockParseError extends GraphsyncError {
  BlockParseError(String message, [dynamic cause])
    : super('Failed to parse block data: $message', cause);
}

/// Error when traversing the graph
class GraphTraversalError extends GraphsyncError {
  GraphTraversalError(String message, [dynamic cause])
    : super('Graph traversal error: $message', cause);
}

/// Error when sending/receiving messages
class MessageError extends GraphsyncError {
  MessageError(String message, [dynamic cause])
    : super('Message error: $message', cause);
}

/// Error when request times out
class RequestTimeoutError extends GraphsyncError {
  RequestTimeoutError(String requestId)
    : super('Request timed out: $requestId');
}

/// Error when handling graphsync requests
class RequestHandlingError extends GraphsyncError {
  RequestHandlingError(String message, [dynamic cause])
    : super('Failed to handle request: $message', cause);
}
