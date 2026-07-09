import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:dart_ipfs/src/transport/webtransport/webtransport_transport.dart';
import 'package:dart_ipfs/src/transport/webtransport/webtransport_session.dart';
import 'package:dart_ipfs/src/transport/webtransport/webtransport_datagram.dart';

/// A mock backend for testing [WebTransportSession] within the transport.
class _MockBackend implements WebTransportSessionBackend {
  _MockBackend();

  int nextId = 0;
  int closeCallCount = 0;

  @override
  Future<WebTransportBidiStream> openBidirectionalStream() async {
    final id = nextId;
    nextId += 4;
    return WebTransportBidiStream(
      id: id,
      writeFn: (_) async {},
      readFn: ([_]) async => null,
      closeFn: () async {},
      resetFn: () async {},
    );
  }

  @override
  Future<WebTransportUniStream> openUnidirectionalStream() async {
    final id = nextId + 2;
    nextId += 4;
    return WebTransportUniStream(
      id: id,
      writeFn: (_) async {},
      closeFn: () async {},
      resetFn: () async {},
    );
  }

  @override
  Future<void> sendDatagram(Uint8List data) async {}

  @override
  Future<void> closeSession({int errorCode = 0, String? reasonPhrase}) async {
    closeCallCount++;
  }

  @override
  Future<void> sendDrain() async {}

  @override
  Stream<WebTransportBidiStream>? get incomingBidiStreams => null;

  @override
  Stream<WebTransportUniStream>? get incomingUniStreams => null;

  @override
  Stream<Uint8List>? get incomingDatagrams => null;
}

void main() {
  group('WebTransportTransport', () {
    test('should initialize with default config', () {
      final transport = WebTransportTransport();

      expect(transport.maxSessions, equals(100));
      expect(transport.activeSessionCount, equals(0));
      expect(transport.isSessionLimitReached, isFalse);
      expect(transport.protocols, equals(['/webtransport']));
      expect(transport.sessionManager, isNotNull);
      expect(transport.defaultSessionConfig, isNotNull);

      transport.dispose();
    });

    test('should initialize with custom max sessions', () {
      final transport = WebTransportTransport(maxSessions: 50);

      expect(transport.maxSessions, equals(50));
      expect(transport.defaultSessionConfig.maxSessions, equals(50));

      transport.dispose();
    });

    test('should initialize with custom max datagram size', () {
      final transport = WebTransportTransport(maxDatagramSize: 2048);

      expect(transport.defaultSessionConfig.maxDatagramSize, equals(2048));

      transport.dispose();
    });

    test('canDial should return true for webtransport multiaddr', () {
      final transport = WebTransportTransport();
      final addr = libp2p.MultiAddr(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
      );

      expect(transport.canDial(addr), isTrue);

      transport.dispose();
    });

    test('canDial should return false for non-webtransport multiaddr', () {
      final transport = WebTransportTransport();
      final addr = libp2p.MultiAddr('/ip4/127.0.0.1/tcp/4001');

      expect(transport.canDial(addr), isFalse);

      transport.dispose();
    });

    test('canListen should match canDial', () {
      final transport = WebTransportTransport();
      final wtAddr = libp2p.MultiAddr(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport',
      );
      final tcpAddr = libp2p.MultiAddr('/ip4/127.0.0.1/tcp/4001');

      expect(transport.canListen(wtAddr), isTrue);
      expect(transport.canListen(tcpAddr), isFalse);

      transport.dispose();
    });

    test('should register and retrieve sessions', () {
      final transport = WebTransportTransport();
      final backend = _MockBackend();
      final session = WebTransportSession(sessionId: 42, backend: backend);

      transport.registerSession(session);

      expect(transport.activeSessionCount, equals(1));
      expect(transport.getSession(42), same(session));

      transport.removeSession(42);
      expect(transport.activeSessionCount, equals(0));
      expect(transport.getSession(42), isNull);

      transport.dispose();
    });

    test('should enforce max sessions limit', () {
      final transport = WebTransportTransport(maxSessions: 2);
      final backend = _MockBackend();

      transport.registerSession(
        WebTransportSession(sessionId: 0, backend: backend),
      );
      transport.registerSession(
        WebTransportSession(sessionId: 1, backend: backend),
      );

      expect(transport.isSessionLimitReached, isTrue);

      expect(
        () => transport.registerSession(
          WebTransportSession(sessionId: 2, backend: backend),
        ),
        throwsStateError,
      );

      transport.dispose();
    });

    test('should throw on duplicate session registration', () {
      final transport = WebTransportTransport();
      final backend = _MockBackend();
      final session = WebTransportSession(sessionId: 0, backend: backend);

      transport.registerSession(session);

      expect(() => transport.registerSession(session), throwsStateError);

      transport.dispose();
    });

    test('should close all sessions on dispose', () async {
      final transport = WebTransportTransport();
      final backend = _MockBackend();

      transport.registerSession(
        WebTransportSession(sessionId: 0, backend: backend),
      );
      transport.registerSession(
        WebTransportSession(sessionId: 1, backend: backend),
      );

      expect(transport.activeSessionCount, equals(2));

      await transport.dispose();

      expect(transport.activeSessionCount, equals(0));
      expect(backend.closeCallCount, equals(2));
    });

    test('should build server settings', () {
      final transport = WebTransportTransport(maxSessions: 30);

      final settings = transport.buildServerSettings();

      expect(settings[WebTransportSettings.enableConnectProtocol], equals(1));
      expect(settings[WebTransportSettings.h3Datagram], equals(1));
      expect(settings[WebTransportSettings.wtEnabled], equals(1));
      expect(settings[WebTransportSettings.wtMaxSessions], equals(30));
      expect(settings[WebTransportSettings.wtInitialMaxData], isNotNull);
      expect(settings[WebTransportSettings.wtInitialMaxStreamsBidi], isNotNull);
      expect(settings[WebTransportSettings.wtInitialMaxStreamsUni], isNotNull);

      transport.dispose();
    });

    test('should build client settings', () {
      final transport = WebTransportTransport();

      final settings = transport.buildClientSettings();

      expect(settings[WebTransportSettings.enableConnectProtocol], equals(1));
      expect(settings[WebTransportSettings.h3Datagram], equals(1));
      expect(settings[WebTransportSettings.wtEnabled], equals(1));

      transport.dispose();
    });

    test('should validate peer settings with WebTransport support', () {
      final transport = WebTransportTransport();
      final settings = WebTransportSettings.buildServerSettings();

      final parsed = transport.validatePeerSettings(settings);

      expect(parsed.isWebTransportSupported, isTrue);
      expect(parsed.connectProtocolEnabled, isTrue);
      expect(parsed.wtEnabled, isTrue);

      transport.dispose();
    });

    test('should reject peer settings without WebTransport support', () {
      final transport = WebTransportTransport();

      expect(() => transport.validatePeerSettings({}), throwsStateError);

      transport.dispose();
    });

    test('should reject peer settings without Extended CONNECT', () {
      final transport = WebTransportTransport();
      final settings = {WebTransportSettings.wtEnabled: 1};

      expect(() => transport.validatePeerSettings(settings), throwsStateError);

      transport.dispose();
    });

    test('should reject peer settings without WT enabled', () {
      final transport = WebTransportTransport();
      final settings = {WebTransportSettings.enableConnectProtocol: 1};

      expect(() => transport.validatePeerSettings(settings), throwsStateError);

      transport.dispose();
    });

    test('config should return a TransportConfig', () {
      final transport = WebTransportTransport();

      expect(transport.config, isNotNull);

      transport.dispose();
    });
  });

  group('WebTransportTransport integration', () {
    test('should support full session lifecycle through transport', () async {
      final transport = WebTransportTransport(maxSessions: 5);
      final backend = _MockBackend();

      // Create and register a session
      final session = WebTransportSession(sessionId: 100, backend: backend);
      transport.registerSession(session);

      expect(transport.activeSessionCount, equals(1));
      expect(transport.getSession(100), same(session));

      // Open a stream within the session
      final stream = await session.openBidirectionalStream();
      expect(stream.isClosed, isFalse);

      // Send a datagram
      await session.sendDatagram(Uint8List.fromList([1, 2, 3]));

      // Close the session
      await session.close();
      expect(session.isClosed, isTrue);

      // Remove from transport
      transport.removeSession(100);
      expect(transport.activeSessionCount, equals(0));

      await transport.dispose();
    });

    test('should enforce max sessions across multiple registrations', () async {
      final transport = WebTransportTransport(maxSessions: 3);
      final backend = _MockBackend();

      // Register 3 sessions (the max)
      for (var i = 0; i < 3; i++) {
        transport.registerSession(
          WebTransportSession(sessionId: i, backend: backend),
        );
      }

      expect(transport.isSessionLimitReached, isTrue);

      // Close one session and remove it
      final session = transport.getSession(0)!;
      await session.close();
      transport.removeSession(0);

      expect(transport.isSessionLimitReached, isFalse);

      // Now we can register a new one
      transport.registerSession(
        WebTransportSession(sessionId: 10, backend: backend),
      );
      expect(transport.activeSessionCount, equals(3));

      await transport.dispose();
    });
  });
}
