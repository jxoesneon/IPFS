// src/protocols/dht/dht_envelope.dart
import 'dart:convert';
import 'dart:typed_data';

/// Thin framing envelope for DHT request/response correlation.
///
/// Used when the underlying transport cannot correlate outbound DHT requests
/// with inbound responses transparently. The [requestId] is echoed back by
/// the responder so the caller can match the payload to a pending request.
class DHTEnvelope {
  /// Creates a new [DHTEnvelope] with the given [requestId] and [payload].
  DHTEnvelope({required this.requestId, required this.payload});

  /// Decodes a [DHTEnvelope] from [data].
  ///
  /// Throws [FormatException] if the encoding is malformed.
  factory DHTEnvelope.fromBytes(Uint8List data) {
    var offset = 0;
    final idLen = _readVarint(data, offset);
    offset += idLen.bytesRead;
    if (offset + idLen.value > data.length) {
      throw const FormatException('Invalid DHT envelope: request id truncated');
    }
    final idBytes = data.sublist(offset, offset + idLen.value);
    offset += idLen.value;
    final payloadLen = _readVarint(data, offset);
    offset += payloadLen.bytesRead;
    if (offset + payloadLen.value > data.length) {
      throw const FormatException('Invalid DHT envelope: payload truncated');
    }
    final payload = data.sublist(offset, offset + payloadLen.value);
    return DHTEnvelope(requestId: utf8.decode(idBytes), payload: payload);
  }

  /// The opaque request identifier echoed by the responder.
  final String requestId;

  /// The encapsulated DHT message payload.
  final Uint8List payload;

  /// Encodes this envelope as a length-prefixed byte stream.
  ///
  /// Format: `<request_id_length:varint> <request_id:utf8> <payload_length:varint> <payload:bytes>`
  Uint8List toBytes() {
    final idBytes = utf8.encode(requestId);
    final bb = BytesBuilder();
    _writeVarint(bb, idBytes.length);
    bb.add(idBytes);
    _writeVarint(bb, payload.length);
    bb.add(payload);
    return bb.toBytes();
  }

  static void _writeVarint(BytesBuilder bb, int value) {
    var v = value;
    while (v > 127) {
      bb.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    bb.addByte(v);
  }

  static ({int value, int bytesRead}) _readVarint(Uint8List data, int offset) {
    var value = 0;
    var shift = 0;
    var bytesRead = 0;
    while (true) {
      if (offset + bytesRead >= data.length) {
        throw const FormatException('Unexpected end of varint');
      }
      final byte = data[offset + bytesRead];
      bytesRead++;
      value |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift > 63) {
        throw const FormatException('Varint too large');
      }
    }
    return (value: value, bytesRead: bytesRead);
  }
}
