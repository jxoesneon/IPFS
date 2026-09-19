import 'dart:typed_data';

/// Inbound read bounds shared by every length-prefixed protocol stream.
///
/// These bounds defend streams we did not dial against unbounded allocation
/// and drip-feed denial of service: varint length prefixes are capped at u64
/// width, message bodies at 4 MiB, each bulk read at 64 KiB, every read gets
/// a 30 s idle deadline, and the whole stream is closed after 5 minutes.
/// [Libp2pRouter]'s guarded dispatch loop and the WebRTC signaling stream
/// handler both read through this shared implementation.
class InboundMessageBounds {
  InboundMessageBounds._();

  /// Maximum size in bytes of a varint length prefix (u64).
  static const int maxVarintBytes = 10;

  /// Maximum inbound message body size accepted on protocol streams.
  static const int maxMessageSize = 4 * 1024 * 1024;

  /// Maximum bytes requested per bulk read on inbound streams.
  static const int readChunkSize = 64 * 1024;

  /// Idle deadline applied to each read on an inbound stream.
  static const Duration readIdleTimeout = Duration(seconds: 30);

  /// Total lifetime of an inbound stream. Without this, a peer can hold a
  /// stream open indefinitely by sending a byte inside each idle window
  /// (drip-feed DoS). Multi-message protocols get a generous bound.
  static const Duration maxStreamLifetime = Duration(minutes: 5);
}

/// Reads one varint-length-prefixed message, pulling body bytes through
/// [read]. Returns `null` when the source closes before a complete
/// message arrives. Throws [FormatException] when the varint prefix
/// exceeds [InboundMessageBounds.maxVarintBytes] or the advertised length
/// exceeds [InboundMessageBounds.maxMessageSize].
Future<Uint8List?> readLengthPrefixedMessage(
  Future<Uint8List?> Function(int size) read,
) async {
  // Read varint length prefix, bounded to u64 width.
  final lengthBytes = <int>[];
  while (true) {
    final chunk = await read(1);
    if (chunk == null || chunk.isEmpty) return null;
    lengthBytes.add(chunk[0]);
    if ((chunk[0] & 0x80) == 0) break;
    if (lengthBytes.length >= InboundMessageBounds.maxVarintBytes) {
      throw const FormatException('Varint length prefix exceeds maximum size');
    }
  }

  final length = decodeVarint(Uint8List.fromList(lengthBytes));
  if (length == 0) return Uint8List(0);
  if (length < 0 || length > InboundMessageBounds.maxMessageSize) {
    throw FormatException(
      'Inbound message length $length exceeds '
      '${InboundMessageBounds.maxMessageSize}',
    );
  }

  // Read message body in bounded chunks.
  final builder = BytesBuilder(copy: false);
  var remaining = length;
  while (remaining > 0) {
    final chunk = await read(
      remaining > InboundMessageBounds.readChunkSize
          ? InboundMessageBounds.readChunkSize
          : remaining,
    );
    if (chunk == null || chunk.isEmpty) return null;
    final take = chunk.length > remaining ? remaining : chunk.length;
    builder.add(Uint8List.fromList(chunk.sublist(0, take)));
    remaining -= take;
  }
  return builder.takeBytes();
}

/// Decodes a u64 varint. Throws [FormatException] when the encoding
/// would exceed 64 bits.
int decodeVarint(Uint8List bytes) {
  var result = 0;
  var shift = 0;
  for (final byte in bytes) {
    if (shift >= 64) {
      throw const FormatException('Varint exceeds 64 bits');
    }
    result |= (byte & 0x7F) << shift;
    if ((byte & 0x80) == 0) break;
    shift += 7;
  }
  return result;
}
