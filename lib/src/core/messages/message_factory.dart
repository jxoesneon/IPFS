import 'dart:typed_data';

import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart';
import 'package:fixnum/fixnum.dart';

/// Factory for creating IPFS protocol messages.
///
/// Provides convenience methods for constructing [IPFSMessage] instances
/// with proper timestamps and metadata.
class MessageFactory {
  /// Creates a base IPFS protocol message.
  static IPFSMessage createBaseMessage({
    required String protocolId,
    required Uint8List payload,
    required String senderId,
    required IPFSMessage_MessageType type,
  }) {
    final now = DateTime.now();
    final timestamp = Timestamp()
      ..seconds = Int64(now.millisecondsSinceEpoch ~/ 1000)
      ..nanos = (now.millisecondsSinceEpoch % 1000) * 1000000;

    return IPFSMessage()
      ..protocolId = protocolId
      ..payload = payload
      ..timestamp = timestamp
      ..senderId = senderId
      ..type = type;
  }
}
