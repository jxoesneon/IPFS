import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:dart_ipfs/src/transport/router_interface.dart';

enum SignalingMessageType { offer, answer, candidate }

class SignalingMessage {
  final SignalingMessageType type;
  final String data;

  SignalingMessage(this.type, this.data);

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
    while (true) {
      final byte = bytes[offset++];
      result |= (byte & 0x7F) << shift;
      if (byte < 0x80) break;
      shift += 7;
    }
    return _VarintResult(result, offset);
  }
}

class _VarintResult {
  final int value;
  final int newOffset;
  _VarintResult(this.value, this.newOffset);
}

class SignalingProtocol {
  static const String id = '/libp2p/webrtc/signaling/0.0.1';

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

  Stream<SignalingMessage> get messages => _messageController.stream;

  void handleStream(libp2p.P2PStream<Uint8List> stream) async {
    try {
      while (!stream.isClosed) {
        // Protobuf messages in libp2p are often prefixed with varint length
        // but the spec might vary. Usually libp2p-mplex/yamux handles framing.
        // For webrtc signaling, it's a dedicated stream.

        // Let's assume standard libp2p length-prefixing if needed,
        // but often the underlying muxer handles it.
        // The spec says "messages are exchanged over the stream".

        final lengthPrefix = await _readVarint(stream);
        final messageBytes = await stream.read(lengthPrefix);
        final message = SignalingMessage.decode(messageBytes);
        _messageController.add(message);
      }
    } catch (e) {
      // Stream closed or error
    } finally {
      _messageController.close();
    }
  }

  Future<int> _readVarint(libp2p.P2PStream<Uint8List> stream) async {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = (await stream.read(1))[0];
      result |= (byte & 0x7F) << shift;
      if (byte < 0x80) break;
      shift += 7;
    }
    return result;
  }

  static Future<void> sendMessage(
    libp2p.P2PStream<Uint8List> stream,
    SignalingMessage msg,
  ) async {
    final bytes = msg.encode();
    final lenPrefix = SignalingMessage._encodeVarint(bytes.length);
    await stream.write(Uint8List.fromList([...lenPrefix, ...bytes]));
  }
}
