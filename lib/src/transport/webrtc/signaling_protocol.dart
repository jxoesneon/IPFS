import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;

import '../router_interface.dart';

/// The type of a signaling message.
enum SignalingMessageType {
  /// SDP offer.
  offer,

  /// SDP answer.
  answer,

  /// ICE candidate.
  candidate,
}

/// A message exchanged over the WebRTC signaling protocol.
class SignalingMessage {
  /// Creates a new [SignalingMessage].
  SignalingMessage(this.type, this.data);

  /// The type of message.
  final SignalingMessageType type;

  /// The message data (SDP or ICE candidate string).
  final String data;

  /// Encodes this message into a protobuf-compatible byte array.
  Uint8List encode() {
    final dataBytes = utf8.encode(data);
    final typeValue = type.index;

    // Proto encoding:
    // tag 1 (type): 1 << 3 | 0 = 8
    // tag 2 (data): 2 << 3 | 2 = 18

    final List<int> result = [];
    result.add(8);
    result.addAll(_encodeVarint(typeValue));
    result.add(18);
    result.addAll(_encodeVarint(dataBytes.length));
    result.addAll(dataBytes);

    return Uint8List.fromList(result);
  }

  /// Decodes a signaling message from a protobuf-compatible byte array.
  static SignalingMessage decode(Uint8List bytes) {
    var offset = 0;
    SignalingMessageType? type;
    String? data;

    while (offset < bytes.length) {
      final tag = bytes[offset++];
      final fieldNumber = tag >> 3;
      final wireType = tag & 0x07;

      if (fieldNumber == 1 && wireType == 0) {
        final val = _decodeVarint(bytes, offset);
        type = SignalingMessageType.values[val.value];
        offset = val.newOffset;
      } else if (fieldNumber == 2 && wireType == 2) {
        final lenVal = _decodeVarint(bytes, offset);
        offset = lenVal.newOffset;
        data = utf8.decode(bytes.sublist(offset, offset + lenVal.value));
        offset += lenVal.value;
      } else {
        // Skip unknown field
        if (wireType == 0) {
          offset = _decodeVarint(bytes, offset).newOffset;
        } else if (wireType == 2) {
          final len = _decodeVarint(bytes, offset);
          offset = len.newOffset + len.value;
        } else {
          throw Exception('Unsupported wire type: $wireType');
        }
      }
    }

    if (type == null || data == null) {
      throw Exception('Missing required fields in SignalingMessage');
    }
    return SignalingMessage(type, data);
  }

  static List<int> _encodeVarint(int value) {
    final List<int> res = [];
    while (value >= 0x80) {
      res.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    res.add(value);
    return res;
  }

  static _VarintResult _decodeVarint(Uint8List bytes, int offset) {
    var result = 0;
    var shift = 0;
    var currentOffset = offset;
    while (true) {
      final byte = bytes[currentOffset++];
      result |= (byte & 0x7F) << shift;
      if (byte < 0x80) break;
      shift += 7;
    }
    return _VarintResult(result, currentOffset);
  }
}

class _VarintResult {
  _VarintResult(this.value, this.newOffset);
  final int value;
  final int newOffset;
}

/// Implementation of the WebRTC signaling protocol for libp2p.
class SignalingProtocol {
  /// Creates a new [SignalingProtocol] handler.
  SignalingProtocol();

  /// The protocol identifier.
  static const String id = '/libp2p/webrtc/signaling/0.0.1';

  /// Registers the protocol handler with the given router.
  static void register(RouterInterface router) {
    router.registerProtocolHandler(id, (packet) {
      // The Libp2pRouter.registerProtocolHandler already sets up a stream handler
      // and passes a NetworkPacket. But for WebRTC signaling, we might need
      // more direct access to the stream or a different integration.
      // For now, following the pattern in Libp2pRouter.
    });
  }

  final StreamController<SignalingMessage> _messageController =
      StreamController<SignalingMessage>.broadcast();

  /// Stream of signaling messages received.
  Stream<SignalingMessage> get messages => _messageController.stream;

  /// Handles an incoming signaling stream.
  void handleStream(libp2p.P2PStream<Uint8List> stream) async {
    try {
      while (!stream.isClosed) {
        final lengthPrefix = await _readVarint(stream);
        final messageBytes = await stream.read(lengthPrefix);
        final message = SignalingMessage.decode(messageBytes);
        _messageController.add(message);
      }
    } catch (e) {
      // Stream closed or error
    } finally {
      unawaited(_messageController.close());
    }
  }

  Future<int> _readVarint(libp2p.P2PStream<Uint8List> stream) async {
    var result = 0;
    var shift = 0;
    while (true) {
      final bytes = await stream.read(1);
      if (bytes.isEmpty) throw Exception('Stream closed while reading varint');
      final byte = bytes[0];
      result |= (byte & 0x7F) << shift;
      if (byte < 0x80) break;
      shift += 7;
    }
    return result;
  }

  /// Sends a signaling message over the given stream.
  static Future<void> sendMessage(
    libp2p.P2PStream<Uint8List> stream,
    SignalingMessage msg,
  ) async {
    final bytes = msg.encode();
    final lenPrefix = SignalingMessage._encodeVarint(bytes.length);
    await stream.write(Uint8List.fromList([...lenPrefix, ...bytes]));
  }
}
