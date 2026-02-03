// test/transport/router_events_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkMessage', () {
    test('stores data correctly', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final message = NetworkMessage(data);
      expect(message.data, equals(data));
    });

    test('fromBytes creates message', () {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final message = NetworkMessage.fromBytes(bytes);
      expect(message.data, equals(bytes));
    });
  });

  group('NetworkPacket', () {
    test('stores srcPeerId and datagram', () {
      final packet = NetworkPacket(
        srcPeerId: 'QmPeer123',
        datagram: Uint8List.fromList([1, 2, 3]),
      );
      expect(packet.srcPeerId, equals('QmPeer123'));
      expect(packet.datagram.length, equals(3));
    });
  });

  group('ConnectionEvent', () {
    test('connected event has correct type', () {
      final event = ConnectionEvent(
        type: ConnectionEventType.connected,
        peerId: 'QmPeer',
      );
      expect(event.type, equals(ConnectionEventType.connected));
    });

    test('disconnected event has correct type', () {
      final event = ConnectionEvent(
        type: ConnectionEventType.disconnected,
        peerId: 'QmPeer',
      );
      expect(event.type, equals(ConnectionEventType.disconnected));
    });
  });

  group('MessageEvent', () {
    test('stores peerId and message', () {
      final event = MessageEvent(
        peerId: 'QmSender',
        message: Uint8List.fromList([1, 2, 3]),
      );
      expect(event.peerId, equals('QmSender'));
      expect(event.message.length, equals(3));
    });
  });

  group('DHTEvent', () {
    test('valueFound event with data', () {
      final event = DHTEvent(
        type: DHTEventType.valueFound,
        data: {'key': 'value'},
      );
      expect(event.type, equals(DHTEventType.valueFound));
      expect(event.data['key'], equals('value'));
    });

    test('providerFound event', () {
      final event = DHTEvent(
        type: DHTEventType.providerFound,
        data: {
          'providers': ['peer1', 'peer2'],
        },
      );
      expect(event.type, equals(DHTEventType.providerFound));
    });
  });

  group('PubSubEvent', () {
    test('stores all fields', () {
      final event = PubSubEvent(
        topic: 'my-topic',
        message: Uint8List.fromList([1]),
        publisher: 'QmPublisher',
        eventType: 'message',
      );
      expect(event.topic, equals('my-topic'));
      expect(event.publisher, equals('QmPublisher'));
      expect(event.eventType, equals('message'));
    });
  });

  group('ErrorEvent', () {
    test('connectionError type', () {
      final event = ErrorEvent(
        type: ErrorEventType.connectionError,
        message: 'Connection failed',
      );
      expect(event.type, equals(ErrorEventType.connectionError));
      expect(event.message, contains('failed'));
    });

    test('all error types exist', () {
      expect(ErrorEventType.values, contains(ErrorEventType.connectionError));
      expect(
        ErrorEventType.values,
        contains(ErrorEventType.disconnectionError),
      );
      expect(ErrorEventType.values, contains(ErrorEventType.messageError));
    });
  });

  group('StreamEvent', () {
    test('opened event', () {
      final event = StreamEvent(
        type: StreamEventType.opened,
        streamId: 'stream-123',
      );
      expect(event.type, equals(StreamEventType.opened));
      expect(event.streamId, equals('stream-123'));
      expect(event.data, isNull);
    });

    test('data event with payload', () {
      final event = StreamEvent(
        type: StreamEventType.data,
        streamId: 'stream-456',
        data: Uint8List.fromList([1, 2, 3]),
      );
      expect(event.type, equals(StreamEventType.data));
      expect(event.data, isNotNull);
    });

    test('closed event', () {
      final event = StreamEvent(
        type: StreamEventType.closed,
        streamId: 'stream-789',
      );
      expect(event.type, equals(StreamEventType.closed));
    });
  });
}
