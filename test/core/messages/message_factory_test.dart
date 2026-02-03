import 'dart:typed_data';
import 'package:dart_ipfs/src/core/messages/message_factory.dart';
import 'package:dart_ipfs/src/proto/generated/base_messages.pb.dart';
import 'package:test/test.dart';

void main() {
  group('MessageFactory', () {
    test('createBaseMessage creates message with all fields', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final message = MessageFactory.createBaseMessage(
        protocolId: '/ipfs/test/1.0.0',
        payload: payload,
        senderId: 'peer123',
        type: IPFSMessage_MessageType.DHT,
      );

      expect(message.protocolId, equals('/ipfs/test/1.0.0'));
      expect(message.payload, equals(payload));
      expect(message.senderId, equals('peer123'));
      expect(message.type, equals(IPFSMessage_MessageType.DHT));
      expect(message.hasTimestamp(), isTrue);
    });

    test('createBaseMessage sets timestamp', () {
      final before = DateTime.now().millisecondsSinceEpoch;

      final message = MessageFactory.createBaseMessage(
        protocolId: '/ipfs/bitswap/1.2.0',
        payload: Uint8List(0),
        senderId: 'peer-x',
        type: IPFSMessage_MessageType.BITSWAP,
      );

      final after = DateTime.now().millisecondsSinceEpoch;
      final messageTime = message.timestamp.seconds.toInt() * 1000;

      expect(messageTime, greaterThanOrEqualTo(before ~/ 1000 * 1000));
      expect(messageTime, lessThanOrEqualTo(after));
    });

    test('createBaseMessage handles empty payload', () {
      final message = MessageFactory.createBaseMessage(
        protocolId: '/test',
        payload: Uint8List(0),
        senderId: 'peer1',
        type: IPFSMessage_MessageType.PING,
      );

      expect(message.payload, isEmpty);
    });

    test('createBaseMessage handles different message types', () {
      for (final type in IPFSMessage_MessageType.values) {
        final message = MessageFactory.createBaseMessage(
          protocolId: '/test',
          payload: Uint8List(0),
          senderId: 'peer',
          type: type,
        );

        expect(message.type, equals(type));
      }
    });
  });
}

