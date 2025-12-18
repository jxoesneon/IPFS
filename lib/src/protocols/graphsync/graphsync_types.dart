// src/protocols/graphsync/graphsync_types.dart
/// Standard Graphsync priority levels according to IPFS spec.
enum GraphsyncPriority {
  /// Low priority request.
  low(1),

  /// Normal priority request.
  normal(2),

  /// High priority request.
  high(3),

  /// Urgent priority request.
  urgent(4);

  /// Creates a priority with the given [value].
  const GraphsyncPriority(this.value);

  /// The numeric priority value.
  final int value;
}

/// Standard Graphsync response status codes.
enum GraphsyncStatus {
  /// Request is being processed.
  inProgress,

  /// Request is paused.
  requestPaused,

  /// Request paused pending resources.
  requestPausedPendingResources,

  /// Request completed successfully.
  completed,

  /// Request failed with an error.
  error,

  /// Request was cancelled.
  cancelled,
}

/// Standard Graphsync message types.
enum GraphsyncMessageType {
  /// A request message.
  request,

  /// A response message.
  response,

  /// Request completion.
  complete,

  /// Request cancellation.
  cancel,

  /// Progress update.
  progress,

  /// Error notification.
  error,
}

/// Standard Graphsync extension keys according to IPFS spec.
class GraphsyncExtensions {
  /// Extension to exclude specific CIDs.
  static const String doNotSendCids = 'graphsync/do-not-send-cids';

  /// Extension for response metadata.
  static const String responseMetadata = 'graphsync/response-metadata';

  /// Extension for request priority.
  static const String requestPriority = 'graphsync/request-priority';

  /// Extension indicating block holes.
  static const String blockHolesPresent = 'graphsync/block-holes-present';

  /// Extension for partial responses.
  static const String partialResponse = 'graphsync/partial-response';
}

/// Standard Graphsync metadata keys.
class GraphsyncMetadata {
  /// Metadata key for total transfer size.
  static const totalSize = 'total-size';

  /// Metadata key for block count.
  static const blockCount = 'block-count';

  /// Metadata key for transfer rate.
  static const transferRate = 'transfer-rate';
}
