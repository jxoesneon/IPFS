import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/transport/webrtc/signaling_protocol.dart';

void main() {
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
  });
}
