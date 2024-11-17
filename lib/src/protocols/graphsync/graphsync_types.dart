// src/protocols/graphsync/graphsync_types.dart
/// Standard Graphsync priority levels according to IPFS spec
enum GraphsyncPriority {
  low(1),
  normal(2),
  high(3),
  urgent(4);

  final int value;
  const GraphsyncPriority(this.value);
}

/// Standard Graphsync response status codes
enum GraphsyncStatus {
  inProgress,
  requestPaused,
  requestPausedPendingResources,
  completed,
  error,
  cancelled,
}

/// Standard Graphsync message types
enum GraphsyncMessageType {
  request,
  response,
  complete,
  cancel,
  progress,
  error,
}

/// Standard Graphsync extension keys according to IPFS spec
class GraphsyncExtensions {
  static const doNotSendCids = "graphsync/do-not-send-cids";
  static const responseMetadata = "graphsync/response-metadata";
  static const requestPriority = "graphsync/request-priority";
  static const blockHolesPresent = "graphsync/block-holes-present";
  static const partialResponse = "graphsync/partial-response";
}

/// Standard Graphsync metadata keys
class GraphsyncMetadata {
  static const totalSize = 'total-size';
  static const blockCount = 'block-count';
  static const transferRate = 'transfer-rate';
}
