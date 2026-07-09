import 'dart:typed_data';

import 'package:dart_ipfs_quic/dart_ipfs_quic.dart';
import 'package:dart_ipfs_quic/src/quic_p2p_stream.dart';
import 'package:ipfs_libp2p/core/multiaddr.dart';
import 'package:ipfs_libp2p/core/network/context.dart';
import 'package:ipfs_libp2p/core/network/rcmgr.dart';
import 'package:ipfs_libp2p/p2p/transport/transport.dart';
import 'package:quic_lib/quic_lib.dart' as quic_lib;
import 'package:test/test.dart';

Future<({quic_lib.SecretKey privateKey, List<int> publicKeyBytes})>
    _generateEd25519KeyPair() async {
  final backend = quic_lib.DefaultCryptoBackend();
  final keyPair = await backend.ed25519GenerateKeyPair();
  final privateKey = await keyPair.secretKey;
  final publicKey = await keyPair.publicKey;
  return (privateKey: privateKey, publicKeyBytes: publicKey.bytes);
}

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

void main() {
  group('QuicTransport', () {
    test('implements libp2p Transport', () {
      final transport = QuicTransport();
      expect(transport, isA<Transport>());
    });

    test('reports QUIC protocols', () {
      final transport = QuicTransport();
      expect(transport.protocols, contains('/ip4/udp/quic-v1'));
      expect(transport.protocols, contains('/ip6/udp/quic-v1'));
    });

    test('canDial recognizes QUIC multiaddrs', () {
      final transport = QuicTransport();
      expect(
        transport.canDial(MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1')),
        isTrue,
      );
      expect(
        transport.canDial(MultiAddr('/ip4/127.0.0.1/tcp/4001')),
        isFalse,
      );
      expect(
        transport
            .canDial(MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1/p2p-circuit')),
        isFalse,
      );
    });

    test('canListen recognizes QUIC multiaddrs', () {
      final transport = QuicTransport();
      expect(
        transport.canListen(MultiAddr('/ip4/0.0.0.0/udp/4002/quic-v1')),
        isTrue,
      );
      expect(
        transport.canListen(MultiAddr('/ip6/::/udp/4002/quic-v1')),
        isTrue,
      );
      expect(
        transport.canListen(MultiAddr('/ip4/0.0.0.0/tcp/4001')),
        isFalse,
      );
    });

    test('dial returns a connection wrapper', () async {
      final transport = QuicTransport();
      final conn = await transport.dial(
        MultiAddr('/ip4/127.0.0.1/udp/12345/quic-v1'),
      );
      expect(conn, isA<QuicConnection>());
      expect(conn.isClosed, isFalse);
      await conn.close();
      addTearDown(() => transport.dispose());
    });

    test('listen returns a listener', () async {
      final transport = QuicTransport();
      final listener = await transport.listen(
        MultiAddr('/ip4/127.0.0.1/udp/0/quic-v1'),
      );
      expect(listener, isNotNull);
      expect(listener.addr.toString(), contains('/quic-v1'));
      await listener.close();
      addTearDown(() => transport.dispose());
    });

    test('dispose marks transport as closed', () async {
      final transport = QuicTransport();
      await transport.dispose();
      expect(
        () => transport.dial(MultiAddr('/ip4/127.0.0.1/udp/12345/quic-v1')),
        throwsStateError,
      );
      expect(
        () => transport.listen(MultiAddr('/ip4/127.0.0.1/udp/0/quic-v1')),
        throwsStateError,
      );
    });
  });

  group('QuicConnection', () {
    test('newStream opens a bidirectional QUIC stream', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);

      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context());
      expect(stream, isA<QuicP2PStream>());
      expect(stream.id(), isNotEmpty);
      expect(stream.isWritable, isTrue);
      expect(stream.isClosed, isFalse);
    });

    test('streams returns incoming receive streams', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);

      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(await conn.streams, isEmpty);
    });

    test('verifyPeerCertificate validates a libp2p TLS certificate', () async {
      final keyPair = await _generateEd25519KeyPair();
      final generator = quic_lib.Libp2pCertificateGenerator(
        quic_lib.DefaultCryptoBackend(),
      );
      final chain = await generator.generate(
        hostIdentityPrivateKey: keyPair.privateKey,
        hostPublicKeyBytes: keyPair.publicKeyBytes,
      );
      final certInfo = chain.certs.first;
      final certBytes = certInfo.rawBytes;

      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);
      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(await conn.verifyPeerCertificate(certBytes), isTrue);
      expect(conn.remotePeer, isNotNull);
    });

    test(
        'verifyPeerFromHandshake returns false when no handshake cert captured',
        () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);
      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(await conn.verifyPeerFromHandshake(), isFalse);
    });

    test('remotePeer throws when peerId is not set', () {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);
      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(() => conn.remotePeer, throwsStateError);
    });

    test('verifyPeer returns true when peerId is set', () async {
      final keyPair = await _generateEd25519KeyPair();
      final generator = quic_lib.Libp2pCertificateGenerator(
        quic_lib.DefaultCryptoBackend(),
      );
      final chain = await generator.generate(
        hostIdentityPrivateKey: keyPair.privateKey,
        hostPublicKeyBytes: keyPair.publicKeyBytes,
      );
      final certBytes = chain.certs.first.rawBytes;

      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      quicConn.negotiatedAlpn = 'libp2p';
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);
      await libp2pConn.verifyPeerCertificate(
        certBytes,
        backend: quic_lib.DefaultCryptoBackend(),
      );
      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(conn.verifyPeer(), isTrue);
    });

    test('close is idempotent', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection(quicConn),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      await conn.close();
      await conn.close();
      expect(conn.isClosed, isTrue);
    });

    test('raw read and write throw UnsupportedError', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection(quicConn),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(() => conn.read(), throwsUnsupportedError);
      expect(() => conn.write(Uint8List(0)), throwsUnsupportedError);
      expect(() => conn.socket, throwsUnsupportedError);
    });

    test('newStream throws when underlying connection is not a QuicConnection',
        () async {
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection('fake'),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());
      await expectLater(
        () => conn.newStream(Context()),
        throwsStateError,
      );
    });

    test(
        'streams returns empty when underlying connection is not a QuicConnection',
        () async {
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection('fake'),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());
      expect(await conn.streams, isEmpty);
    });

    test('exposes connection metadata', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection(quicConn),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(conn.id, isNotEmpty);
      expect(conn.localPeer, isNotNull);
      expect(await conn.remotePublicKey, isNull);
      expect(conn.localMultiaddr.toString(), contains('/quic-v1'));
      expect(conn.remoteMultiaddr.toString(), contains('/quic-v1'));
      expect(conn.state.transport, 'quic-v1');
      expect(conn.state.security, '/tls/1.3');
      expect(conn.stat.numStreams, 0);
      expect(conn.scope, isA<NullScope>());
      conn.setReadTimeout(Duration(seconds: 1));
      conn.setWriteTimeout(Duration(seconds: 1));
      conn.notifyActivity();
    });

    test('streams returns inbound P2PStreams for receive streams', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      // Register a receive stream in the manager.
      quicConn.streamManager.onStreamFrame(
        quic_lib.StreamFrame(
          streamId: 0,
          offset: 0,
          data: Uint8List.fromList([1, 2, 3]),
          fin: false,
        ),
      );
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection(quicConn),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      final streams = await conn.streams;
      expect(streams, hasLength(1));
      expect(streams.first, isA<QuicP2PStream>());
    });

    test('quicConnection exposes underlying delegate', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);
      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(conn.quicConnection, equals(quicConn));
    });

    test('isEstablished delegates to QuicConnectionAdapter', () async {
      final fakeAdapter = _FakeQuicConnectionAdapter(
        streams: {},
        isEstablished: false,
      );
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection(fakeAdapter),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(conn.isEstablished, isFalse);
      fakeAdapter.isEstablished = true;
      expect(conn.isEstablished, isTrue);
    });

    test('openBidirectionalStream delegates to QuicConnectionAdapter',
        () async {
      final fakeAdapter = _FakeQuicConnectionAdapter(
        streams: {},
        nextStreamId: 42,
      );
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection(fakeAdapter),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(conn.openBidirectionalStream(), equals(42));
      expect(fakeAdapter.openBidirectionalStreamCalls, equals(1));
    });

    test('openBidirectionalStream throws when not a QuicConnectionAdapter',
        () async {
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection('not-a-connection'),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      expect(
        () => conn.openBidirectionalStream(),
        throwsStateError,
      );
    });

    test('newStream waits for adapter handshake before opening stream',
        () async {
      final fakeAdapter = _TransitioningQuicConnectionAdapter(streamId: 7);
      final conn = QuicConnection(
        quic_lib.Libp2pQuicConnection(fakeAdapter),
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context());
      expect(stream, isA<QuicP2PStream>());
      expect(stream.stat().extra, containsPair('quicStreamId', 7));
      expect(fakeAdapter.isEstablished, isTrue);
    });
  });

  group('QuicP2PStream', () {
    test('implements P2PStream', () async {
      final quicConn = _createQuicConnection();
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.handshaking);
      quicConn.stateMachine.transitionTo(quic_lib.ConnectionState.established);
      final libp2pConn = quic_lib.Libp2pQuicConnection(quicConn);
      final conn = QuicConnection(
        libp2pConn,
        localAddr: MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1'),
        remoteAddr: MultiAddr('/ip4/127.0.0.1/udp/4003/quic-v1'),
        isServer: false,
      );
      addTearDown(() => conn.close());

      final stream = await conn.newStream(Context());
      expect(stream, isA<QuicP2PStream>());
      expect(stream.protocol(), '');
      await stream.setProtocol('/test/1.0.0');
      expect(stream.protocol(), '/test/1.0.0');
    });
  });
}

class _FakeQuicConnectionAdapter implements QuicConnectionAdapter {
  final Map<int, quic_lib.QuicStream> _streams;
  @override
  bool isEstablished;
  int nextStreamId;
  int openBidirectionalStreamCalls = 0;

  _FakeQuicConnectionAdapter({
    required Map<int, quic_lib.QuicStream> streams,
    this.isEstablished = true,
    this.nextStreamId = 0,
  }) : _streams = streams;

  @override
  quic_lib.QuicStream? getQuicStream(int id) => _streams[id];

  @override
  int openBidirectionalStream() {
    openBidirectionalStreamCalls++;
    return nextStreamId;
  }

  @override
  Future<void> close() async {}
}

class _TransitioningQuicConnectionAdapter implements QuicConnectionAdapter {
  final int streamId;
  bool _isEstablished = false;

  _TransitioningQuicConnectionAdapter({required this.streamId}) {
    // Transition to established after the first isEstablished check.
    Future.delayed(const Duration(milliseconds: 25), () {
      _isEstablished = true;
    });
  }

  @override
  bool get isEstablished => _isEstablished;

  @override
  quic_lib.QuicStream? getQuicStream(int id) => null;

  @override
  int openBidirectionalStream() => streamId;

  @override
  Future<void> close() async {}
}
