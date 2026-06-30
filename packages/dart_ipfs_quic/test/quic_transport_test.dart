import 'package:dart_ipfs_quic/dart_ipfs_quic.dart';
import 'package:ipfs_libp2p/core/multiaddr.dart';
import 'package:ipfs_libp2p/core/network/context.dart';
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
