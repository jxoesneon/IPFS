// src/protocols/graphsync/graphsync_protocol.dart
import 'dart:typed_data';
import 'package:dart_ipfs/src/proto/generated/graphsync/graphsync.pb.dart';
import 'package:dart_ipfs/src/protocols/graphsync/graphsync_types.dart';

/// Graphsync protocol message factory.
///
/// Creates request and response messages for the Graphsync protocol.
class GraphsyncProtocol {
  /// Protocol identifier.
  static const protocolID = '/ipfs/graphsync/1.0.0';

  /// Default request timeout.
  static const defaultTimeout = Duration(seconds: 60);

  /// Creates a Graphsync request message.
  GraphsyncMessage createRequest({
    required int id,
    required Uint8List root,
    required Uint8List selector,
    GraphsyncPriority priority = GraphsyncPriority.normal,
    Map<String, Uint8List>? extensions,
  }) {
    return GraphsyncMessage()
      ..requests.add(
        GraphsyncRequest()
          ..id = id
          ..root = root
          ..selector = selector
          ..priority = priority.value
          ..extensions.addAll(extensions ?? {}),
      );
  }

  GraphsyncMessage createCancelRequest(int requestId) {
    return GraphsyncMessage()
      ..requests.add(
        GraphsyncRequest()
          ..id = requestId
          ..cancel = true,
      );
  }

  GraphsyncMessage createPauseRequest(int requestId) {
    return GraphsyncMessage()
      ..requests.add(
        GraphsyncRequest()
          ..id = requestId
          ..pause = true,
      );
  }

  GraphsyncMessage createUnpauseRequest(int requestId) {
    return GraphsyncMessage()
      ..requests.add(
        GraphsyncRequest()
          ..id = requestId
          ..unpause = true,
      );
  }

  GraphsyncMessage createResponse({
    required int requestId,
    required ResponseStatus status,
    Map<String, Uint8List>? extensions,
    Map<String, String>? metadata,
    List<Block>? blocks,
  }) {
    final message = GraphsyncMessage()
      ..responses.add(
        GraphsyncResponse()
          ..id = requestId
          ..status = status
          ..extensions.addAll(extensions ?? {})
          ..metadata.addAll(metadata ?? {}),
      );

    if (blocks != null) {
      message.blocks.addAll(blocks);
    }

    return message;
  }

  GraphsyncMessage createProgressResponse({
    required int requestId,
    required int blocksProcessed,
    required int totalBlocks,
  }) {
    return createResponse(
      requestId: requestId,
      status: ResponseStatus.RS_IN_PROGRESS,
      metadata: {
        'blocksProcessed': blocksProcessed.toString(),
        'totalBlocks': totalBlocks.toString(),
      },
    );
  }
}
