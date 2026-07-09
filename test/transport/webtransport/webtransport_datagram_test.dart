import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:dart_ipfs/src/transport/webtransport/webtransport_datagram.dart';

/// A mock backend for testing [WebTransportDatagram].
class _MockDatagramBackend implements WebTransportDatagramBackend {
  _MockDatagramBackend({this.acceptAll = true, this.maxSize = 1024});

  final bool acceptAll;
  final int maxSize;

  final List<Uint8List> sentDatagrams = [];
  final StreamController<Uint8List> _receiveController =
      StreamController<Uint8List>.broadcast();

  @override
  Future<bool> sendFn(Uint8List data) async {
    if (acceptAll) {
      sentDatagrams.add(Uint8List.fromList(data));
      return true;
    }
    return false;
  }

  @override
  Stream<Uint8List>? get receiveStream => _receiveController.stream;

  @override
  int Function()? get maxDatagramSizeFn =>
      () => maxSize;

  /// Simulates an incoming datagram from the peer.
  void simulateReceive(Uint8List data) {
    _receiveController.add(data);
  }

  /// Simulates the receive stream closing.
  void simulateDone() {
    _receiveController.close();
  }

  /// Simulates a receive error.
  void simulateError(Object error) {
    _receiveController.addError(error);
  }
}

void main() {
  group('WebTransportDatagram', () {
    late _MockDatagramBackend backend;
    late WebTransportDatagram datagram;

    setUp(() {
      backend = _MockDatagramBackend();
      datagram = WebTransportDatagram(backend: backend);
    });

    tearDown(() async {
      await datagram.close();
    });

    test('should initialize with correct default state', () {
      expect(datagram.isClosed, isFalse);
      expect(datagram.maxDatagramSize, equals(1024));
      expect(datagram.pendingQueueLength, equals(0));
      expect(datagram.stats.sentCount, equals(0));
      expect(datagram.stats.receivedCount, equals(0));
    });

    test('should send a datagram', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final result = await datagram.send(data);

      expect(result, isTrue);
      expect(backend.sentDatagrams, hasLength(1));
      expect(backend.sentDatagrams[0], equals(data));
      expect(datagram.stats.sentCount, equals(1));
      expect(datagram.stats.bytesSent, equals(3));
    });

    test('should send multiple datagrams', () async {
      await datagram.send(Uint8List.fromList([1]));
      await datagram.send(Uint8List.fromList([2, 3]));
      await datagram.send(Uint8List.fromList([4, 5, 6]));

      expect(backend.sentDatagrams, hasLength(3));
      expect(datagram.stats.sentCount, equals(3));
      expect(datagram.stats.bytesSent, equals(6));
    });

    test('should throw on oversized datagram', () async {
      final smallBackend = _MockDatagramBackend(maxSize: 10);
      final smallDatagram = WebTransportDatagram(
        backend: smallBackend,
        config: const WebTransportDatagramConfig(maxDatagramSize: 10),
      );

      final data = Uint8List.fromList(List.filled(15, 0));
      expect(() => smallDatagram.send(data), throwsArgumentError);
      expect(smallDatagram.stats.droppedCount, equals(1));
      expect(smallDatagram.stats.sentCount, equals(0));

      await smallDatagram.close();
    });

    test('should throw on empty datagram', () async {
      expect(() => datagram.send(Uint8List(0)), throwsArgumentError);
      expect(datagram.stats.droppedCount, equals(1));
    });

    test('should throw when sending on closed channel', () async {
      await datagram.close();

      expect(() => datagram.send(Uint8List.fromList([1])), throwsStateError);
    });

    test('should return false when backend rejects datagram', () async {
      final rejectBackend = _MockDatagramBackend(acceptAll: false);
      final rejectDatagram = WebTransportDatagram(backend: rejectBackend);

      final result = await rejectDatagram.send(Uint8List.fromList([1]));

      expect(result, isFalse);
      expect(rejectDatagram.stats.sentCount, equals(0));
      expect(rejectDatagram.stats.droppedCount, equals(1));

      await rejectDatagram.close();
    });

    test('should trySend without throwing', () async {
      final rejectBackend = _MockDatagramBackend(acceptAll: false);
      final rejectDatagram = WebTransportDatagram(backend: rejectBackend);

      final result = await rejectDatagram.trySend(Uint8List.fromList([1]));

      expect(result, isFalse);
      expect(rejectDatagram.stats.droppedCount, equals(1));

      await rejectDatagram.close();
    });

    test('should trySend oversized datagram without throwing', () async {
      final smallBackend = _MockDatagramBackend(maxSize: 10);
      final smallDatagram = WebTransportDatagram(
        backend: smallBackend,
        config: const WebTransportDatagramConfig(maxDatagramSize: 10),
      );

      final result = await smallDatagram.trySend(
        Uint8List.fromList(List.filled(15, 0)),
      );

      expect(result, isFalse);
      expect(smallDatagram.stats.droppedCount, equals(1));

      await smallDatagram.close();
    });

    test('should trySend empty datagram without throwing', () async {
      final result = await datagram.trySend(Uint8List(0));

      expect(result, isFalse);
      expect(datagram.stats.droppedCount, equals(1));
    });

    test('should receive datagrams via stream', () async {
      final received = <WebTransportDatagramEvent>[];
      final sub = datagram.datagramStream.listen(received.add);

      backend.simulateReceive(Uint8List.fromList([10, 20]));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received[0].data, equals([10, 20]));
      expect(received[0].size, equals(2));
      expect(received[0].receivedAt, isNotNull);
      expect(datagram.stats.receivedCount, equals(1));
      expect(datagram.stats.bytesReceived, equals(2));

      await sub.cancel();
    });

    test('should receive multiple datagrams', () async {
      final received = <WebTransportDatagramEvent>[];
      final sub = datagram.datagramStream.listen(received.add);

      backend.simulateReceive(Uint8List.fromList([1]));
      backend.simulateReceive(Uint8List.fromList([2, 3]));
      backend.simulateReceive(Uint8List.fromList([4, 5, 6]));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(3));
      expect(datagram.stats.receivedCount, equals(3));
      expect(datagram.stats.bytesReceived, equals(6));

      await sub.cancel();
    });

    test('should not receive datagrams after close', () async {
      final received = <WebTransportDatagramEvent>[];
      datagram.datagramStream.listen(received.add);

      await datagram.close();

      backend.simulateReceive(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
    });

    test('should close the datagram channel', () async {
      await datagram.close();

      expect(datagram.isClosed, isTrue);
    });

    test('should close idempotently', () async {
      await datagram.close();
      await datagram.close(); // Should not throw

      expect(datagram.isClosed, isTrue);
    });

    test('should handle backend stream done', () async {
      final doneBackend = _MockDatagramBackend();
      final doneDatagram = WebTransportDatagram(backend: doneBackend);

      doneBackend.simulateDone();
      await Future<void>.delayed(Duration.zero);

      expect(doneDatagram.isClosed, isTrue);
    });

    test('should forward receive errors to stream', () async {
      final errors = <Object>[];
      datagram.datagramStream.listen((_) {}, onError: errors.add);

      backend.simulateError('test error');
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
    });

    test('should use minimum of config and backend max size', () async {
      final smallBackend = _MockDatagramBackend(maxSize: 256);
      final datagramWithSmallBackend = WebTransportDatagram(
        backend: smallBackend,
        config: const WebTransportDatagramConfig(maxDatagramSize: 1024),
      );

      expect(datagramWithSmallBackend.maxDatagramSize, equals(256));

      await datagramWithSmallBackend.close();
    });

    test(
      'should use config max size when backend has no size function',
      () async {
        final noSizeBackend = _MockDatagramBackend();
        // Override to return null for maxDatagramSizeFn
        final datagramNoSize = WebTransportDatagram(
          backend: _NullSizeBackend(),
          config: const WebTransportDatagramConfig(maxDatagramSize: 512),
        );

        expect(datagramNoSize.maxDatagramSize, equals(512));

        await datagramNoSize.close();
      },
    );

    test('should apply backpressure when queue is full', () async {
      final slowBackend = _SlowBackend();
      final smallQueueDatagram = WebTransportDatagram(
        backend: slowBackend,
        config: const WebTransportDatagramConfig(maxQueueSize: 2),
      );

      // Start 3 sends concurrently; the third should be dropped
      final results = await Future.wait([
        smallQueueDatagram.trySend(Uint8List.fromList([1])),
        smallQueueDatagram.trySend(Uint8List.fromList([2])),
        smallQueueDatagram.trySend(Uint8List.fromList([3])),
      ]);

      // At least one should be dropped due to backpressure
      expect(results.any((r) => r == false), isTrue);
      expect(smallQueueDatagram.stats.droppedCount, greaterThanOrEqualTo(1));

      await smallQueueDatagram.close();
    });

    test('should track stats correctly', () async {
      // Send some datagrams
      await datagram.send(Uint8List.fromList([1, 2]));
      await datagram.send(Uint8List.fromList([3, 4, 5]));

      // Receive some datagrams
      backend.simulateReceive(Uint8List.fromList([6, 7]));
      backend.simulateReceive(Uint8List.fromList([8, 9, 10]));
      await Future<void>.delayed(Duration.zero);

      expect(datagram.stats.sentCount, equals(2));
      expect(datagram.stats.bytesSent, equals(5));
      expect(datagram.stats.receivedCount, equals(2));
      expect(datagram.stats.bytesReceived, equals(5));
    });

    test('should reset stats', () {
      datagram.stats.sentCount = 5;
      datagram.stats.receivedCount = 3;

      datagram.stats.reset();

      expect(datagram.stats.sentCount, equals(0));
      expect(datagram.stats.receivedCount, equals(0));
      expect(datagram.stats.bytesSent, equals(0));
      expect(datagram.stats.bytesReceived, equals(0));
      expect(datagram.stats.droppedCount, equals(0));
    });
  });

  group('WebTransportDatagramStats', () {
    test('should have a string representation', () {
      final stats = WebTransportDatagramStats(
        sentCount: 5,
        receivedCount: 3,
        bytesSent: 100,
        bytesReceived: 60,
        droppedCount: 2,
      );

      final str = stats.toString();
      expect(str, contains('sent: 5'));
      expect(str, contains('received: 3'));
      expect(str, contains('dropped: 2'));
    });
  });

  group('DatagramSizeNegotiator', () {
    test('should return local max when remote is unknown', () {
      final negotiator = DatagramSizeNegotiator(
        localMaxSize: 1024,
        remoteMaxSize: null,
      );

      expect(negotiator.negotiatedMaxSize, equals(1024));
      expect(negotiator.isNegotiated, isFalse);
    });

    test('should return minimum of local and remote', () {
      final negotiator = DatagramSizeNegotiator(
        localMaxSize: 1024,
        remoteMaxSize: 512,
      );

      expect(negotiator.negotiatedMaxSize, equals(512));
      expect(negotiator.isNegotiated, isTrue);
    });

    test('should return local when local is smaller', () {
      final negotiator = DatagramSizeNegotiator(
        localMaxSize: 256,
        remoteMaxSize: 1024,
      );

      expect(negotiator.negotiatedMaxSize, equals(256));
    });

    test('should update remote max size', () {
      final negotiator = DatagramSizeNegotiator(
        localMaxSize: 1024,
        remoteMaxSize: null,
      );

      expect(negotiator.isNegotiated, isFalse);

      negotiator.updateRemoteMaxSize(512);
      expect(negotiator.isNegotiated, isTrue);
      expect(negotiator.negotiatedMaxSize, equals(512));
    });

    test('should update local max size', () {
      final negotiator = DatagramSizeNegotiator(
        localMaxSize: 1024,
        remoteMaxSize: 1024,
      );

      negotiator.updateLocalMaxSize(256);
      expect(negotiator.negotiatedMaxSize, equals(256));
    });

    test('should validate datagram size', () {
      final negotiator = DatagramSizeNegotiator(
        localMaxSize: 100,
        remoteMaxSize: 50,
      );

      expect(
        negotiator.validate(Uint8List.fromList(List.filled(40, 0))),
        isTrue,
      );
      expect(
        negotiator.validate(Uint8List.fromList(List.filled(50, 0))),
        isTrue,
      );
      expect(
        negotiator.validate(Uint8List.fromList(List.filled(51, 0))),
        isFalse,
      );
    });
  });

  group('WebTransportDatagramEvent', () {
    test('should expose size', () {
      final event = WebTransportDatagramEvent(
        data: Uint8List.fromList([1, 2, 3, 4]),
        receivedAt: DateTime.now(),
      );

      expect(event.size, equals(4));
    });

    test('should store timestamp', () {
      final ts = DateTime.now();
      final event = WebTransportDatagramEvent(
        data: Uint8List.fromList([1]),
        timestamp: ts,
      );

      expect(event.timestamp, equals(ts));
    });
  });
}

/// A backend that returns null for maxDatagramSizeFn.
class _NullSizeBackend implements WebTransportDatagramBackend {
  @override
  Future<bool> sendFn(Uint8List data) async => true;

  @override
  Stream<Uint8List>? get receiveStream => null;

  @override
  int Function()? get maxDatagramSizeFn => null;
}

/// A backend that delays sends to simulate backpressure.
class _SlowBackend implements WebTransportDatagramBackend {
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();

  @override
  Future<bool> sendFn(Uint8List data) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return true;
  }

  @override
  Stream<Uint8List>? get receiveStream => _controller.stream;

  @override
  int Function()? get maxDatagramSizeFn =>
      () => 1024;
}
