// test/core/events/event_bus_test.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/events/event_bus.dart';
import 'package:test/test.dart';

void main() {
  group('EventBus', () {
    late EventBus eventBus;

    setUp(() {
      eventBus = EventBus();
    });

    tearDown(() {
      eventBus.dispose();
    });

    test('subscribe returns stream', () {
      final stream = eventBus.subscribe<String>();
      expect(stream, isA<Stream<String>>());
    });

    test('publish delivers event to subscriber', () async {
      final events = <String>[];
      final subscription = eventBus.subscribe<String>().listen(events.add);

      eventBus.publish('test-event');

      await Future.delayed(Duration(milliseconds: 50));
      expect(events, contains('test-event'));

      await subscription.cancel();
    });

    test('multiple subscribers receive same event', () async {
      final events1 = <int>[];
      final events2 = <int>[];

      final sub1 = eventBus.subscribe<int>().listen(events1.add);
      final sub2 = eventBus.subscribe<int>().listen(events2.add);

      eventBus.publish(42);

      await Future.delayed(Duration(milliseconds: 50));
      expect(events1, contains(42));
      expect(events2, contains(42));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('typed events are isolated', () async {
      final stringEvents = <String>[];
      final intEvents = <int>[];

      final sub1 = eventBus.subscribe<String>().listen(stringEvents.add);
      final sub2 = eventBus.subscribe<int>().listen(intEvents.add);

      eventBus.publish('hello');
      eventBus.publish(100);

      await Future.delayed(Duration(milliseconds: 50));
      expect(stringEvents, equals(['hello']));
      expect(intEvents, equals([100]));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('dispose closes all streams', () {
      eventBus.subscribe<String>();
      eventBus.subscribe<int>();
      eventBus.dispose();
      // We should not throw after dispose, streams are closed
    });
  });

  group('PeerConnectedEvent', () {
    test('stores peerId and address', () {
      final event = PeerConnectedEvent(
        peerId: 'QmPeer123',
        address: '/ip4/127.0.0.1/tcp/4001',
      );
      expect(event.peerId, equals('QmPeer123'));
      expect(event.address, contains('/ip4/'));
    });

    test('has timestamp', () {
      final event = PeerConnectedEvent(peerId: 'Qm', address: '/ip4/');
      expect(event.timestamp, isNotNull);
    });
  });

  group('BlockTransferEvent', () {
    test('stores transfer details', () {
      final event = BlockTransferEvent(
        cid: 'QmCid123',
        peerId: 'QmPeer456',
        type: TransferType.received,
        size: 1024,
      );
      expect(event.cid, equals('QmCid123'));
      expect(event.peerId, equals('QmPeer456'));
      expect(event.type, equals(TransferType.received));
      expect(event.size, equals(1024));
    });

    test('sent transfer type', () {
      final event = BlockTransferEvent(
        cid: 'Qm',
        peerId: 'Qm',
        type: TransferType.sent,
        size: 512,
      );
      expect(event.type, equals(TransferType.sent));
    });
  });

  group('TransferType', () {
    test('has received value', () {
      expect(TransferType.values, contains(TransferType.received));
    });

    test('has sent value', () {
      expect(TransferType.values, contains(TransferType.sent));
    });
  });
}

