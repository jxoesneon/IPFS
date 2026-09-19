import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/webrtc/signaling_protocol.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:test/test.dart';

/// Minimal [libp2p.P2PStream] backed by a fixed byte buffer. [read] returns
/// at most the requested number of bytes and an empty list once drained.
class _FakeSignalingStream implements libp2p.P2PStream<Uint8List> {
  _FakeSignalingStream(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  final Uint8List _bytes;
  var _offset = 0;
  var _closed = false;

  /// Total number of payload bytes consumed by [read] calls.
  int get bytesRead => _offset;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_closed || _offset >= _bytes.length) return Uint8List(0);
    final end = maxLength == null || _offset + maxLength > _bytes.length
        ? _bytes.length
        : _offset + maxLength;
    final chunk = Uint8List.fromList(_bytes.sublist(_offset, end));
    _offset = end;
    return chunk;
  }

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  List<int> varint(int value) {
    final out = <int>[];
    var n = value;
    while (n >= 0x80) {
      out.add((n & 0x7F) | 0x80);
      n >>= 7;
    }
    out.add(n);
    return out;
  }

  group('SignalingMessage', () {
    test('should encode and decode offer message', () {
      final sdp = 'v=0\r\no=- 4716491763137913264 2 IN IP4 127.0.0.1';
      final msg = SignalingMessage(SignalingMessageType.offer, sdp);

      final encoded = msg.encode();
      final decoded = SignalingMessage.decode(encoded);

      expect(decoded.type, equals(SignalingMessageType.offer));
      expect(decoded.data, equals(sdp));
    });

    test('should encode and decode candidate message', () {
      final candidate =
          'candidate:427067828 1 udp 2113937151 192.168.1.1 50000 typ host';
      final msg = SignalingMessage(SignalingMessageType.candidate, candidate);

      final encoded = msg.encode();
      final decoded = SignalingMessage.decode(encoded);

      expect(decoded.type, equals(SignalingMessageType.candidate));
      expect(decoded.data, equals(candidate));
    });

    test('should fail decoding invalid bytes', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3]);
      expect(() => SignalingMessage.decode(bytes), throwsException);
    });

    test('rejects an out-of-range message type without a RangeError', () {
      // field 1 (type) = 9, outside SignalingMessageType.values.
      final bytes = Uint8List.fromList([8, 9, 18, 0]);
      expect(() => SignalingMessage.decode(bytes), throwsFormatException);
    });

    test('rejects a data field length beyond the buffer', () {
      // field 2 declares 10 bytes but only 1 remains.
      final bytes = Uint8List.fromList([8, 0, 18, 10, 65]);
      expect(() => SignalingMessage.decode(bytes), throwsFormatException);
    });

    test('rejects a truncated varint', () {
      // field 1 varint has its continuation bit set but no next byte.
      final bytes = Uint8List.fromList([8, 0xFF]);
      expect(() => SignalingMessage.decode(bytes), throwsFormatException);
    });

    test('rejects an unknown field length beyond the buffer', () {
      // tag 26: field 3, wire type 2, declares 10 bytes with none present.
      final bytes = Uint8List.fromList([8, 0, 18, 0, 26, 10]);
      expect(() => SignalingMessage.decode(bytes), throwsFormatException);
    });

    test('rejects an unsupported wire type', () {
      // tag 0x21: field 4, wire type 1 (fixed64) — unsupported.
      final bytes = Uint8List.fromList([8, 0, 18, 0, 0x21]);
      expect(() => SignalingMessage.decode(bytes), throwsFormatException);
    });
  });

  group('SignalingProtocol.handleStream bounds', () {
    test('delivers a valid length-prefixed message', () async {
      final protocol = SignalingProtocol();
      final msg = SignalingMessage(SignalingMessageType.offer, 'sdp-offer');
      final body = msg.encode();
      final stream = _FakeSignalingStream([...varint(body.length), ...body]);

      final received = protocol.messages.first;
      protocol.handleStream(stream);

      final decoded = await received;
      expect(decoded.type, equals(SignalingMessageType.offer));
      expect(decoded.data, equals('sdp-offer'));
    });

    test('rejects an overlong varint prefix', () async {
      // Eleven continuation bytes: never terminates within the bound.
      final stream = _FakeSignalingStream(List<int>.filled(11, 0xFF));
      final protocol = SignalingProtocol();

      final done = protocol.messages.drain<void>();
      protocol.handleStream(stream);
      await done;

      // The prefix is rejected after the 10-byte cap; no body read follows.
      expect(stream.bytesRead, equals(10));
    });

    test(
      'rejects an oversized declared length before reading the body',
      () async {
        const cap = 4 * 1024 * 1024;
        final prefix = varint(cap + 1);
        final stream = _FakeSignalingStream(prefix);
        final protocol = SignalingProtocol();

        final done = protocol.messages.drain<void>();
        protocol.handleStream(stream);
        await done;

        // Only the prefix bytes were consumed — the handler never attempted
        // to read the advertised body.
        expect(stream.bytesRead, equals(prefix.length));
      },
    );

    test(
      'malformed message body terminates the handler without crashing',
      () async {
        // Valid 2-byte length prefix; body decodes to an unknown message type.
        final stream = _FakeSignalingStream([...varint(2), 8, 9]);
        final protocol = SignalingProtocol();

        final done = protocol.messages.drain<void>();
        protocol.handleStream(stream);
        await done;
      },
    );
  });
}
