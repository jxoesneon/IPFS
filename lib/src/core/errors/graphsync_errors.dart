// src/core/errors/graphsync_errors.dart
/// Base class for Graphsync protocol errors
abstract class GraphsyncError implements Exception {
  /// Creates a new [GraphsyncError] with the given [message] and optional [cause].
  GraphsyncError(this.message, [this.cause]);

  /// The error message describing what went wrong.
  final String message;

  /// The underlying cause of this error, if any.
  final dynamic cause;

  @override
  String toString() => cause == null
      ? 'GraphsyncError: $message'
      : 'GraphsyncError: $message (Cause: $cause)';
}

/// Error when a block is not found.
class BlockNotFoundError extends GraphsyncError {
  /// Creates an error for a missing block with [cid].
  BlockNotFoundError(String cid) : super('Block not found: $cid');
}

/// Error when parsing block data fails.
class BlockParseError extends GraphsyncError {
  /// Creates a parse error with [message] and optional [cause].
  BlockParseError(String message, [dynamic cause])
    : super('Failed to parse block data: $message', cause);
}

/// Error when traversing the graph.
class GraphTraversalError extends GraphsyncError {
  /// Creates a traversal error with [message] and optional [cause].
  GraphTraversalError(String message, [dynamic cause])
    : super('Graph traversal error: $message', cause);
}

/// Error when sending/receiving messages.
class MessageError extends GraphsyncError {
  /// Creates a message error with [message] and optional [cause].
  MessageError(String message, [dynamic cause])
    : super('Message error: $message', cause);
}

/// Error when request times out.
class RequestTimeoutError extends GraphsyncError {
  /// Creates a timeout error for [requestId].
  RequestTimeoutError(String requestId)
    : super('Request timed out: $requestId');
}

/// Error when handling graphsync requests.
class RequestHandlingError extends GraphsyncError {
  /// Creates a handling error with [message] and optional [cause].
  RequestHandlingError(String message, [dynamic cause])
    : super('Failed to handle request: $message', cause);
}

