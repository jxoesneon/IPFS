import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/errors/transport_errors.dart';
import 'package:dart_ipfs/src/transport/libp2p_router.dart';
import 'package:dart_ipfs/src/transport/webrtc/data_channel_stream.dart';
import 'package:dart_ipfs/src/transport/webrtc/peer_connection.dart';
import 'package:dart_ipfs/src/transport/webrtc/peer_connection_stub.dart'
    show PeerConnectionStub;
import 'package:dart_ipfs/src/transport/webrtc/webrtc_direct_transport.dart';
import 'package:dart_ipfs/src/transport/webtransport/webtransport_dialer.dart';
import 'package:dart_ipfs/src/transport/webtransport/webtransport_transport.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

/// Minimal [DataChannelStream] used to exercise the base-class members.
class _TestDataChannelStream extends DataChannelStream {
  @override
  String get label => 'test-channel';

  @override
  Future<void> write(Uint8List data) async {}
}

void main() {
  final addr = libp2p.MultiAddr('/ip4/127.0.0.1/tcp/4001');

  group('TransportUnavailableException', () {
    test('message names the transport and platform', () {
      final exception = TransportUnavailableException.forPlatform(
        'WebTransport',
        'IO',
      );

      expect(
        exception.message,
        equals('WebTransport is not available on IO platforms'),
      );
      expect(exception, isA<Exception>());
      expect(exception, isNot(isA<UnimplementedError>()));
    });

    test('forPlatform produces the expected message text', () {
      expect(
        TransportUnavailableException.forPlatform('WebRTC', 'VM').message,
        equals('WebRTC is not available on VM platforms'),
      );
      expect(
        TransportUnavailableException.forPlatform(
          'WebTransport',
          'native',
        ).message,
        equals('WebTransport is not available on native platforms'),
      );
    });

    test('toString includes the exception name and message', () {
      final exception = TransportUnavailableException.forPlatform(
        'WebRTC',
        'IO',
      );

      expect(
        exception.toString(),
        equals(
          'TransportUnavailableException: '
          'WebRTC is not available on IO platforms',
        ),
      );
      expect(
        TransportUnavailableException('custom message').toString(),
        equals('TransportUnavailableException: custom message'),
      );
      expect(exception.toString(), contains(exception.message));
    });
  });

  group('IO transport stubs', () {
    test('WebTransport dialer throws TransportUnavailableException', () {
      final dialer = createWebTransportDialer();

      expect(
        () => dialer.dial(addr),
        throwsA(
          isA<TransportUnavailableException>().having(
            (e) => e.message,
            'message',
            contains('WebTransport'),
          ),
        ),
      );
    });

    test('WebTransportTransport.dial throws TransportUnavailableException', () {
      final transport = WebTransportTransport();

      expect(
        () => transport.dial(addr),
        throwsA(isA<TransportUnavailableException>()),
      );
    });

    test('PeerConnection methods throw TransportUnavailableException', () {
      final pc = createPeerConnection(const []);

      expect(
        () => pc.createOffer(),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.createAnswer(),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.setLocalDescription(RTCSessionDescriptionInit('offer', 'sdp')),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.setRemoteDescription('answer', 'sdp'),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.addIceCandidate(RTCIceCandidateInit('candidate', null, null)),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.createDataChannel('data'),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(() => pc.close(), throwsA(isA<TransportUnavailableException>()));
      expect(
        () => pc.localDescriptionSdp,
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.remoteDescriptionSdp,
        throwsA(isA<TransportUnavailableException>()),
      );
    });

    test('PeerConnectionStub throws TransportUnavailableException', () {
      final pc = PeerConnectionStub(const []);

      expect(
        () => pc.createOffer(),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.createAnswer(),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.setLocalDescription(RTCSessionDescriptionInit('offer', 'sdp')),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.setRemoteDescription('answer', 'sdp'),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.addIceCandidate(RTCIceCandidateInit('candidate', null, null)),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.createDataChannel('data'),
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(() => pc.close(), throwsA(isA<TransportUnavailableException>()));
      expect(
        () => pc.onIceCandidate,
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.onDataChannel,
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.localDescriptionSdp,
        throwsA(isA<TransportUnavailableException>()),
      );
      expect(
        () => pc.remoteDescriptionSdp,
        throwsA(isA<TransportUnavailableException>()),
      );
    });

    test('PeerConnectionStub state getters return null', () {
      final pc = PeerConnectionStub(const []);

      expect(pc.iceConnectionState, isNull);
      expect(pc.signalingState, isNull);
    });

    test(
      'WebRTCDirectTransport.listen throws TransportUnavailableException',
      () {
        final transport = WebRTCDirectTransport();

        expect(
          () => transport.listen(addr),
          throwsA(isA<TransportUnavailableException>()),
        );
      },
    );

    test('DataChannelStream.conn throws TransportUnavailableException', () {
      final stream = _TestDataChannelStream();

      expect(() => stream.conn, throwsA(isA<TransportUnavailableException>()));
    });
  });

  group('Libp2pRouter browser-transport gating', () {
    late Libp2pRouter router;

    IPFSConfig makeConfig() => IPFSConfig(
      dataPath: Directory.systemTemp.createTempSync('ipfs_browser_gate_').path,
      network: NetworkConfig(
        listenAddresses: ['/ip4/127.0.0.1/tcp/0'],
        bootstrapPeers: const [],
      ),
    );

    tearDown(() async {
      Libp2pRouter.setBrowserTransportsSupportedForTesting(null);
      if (router.hasStarted) await router.stop();
    });

    test('reports browser transports as unsupported on IO platforms', () {
      router = Libp2pRouter(makeConfig());

      expect(router.supportsBrowserTransports, isFalse);
    });

    test('starts with default-on transports skipped on IO platforms', () async {
      // enableWebTransport and enableWebRtc default to true; on IO the
      // router must skip the stub transports rather than failing.
      router = Libp2pRouter(makeConfig());
      await router.start();

      expect(router.hasStarted, isTrue);
      expect(router.peerID, isNotEmpty);
    });

    test('logs a skip message for each unavailable transport', () async {
      final messages = <String>[];
      final subscription = logging.Logger.root.onRecord.listen((record) {
        if (record.loggerName == 'Libp2pRouter') {
          messages.add(record.message);
        }
      });
      addTearDown(subscription.cancel);

      router = Libp2pRouter(makeConfig());
      await router.start();

      expect(
        messages.any(
          (m) => m.contains('WebTransport') && m.contains('skipping'),
        ),
        isTrue,
      );
      expect(
        messages.any((m) => m.contains('WebRTC') && m.contains('skipping')),
        isTrue,
      );
    });

    test(
      'registers browser transports when the platform supports them',
      () async {
        Libp2pRouter.setBrowserTransportsSupportedForTesting(true);
        router = Libp2pRouter(makeConfig());

        expect(router.supportsBrowserTransports, isTrue);

        await router.start();
        expect(router.hasStarted, isTrue);
      },
    );
  });
}
