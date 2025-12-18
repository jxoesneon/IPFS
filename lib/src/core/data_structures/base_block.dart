import 'dart:typed_data';
import 'package:dart_ipfs/src/core/cid.dart';

import '../../utils/encoding.dart';

/// Abstract base class for content-addressed blocks.
///
/// Provides common serialization/deserialization for block types.
abstract class BaseBlock {

  /// Creates a block with the given [data] and [cid].
  const BaseBlock(this.data, this.cid);
  /// The raw data payload.
  final Uint8List data;

  /// The content identifier.
  final CID cid;

  Uint8List toBytes() {
    final bytes = BytesBuilder();
    final cidBytes = EncodingUtils.cidToBytes(cid);
    bytes.addByte(cidBytes.length);
    bytes.add(cidBytes);
    bytes.add(data);
    return bytes.toBytes();
  }

  static T fromBytes<T extends BaseBlock>(
    Uint8List bytes,
    T Function(Uint8List data, CID cid) factory,
  ) {
    try {
      if (bytes.length < 3) {
        throw const FormatException('Invalid block bytes: too short');
      }

      final cidLength = bytes[0];
      if (bytes.length < cidLength + 2) {
        throw const FormatException('Invalid block bytes: incomplete CID');
      }

      final cidBytes = bytes.sublist(1, cidLength + 1);
      if (!EncodingUtils.isValidCIDBytes(cidBytes)) {
        throw const FormatException('Invalid CID bytes');
      }

      final blockData = bytes.sublist(cidLength + 1);
      final cid = CID.fromBytes(cidBytes); // Changed to single argument

      return factory(blockData, cid);
    } catch (e) {
      throw FormatException('Failed to create block from bytes: $e');
    }
  }
}
