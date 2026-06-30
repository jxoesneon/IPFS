import 'dart:async';
import 'dart:typed_data';

import 'package:ipfs_libp2p/core/multiaddr.dart';
import 'package:ipfs_libp2p/core/network/common.dart';
import 'package:ipfs_libp2p/core/network/context.dart';
import 'package:quic_lib/quic_lib.dart' as quic_lib;
import 'package:test/test.dart';

import 'package:dart_ipfs_quic/src/quic_p2p_stream.dart';
import 'package:dart_ipfs_quic/src/quic_transport.dart';

quic_lib.QuicConnection _createQuicConnection() {
  return quic_lib.QuicConnection(
    stateMachine: quic_lib.ConnectionStateMachine(),
    cidManager: quic_lib.ConnectionIdManager(),
    pnSpaceManager: quic_lib.PacketNumberSpaceManager(),
    rttEstimator: quic_lib.RttEstimator(),
    lossDetector: quic_lib.LossDetector(),
    ptoScheduler: quic_lib.PtoScheduler(quic_lib.RttEstimator()),
    congestionController: quic_lib.CongestionController(),
    streamIdAllocator: quic_lib.StreamIdAllocator(),
  );
}

QuicConnection _createConnection(quic_lib.Libp2pQuicConnection libp2pConn) {
  return QuicConnection(
    libp2pConn,
    localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
    remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
    isServer: false,
  );
}

void main() {
  group('QuicP2PStream', () {
    test('exposes metadata and stat', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      expect(stream.id(), isNotEmpty);
      expect(stream.protocol(), '');
      await stream.setProtocol('/test/1.0.0');
      expect(stream.protocol(), '/test/1.0.0');
      expect(stream.stat().direction, Direction.outbound);
      expect(stream.stat().extra, containsPair('quicStreamId', isA<int>()));
      expect(stream.conn, equals(conn));
      expect(stream.isWritable, isTrue);
      expect(stream.isClosed, isFalse);
    });

    test('write sends data through the send stream', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      final streamId = stream.stat().extra['quicStreamId'] as int;
      final sendStream = quicConn.streamManager.getStream(streamId)!;
      final written = <Uint8List>[];
      (sendStream as quic_lib.QuicSendStream).outgoingData.listen(written.add);

      final data = Uint8List.fromList([1, 2, 3]);
      await stream.write(data);
      expect(written, hasLength(1));
      expect(written.first, equals(data));
    });

    test('close marks the stream as closed', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      await stream.close();
      expect(stream.isClosed, isTrue);
      expect(stream.isWritable, isFalse);
      await expectLater(
        () => stream.write(Uint8List.fromList([1])),
        throwsStateError,
      );
    });

    test('close is idempotent', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      await stream.close();
      await stream.close();
      expect(stream.isClosed, isTrue);
    });

    test('read throws when stream is closed', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      await stream.close();
      await expectLater(
        () => stream.read(),
        throwsStateError,
      );
    });

    test('reset closes the stream', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      await stream.reset();
      expect(stream.isClosed, isTrue);
    });

    test('deadline methods are no-ops', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      await stream.setDeadline(DateTime.now());
      await stream.setReadDeadline(DateTime.now());
      await stream.setWriteDeadline(DateTime.now());
    });

    test('incoming stream controller is a broadcast stream', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(quicConn));
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context()) as QuicP2PStream;
      expect(stream.stream, isA<Stream<Uint8List>>());
    });

    test('read returns buffered data from receive stream', () async {
      final receiveStream = quic_lib.QuicReceiveStream(
        0,
        stateMachine: quic_lib.ReceiveStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: receiveStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.inbound, '');
      receiveStream.deliver(Uint8List.fromList([1, 2, 3]));
      final data = await stream.read();
      expect(data, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('read waits for data on receive stream', () async {
      final receiveStream = quic_lib.QuicReceiveStream(
        0,
        stateMachine: quic_lib.ReceiveStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: receiveStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.inbound, '');
      final readFuture = stream.read();
      receiveStream.deliver(Uint8List.fromList([4, 5, 6]));
      final data = await readFuture;
      expect(data, equals(Uint8List.fromList([4, 5, 6])));
    });

    test('read returns empty when receive stream is done', () async {
      final receiveStream = quic_lib.QuicReceiveStream(
        0,
        stateMachine: quic_lib.ReceiveStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: receiveStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.inbound, '');
      receiveStream.deliver(Uint8List(0), fin: true);
      final data = await stream.read();
      expect(data, equals(Uint8List(0)));
    });

    test('closeRead cancels receive subscription', () async {
      final receiveStream = quic_lib.QuicReceiveStream(
        0,
        stateMachine: quic_lib.ReceiveStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: receiveStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.inbound, '');
      receiveStream.deliver(Uint8List.fromList([1, 2]));
      await stream.read();
      await stream.closeRead();
      expect(stream.isClosed, isFalse);
    });

    test('closeWrite closes the send side', () async {
      final sendStream = quic_lib.QuicSendStream(
        0,
        stateMachine: quic_lib.SendStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: sendStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.outbound, '');
      await stream.closeWrite();
      expect(stream.isWritable, isFalse);
    });

    test('write throws when no send stream is available', () async {
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.outbound, '');
      await expectLater(
        () => stream.write(Uint8List.fromList([1])),
        throwsStateError,
      );
    });

    test('read with maxLength returns partial buffer', () async {
      final receiveStream = quic_lib.QuicReceiveStream(
        0,
        stateMachine: quic_lib.ReceiveStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: receiveStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.inbound, '');
      receiveStream.deliver(Uint8List.fromList([1, 2, 3, 4, 5]));
      await Future.delayed(Duration(milliseconds: 20));
      final data = await stream.read(2);
      expect(data, equals(Uint8List.fromList([1, 2])));
      final rest = await stream.read();
      expect(rest, equals(Uint8List.fromList([3, 4, 5])));
    });

    test('reset calls reset on receive stream', () async {
      final receiveStream = quic_lib.QuicReceiveStream(
        0,
        stateMachine: quic_lib.ReceiveStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: receiveStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.inbound, '');
      receiveStream.deliver(Uint8List.fromList([1]));
      await stream.read();
      await stream.reset();
      expect(stream.isClosed, isTrue);
    });

    test('forwards receive stream errors to incoming controller', () async {
      final receiveStream = _FakeQuicReceiveStream(
        0,
        stateMachine: quic_lib.ReceiveStateMachine(),
      );
      final fakeConn = _FakeQuicConnectionForRead(
        streamManager: _FakeStreamManager({0: receiveStream}),
      );
      final conn = _createConnection(quic_lib.Libp2pQuicConnection(fakeConn));
      addTearDown(() => conn.close());

      final stream = QuicP2PStream(conn, 0, Direction.inbound, '');
      final errors = <Object>[];
      stream.stream.listen(
        (_) {},
        onError: (Object e) => errors.add(e),
      );
      receiveStream.addError(Exception('boom'));
      await Future.delayed(Duration.zero);
      expect(errors, hasLength(1));
    });
  });
}

class _FakeQuicReceiveStream extends quic_lib.QuicReceiveStream {
  final StreamController<Uint8List> _dataController;

  _FakeQuicReceiveStream(
    super.streamId, {
    required super.stateMachine,
  }) : _dataController = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get incomingData => _dataController.stream;

  @override
  Future<void> get done => _dataController.done;

  void addError(Object error) => _dataController.addError(error);
}

class _FakeStreamManager {
  final Map<int, quic_lib.QuicStream> _streams;

  _FakeStreamManager(this._streams);

  quic_lib.QuicStream? getStream(int streamId) => _streams[streamId];
}

class _FakeQuicConnectionForRead {
  final _FakeStreamManager streamManager;
  bool isEstablished = true;

  _FakeQuicConnectionForRead({required this.streamManager});

  int openBidirectionalStream() => 0;
  void close() {}
}
