import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:dart_ipfs/src/transport/webtransport/webtransport_session.dart';

/// A mock backend for testing [WebTransportSession].
class _MockSessionBackend implements WebTransportSessionBackend {
  _MockSessionBackend({
    this.bidiStreamFail = false,
    this.uniStreamFail = false,
    this.datagramFail = false,
  });

  final bool bidiStreamFail;
  final bool uniStreamFail;
  final bool datagramFail;

  int nextBidiId = 0;
  int nextUniId = 0;
  int closeCallCount = 0;
  int drainCallCount = 0;
  int? lastErrorCode;
  String? lastReasonPhrase;

  final List<Uint8List> sentDatagrams = [];

  final StreamController<WebTransportBidiStream> _incomingBidiController =
      StreamController<WebTransportBidiStream>.broadcast();
  final StreamController<WebTransportUniStream> _incomingUniController =
      StreamController<WebTransportUniStream>.broadcast();
  final StreamController<Uint8List> _incomingDatagramController =
      StreamController<Uint8List>.broadcast();

  /// Simulates an incoming bidirectional stream from the peer.
  void simulateIncomingBidiStream(WebTransportBidiStream stream) {
    _incomingBidiController.add(stream);
  }

  /// Simulates an incoming unidirectional stream from the peer.
  void simulateIncomingUniStream(WebTransportUniStream stream) {
    _incomingUniController.add(stream);
  }

  /// Simulates an incoming datagram from the peer.
  void simulateIncomingDatagram(Uint8List data) {
    _incomingDatagramController.add(data);
  }

  @override
  Future<WebTransportBidiStream> openBidirectionalStream() async {
    if (bidiStreamFail) {
      throw StateError('Failed to open bidirectional stream');
    }
    final id = nextBidiId;
    nextBidiId += 4; // QUIC stream IDs increment by 4
    return _createMockBidiStream(id);
  }

  @override
  Future<WebTransportUniStream> openUnidirectionalStream() async {
    if (uniStreamFail) {
      throw StateError('Failed to open unidirectional stream');
    }
    final id = nextUniId + 2; // Unidirectional streams have bit 1 set
    nextUniId += 4;
    return _createMockUniStream(id);
  }

  @override
  Future<void> sendDatagram(Uint8List data) async {
    if (datagramFail) {
      throw StateError('Failed to send datagram');
    }
    sentDatagrams.add(Uint8List.fromList(data));
  }

  @override
  Future<void> closeSession({int errorCode = 0, String? reasonPhrase}) async {
    closeCallCount++;
    lastErrorCode = errorCode;
    lastReasonPhrase = reasonPhrase;
  }

  @override
  Future<void> sendDrain() async {
    drainCallCount++;
  }

  @override
  Stream<WebTransportBidiStream>? get incomingBidiStreams =>
      _incomingBidiController.stream;

  @override
  Stream<WebTransportUniStream>? get incomingUniStreams =>
      _incomingUniController.stream;

  @override
  Stream<Uint8List>? get incomingDatagrams =>
      _incomingDatagramController.stream;

  WebTransportBidiStream _createMockBidiStream(int id) {
    return WebTransportBidiStream(
      id: id,
      writeFn: (_) async {},
      readFn: ([_]) async => null,
      closeFn: () async {},
      resetFn: () async {},
    );
  }

  WebTransportUniStream _createMockUniStream(int id) {
    return WebTransportUniStream(
      id: id,
      writeFn: (_) async {},
      closeFn: () async {},
      resetFn: () async {},
    );
  }

  Future<void> closeControllers() async {
    await _incomingBidiController.close();
    await _incomingUniController.close();
    await _incomingDatagramController.close();
  }
}

void main() {
  group('WebTransportSession', () {
    late _MockSessionBackend backend;
    late WebTransportSession session;

    setUp(() {
      backend = _MockSessionBackend();
      session = WebTransportSession(sessionId: 0, backend: backend);
    });

    tearDown(() async {
      await session.close();
      await backend.closeControllers();
    });

    test('should initialize with correct default state', () {
      expect(session.sessionId, equals(0));
      expect(session.isClosed, isFalse);
      expect(session.isDraining, isFalse);
      expect(session.isActive, isTrue);
      expect(session.receivedGoaway, isFalse);
      expect(session.openBidiStreamCount, equals(0));
      expect(session.openUniStreamCount, equals(0));
      expect(session.stats.openedAt, isNotNull);
      expect(session.stats.closedAt, isNull);
    });

    test('should open a bidirectional stream', () async {
      final stream = await session.openBidirectionalStream();

      expect(stream.id, equals(0));
      expect(stream.isClosed, isFalse);
      expect(session.openBidiStreamCount, equals(1));
      expect(session.bidiStreams, hasLength(1));
      expect(session.stats.bidiStreamsOpened, equals(1));
    });

    test(
      'should open multiple bidirectional streams with incrementing IDs',
      () async {
        final stream1 = await session.openBidirectionalStream();
        final stream2 = await session.openBidirectionalStream();

        expect(stream1.id, equals(0));
        expect(stream2.id, equals(4));
        expect(session.openBidiStreamCount, equals(2));
        expect(session.stats.bidiStreamsOpened, equals(2));
      },
    );

    test('should open a unidirectional stream', () async {
      final stream = await session.openUnidirectionalStream();

      expect(stream.id, equals(2)); // Uni streams have bit 1 set
      expect(stream.isClosed, isFalse);
      expect(session.openUniStreamCount, equals(1));
      expect(session.uniStreams, hasLength(1));
      expect(session.stats.uniStreamsOpened, equals(1));
    });

    test('should throw when opening stream on closed session', () async {
      await session.close();

      expect(() => session.openBidirectionalStream(), throwsStateError);
      expect(() => session.openUnidirectionalStream(), throwsStateError);
    });

    test('should throw when opening stream on draining session', () async {
      await session.initiateDrain();

      expect(() => session.openBidirectionalStream(), throwsStateError);
      expect(() => session.openUnidirectionalStream(), throwsStateError);
    });

    test('should send a datagram', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      await session.sendDatagram(data);

      expect(backend.sentDatagrams, hasLength(1));
      expect(backend.sentDatagrams[0], equals(data));
      expect(session.stats.datagramsSent, equals(1));
      expect(session.stats.bytesSent, equals(5));
    });

    test('should throw when sending oversized datagram', () async {
      final config = WebTransportSessionConfig(maxDatagramSize: 10);
      final smallSession = WebTransportSession(
        sessionId: 1,
        backend: backend,
        config: config,
      );

      final data = Uint8List.fromList(List.filled(20, 0));
      expect(() => smallSession.sendDatagram(data), throwsArgumentError);
      expect(smallSession.stats.datagramsSent, equals(0));
    });

    test('should throw when sending datagram on closed session', () async {
      await session.close();

      expect(
        () => session.sendDatagram(Uint8List.fromList([1])),
        throwsStateError,
      );
    });

    test('should close session gracefully', () async {
      await session.close();

      expect(session.isClosed, isTrue);
      expect(session.isActive, isFalse);
      expect(session.stats.closedAt, isNotNull);
      expect(backend.closeCallCount, equals(1));
      expect(backend.lastErrorCode, equals(0));
    });

    test('should close session with error code and reason', () async {
      await session.close(errorCode: 42, reasonPhrase: 'test error');

      expect(session.isClosed, isTrue);
      expect(backend.lastErrorCode, equals(42));
      expect(backend.lastReasonPhrase, equals('test error'));
    });

    test('should close session idempotently', () async {
      await session.close();
      await session.close(); // Should not throw

      expect(backend.closeCallCount, equals(1));
    });

    test('should close all open streams when session closes', () async {
      final bidiStream = await session.openBidirectionalStream();
      final uniStream = await session.openUnidirectionalStream();

      expect(bidiStream.isClosed, isFalse);
      expect(uniStream.isClosed, isFalse);

      await session.close();

      expect(bidiStream.isClosed, isTrue);
      expect(uniStream.isClosed, isTrue);
      expect(session.openBidiStreamCount, equals(0));
      expect(session.openUniStreamCount, equals(0));
    });

    test('should initiate drain', () async {
      await session.initiateDrain();

      expect(session.isDraining, isTrue);
      expect(session.isActive, isFalse);
      expect(backend.drainCallCount, equals(1));
    });

    test('should throw when initiating drain on closed session', () async {
      await session.close();

      expect(() => session.initiateDrain(), throwsStateError);
    });

    test('should handle peer close', () {
      session.onPeerClose(errorCode: 10);

      expect(session.isClosed, isTrue);
      expect(session.isActive, isFalse);
      expect(backend.closeCallCount, equals(0)); // No close sent to peer
    });

    test('should handle peer drain', () {
      session.onPeerDrain();

      expect(session.isDraining, isTrue);
      expect(session.isActive, isFalse);
    });

    test('should handle GOAWAY from peer', () {
      session.onGoawayReceived();

      expect(session.receivedGoaway, isTrue);
    });

    test('should receive incoming datagrams', () async {
      final received = <Uint8List>[];
      final sub = session.incomingDatagrams.listen(received.add);

      backend.simulateIncomingDatagram(Uint8List.fromList([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received[0], equals([1, 2, 3]));
      expect(session.stats.datagramsReceived, equals(1));
      expect(session.stats.bytesReceived, equals(3));

      await sub.cancel();
    });

    test('should receive incoming bidirectional streams', () async {
      final received = <WebTransportBidiStream>[];
      final sub = session.incomingBidiStreams.listen(received.add);

      final mockStream = WebTransportBidiStream(
        id: 99,
        writeFn: (_) async {},
        readFn: ([_]) async => null,
        closeFn: () async {},
        resetFn: () async {},
      );
      backend.simulateIncomingBidiStream(mockStream);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received[0].id, equals(99));
      expect(session.openBidiStreamCount, equals(1));

      await sub.cancel();
    });

    test('should receive incoming unidirectional streams', () async {
      final received = <WebTransportUniStream>[];
      final sub = session.incomingUniStreams.listen(received.add);

      final mockStream = WebTransportUniStream(
        id: 77,
        writeFn: (_) async {},
        closeFn: () async {},
        resetFn: () async {},
      );
      backend.simulateIncomingUniStream(mockStream);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received[0].id, equals(77));
      expect(session.openUniStreamCount, equals(1));

      await sub.cancel();
    });

    test('should not receive datagrams after close', () async {
      final received = <Uint8List>[];
      session.incomingDatagrams.listen(received.add);

      await session.close();

      backend.simulateIncomingDatagram(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
    });

    test('should remove stream from tracking', () async {
      final stream = await session.openBidirectionalStream();
      expect(session.openBidiStreamCount, equals(1));

      session.removeStream(stream.id);
      expect(session.openBidiStreamCount, equals(0));
    });

    test('should enforce max bidirectional stream limit', () async {
      final config = WebTransportSessionConfig(initialMaxStreamsBidi: 2);
      final limitedSession = WebTransportSession(
        sessionId: 5,
        backend: backend,
        config: config,
      );

      await limitedSession.openBidirectionalStream();
      await limitedSession.openBidirectionalStream();

      expect(() => limitedSession.openBidirectionalStream(), throwsStateError);

      await limitedSession.close();
    });

    test('should enforce max unidirectional stream limit', () async {
      final config = WebTransportSessionConfig(initialMaxStreamsUni: 1);
      final limitedSession = WebTransportSession(
        sessionId: 6,
        backend: backend,
        config: config,
      );

      await limitedSession.openUnidirectionalStream();

      expect(() => limitedSession.openUnidirectionalStream(), throwsStateError);

      await limitedSession.close();
    });

    test('should track session duration', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(session.stats.duration.inMilliseconds, greaterThanOrEqualTo(20));
    });
  });

  group('WebTransportBidiStream', () {
    test('should write and read data', () async {
      final written = <Uint8List>[];
      final stream = WebTransportBidiStream(
        id: 0,
        writeFn: (data) async {
          written.add(data);
        },
        readFn: ([len]) async => Uint8List.fromList([10, 20]),
        closeFn: () async {},
        resetFn: () async {},
      );

      await stream.write(Uint8List.fromList([1, 2, 3]));
      expect(written, hasLength(1));
      expect(written[0], equals([1, 2, 3]));

      final data = await stream.read();
      expect(data, equals([10, 20]));
    });

    test('should close gracefully', () async {
      var closed = false;
      final stream = WebTransportBidiStream(
        id: 0,
        writeFn: (_) async {},
        readFn: ([_]) async => null,
        closeFn: () async {
          closed = true;
        },
        resetFn: () async {},
      );

      await stream.close();
      expect(stream.isClosed, isTrue);
      expect(closed, isTrue);

      // Writing after close should throw
      expect(() => stream.write(Uint8List.fromList([1])), throwsStateError);
    });

    test('should reset abruptly', () async {
      var reset = false;
      final stream = WebTransportBidiStream(
        id: 0,
        writeFn: (_) async {},
        readFn: ([_]) async => null,
        closeFn: () async {},
        resetFn: () async {
          reset = true;
        },
      );

      await stream.reset();
      expect(stream.isClosed, isTrue);
      expect(reset, isTrue);
    });

    test('should close idempotently', () async {
      var closeCount = 0;
      final stream = WebTransportBidiStream(
        id: 0,
        writeFn: (_) async {},
        readFn: ([_]) async => null,
        closeFn: () async {
          closeCount++;
        },
        resetFn: () async {},
      );

      await stream.close();
      await stream.close();
      expect(closeCount, equals(1));
    });
  });

  group('WebTransportUniStream', () {
    test('should write data', () async {
      final written = <Uint8List>[];
      final stream = WebTransportUniStream(
        id: 2,
        writeFn: (data) async {
          written.add(data);
        },
        closeFn: () async {},
        resetFn: () async {},
      );

      await stream.write(Uint8List.fromList([4, 5, 6]));
      expect(written, hasLength(1));
      expect(written[0], equals([4, 5, 6]));
    });

    test('should close gracefully', () async {
      var closed = false;
      final stream = WebTransportUniStream(
        id: 2,
        writeFn: (_) async {},
        closeFn: () async {
          closed = true;
        },
        resetFn: () async {},
      );

      await stream.close();
      expect(stream.isClosed, isTrue);
      expect(closed, isTrue);
    });

    test('should reset abruptly', () async {
      var reset = false;
      final stream = WebTransportUniStream(
        id: 2,
        writeFn: (_) async {},
        closeFn: () async {},
        resetFn: () async {
          reset = true;
        },
      );

      await stream.reset();
      expect(stream.isClosed, isTrue);
      expect(reset, isTrue);
    });

    test('should throw when writing to closed stream', () async {
      final stream = WebTransportUniStream(
        id: 2,
        writeFn: (_) async {},
        closeFn: () async {},
        resetFn: () async {},
      );

      await stream.close();

      expect(() => stream.write(Uint8List.fromList([1])), throwsStateError);
    });
  });

  group('WebTransportSessionManager', () {
    late WebTransportSessionManager manager;

    setUp(() {
      manager = WebTransportSessionManager(maxSessions: 3);
    });

    test('should initialize with correct defaults', () {
      expect(manager.maxSessions, equals(3));
      expect(manager.sessionCount, equals(0));
      expect(manager.isFull, isFalse);
      expect(manager.sessions, isEmpty);
    });

    test('should register a session', () {
      final backend = _MockSessionBackend();
      final session = WebTransportSession(sessionId: 0, backend: backend);
      manager.registerSession(session);

      expect(manager.sessionCount, equals(1));
      expect(manager.getSession(0), same(session));
    });

    test('should throw when registering duplicate session', () {
      final backend = _MockSessionBackend();
      final session = WebTransportSession(sessionId: 0, backend: backend);
      manager.registerSession(session);

      expect(() => manager.registerSession(session), throwsStateError);
    });

    test('should enforce max sessions limit', () {
      final backend = _MockSessionBackend();
      for (var i = 0; i < 3; i++) {
        manager.registerSession(
          WebTransportSession(sessionId: i, backend: backend),
        );
      }

      expect(manager.isFull, isTrue);

      expect(
        () => manager.registerSession(
          WebTransportSession(sessionId: 3, backend: backend),
        ),
        throwsStateError,
      );
    });

    test('should remove a session', () {
      final backend = _MockSessionBackend();
      final session = WebTransportSession(sessionId: 0, backend: backend);
      manager.registerSession(session);

      manager.removeSession(0);
      expect(manager.sessionCount, equals(0));
      expect(manager.getSession(0), isNull);
    });

    test('should close all sessions', () async {
      final backend = _MockSessionBackend();
      for (var i = 0; i < 3; i++) {
        manager.registerSession(
          WebTransportSession(sessionId: i, backend: backend),
        );
      }

      await manager.closeAll();

      expect(manager.sessionCount, equals(0));
      expect(backend.closeCallCount, equals(3));
    });

    test('should cleanup inactive sessions', () async {
      final backend = _MockSessionBackend();
      final s1 = WebTransportSession(sessionId: 0, backend: backend);
      final s2 = WebTransportSession(sessionId: 1, backend: backend);
      final s3 = WebTransportSession(sessionId: 2, backend: backend);

      manager.registerSession(s1);
      manager.registerSession(s2);
      manager.registerSession(s3);

      // Close one and drain another
      await s1.close();
      await s2.initiateDrain();

      final removed = manager.cleanupInactive();
      expect(removed, equals(2));
      expect(manager.sessionCount, equals(1));
      expect(manager.getSession(2), isNotNull);
    });
  });

  group('WebTransportSettings', () {
    test('should build server settings', () {
      final settings = WebTransportSettings.buildServerSettings(
        maxSessions: 50,
        enableDatagrams: true,
      );

      expect(settings[WebTransportSettings.enableConnectProtocol], equals(1));
      expect(settings[WebTransportSettings.h3Datagram], equals(1));
      expect(settings[WebTransportSettings.wtEnabled], equals(1));
      expect(settings[WebTransportSettings.wtMaxSessions], equals(50));
    });

    test('should build server settings without datagrams', () {
      final settings = WebTransportSettings.buildServerSettings(
        enableDatagrams: false,
      );

      expect(settings.containsKey(WebTransportSettings.h3Datagram), isFalse);
    });

    test('should build client settings', () {
      final settings = WebTransportSettings.buildClientSettings();

      expect(settings[WebTransportSettings.enableConnectProtocol], equals(1));
      expect(settings[WebTransportSettings.h3Datagram], equals(1));
      expect(settings[WebTransportSettings.wtEnabled], equals(1));
    });

    test('should parse settings correctly', () {
      final settings = WebTransportSettings.buildServerSettings(
        maxSessions: 25,
        enableDatagrams: true,
        initialMaxData: 1024,
        initialMaxStreamsBidi: 10,
        initialMaxStreamsUni: 5,
      );

      final parsed = WebTransportSettings.parse(settings);

      expect(parsed.connectProtocolEnabled, isTrue);
      expect(parsed.h3DatagramEnabled, isTrue);
      expect(parsed.wtEnabled, isTrue);
      expect(parsed.wtInitialMaxData, equals(1024));
      expect(parsed.wtInitialMaxStreamsBidi, equals(10));
      expect(parsed.wtInitialMaxStreamsUni, equals(5));
      expect(parsed.wtMaxSessions, equals(25));
    });

    test('should detect WebTransport support', () {
      final parsed = WebTransportSettings.parse({
        WebTransportSettings.enableConnectProtocol: 1,
        WebTransportSettings.wtEnabled: 1,
      });

      expect(parsed.isWebTransportSupported, isTrue);
    });

    test('should detect lack of WebTransport support', () {
      final parsed = WebTransportSettings.parse({});

      expect(parsed.isWebTransportSupported, isFalse);
    });

    test('should detect datagram support', () {
      final parsed = WebTransportSettings.parse({
        WebTransportSettings.wtEnabled: 1,
        WebTransportSettings.h3Datagram: 1,
      });

      expect(parsed.areDatagramsSupported, isTrue);
    });

    test('should detect lack of datagram support', () {
      final parsed = WebTransportSettings.parse({
        WebTransportSettings.wtEnabled: 1,
      });

      expect(parsed.areDatagramsSupported, isFalse);
    });

    test('should default wtMaxSessions to wtInitialMaxStreamsBidi', () {
      final parsed = WebTransportSettings.parse({
        WebTransportSettings.wtInitialMaxStreamsBidi: 42,
      });

      expect(parsed.wtMaxSessions, equals(42));
    });

    test('should default wtMaxSessions to 100 when not specified', () {
      final parsed = WebTransportSettings.parse({});

      expect(parsed.wtMaxSessions, equals(100));
    });
  });
}
