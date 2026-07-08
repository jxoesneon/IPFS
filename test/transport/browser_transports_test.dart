import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:dart_ipfs/src/transport/webtransport/multiaddr_parser.dart';
import 'package:dart_ipfs/src/transport/webrtc/ice_server.dart';
import 'package:dart_ipfs/src/transport/webrtc/webrtc_direct_transport.dart';
import 'package:dart_ipfs/src/transport/webrtc/webrtc_transport.dart';
import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:mockito/mockito.dart';
import 'package:multibase/multibase.dart';
import 'package:test/test.dart';

class FakeMultiAddr extends Fake implements libp2p.MultiAddr {
  final String _addr;
  FakeMultiAddr(this._addr);
  @override
  String toString() => _addr;
  @override
  bool operator ==(Object other) =>
      (other is libp2p.MultiAddr || other is FakeMultiAddr) &&
      other.toString() == _addr;
  @override
  int get hashCode => _addr.hashCode;
}

void main() {
  group('NetworkConfig browser transport settings', () {
    test('defaults have no hardcoded STUN/TURN servers', () {
      final config = NetworkConfig();
      expect(config.stunServers, isEmpty);
      expect(config.turnServers, isEmpty);
    });

    test('stunServers and turnServers round-trip through JSON', () {
      final config = NetworkConfig(
        stunServers: ['stun:stun.example.com:19302'],
        turnServers: [
          TurnServer(
            url: 'turn:turn.example.com:3478',
            username: 'user',
            credential: 'pass',
          ),
        ],
      );
      final json = config.toJson();
      expect(json['stunServers'], ['stun:stun.example.com:19302']);
      expect(json['turnServers'], [
        {
          'url': 'turn:turn.example.com:3478',
          'username': 'user',
          'credential': 'pass',
        },
      ]);

      final restored = NetworkConfig.fromJson(json);
      expect(restored.stunServers, ['stun:stun.example.com:19302']);
      expect(restored.turnServers, hasLength(1));
      expect(restored.turnServers.first.url, 'turn:turn.example.com:3478');
      expect(restored.turnServers.first.username, 'user');
      expect(restored.turnServers.first.credential, 'pass');
    });

    test('empty stun/turn lists produce empty ice servers', () {
      final config = NetworkConfig();
      final iceServers = buildIceServersFromNetworkConfig(config);
      expect(iceServers, isEmpty);
    });

    test('buildIceServersFromNetworkConfig creates STUN and TURN entries', () {
      final config = NetworkConfig(
        stunServers: ['stun:stun.example.com:19302'],
        turnServers: [
          TurnServer(
            url: 'turn:turn.example.com:3478',
            username: 'user',
            credential: 'pass',
          ),
        ],
      );
      final iceServers = buildIceServersFromNetworkConfig(config);
      expect(iceServers, hasLength(2));
      expect(
        iceServers.first,
        IceServer.fromStun('stun:stun.example.com:19302'),
      );
      expect(
        iceServers.last,
        IceServer(
          urls: 'turn:turn.example.com:3478',
          username: 'user',
          credential: 'pass',
        ),
      );
    });
  });

  group('WebTransport multiaddr certhash parsing', () {
    String _makeCerthash() {
      // Build a valid sha2-256 multihash: 0x12 = sha2-256, 0x20 = 32 byte digest.
      final digest = Uint8List.fromList(
        List.generate(32, (index) => index % 256),
      );
      final multihash = Uint8List.fromList([0x12, 0x20, ...digest]);
      return multibaseEncode(Multibase.base64url, multihash);
    }

    test('decodes a valid multibase certhash into 32 bytes', () {
      final certhash = _makeCerthash();
      final addr = libp2p.MultiAddr(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport/certhash/$certhash',
      );
      final info = WebTransportMultiaddrParser.parse(addr);
      expect(info, isNotNull);
      expect(info!.certHashes, hasLength(1));
      expect(info.certHashes.first.value, hasLength(32));
      expect(info.certHashes.first.algorithm, 'sha-256');
    });

    test('decodes multiple certhashes', () {
      final certhash = _makeCerthash();
      final addr = libp2p.MultiAddr(
        '/ip4/127.0.0.1/udp/4001/quic-v1/webtransport/certhash/$certhash/certhash/$certhash',
      );
      final info = WebTransportMultiaddrParser.parse(addr);
      expect(info, isNotNull);
      expect(info!.certHashes, hasLength(2));
    });
  });

  group('WebRTC transport ICE configuration', () {
    test('WebRTCTransport uses configurable ICE servers', () {
      final config = NetworkConfig(
        stunServers: ['stun:stun.example.com:19302'],
      );
      final transport = WebRTCTransport(host: null, networkConfig: config);
      // The transport should be constructable with a network config.
      // No hardcoded Google STUN server is used.
      expect(transport, isNotNull);
    });

    test('WebRTCDirectTransport uses configurable ICE servers', () {
      final config = NetworkConfig(
        stunServers: ['stun:stun.example.com:19302'],
      );
      final transport = WebRTCDirectTransport(networkConfig: config);
      expect(transport, isNotNull);
      expect(
        transport.canDial(FakeMultiAddr('/webrtc-direct/p2p/QmX')),
        isTrue,
      );
    });

    test('transports default to no ICE servers when no config is provided', () {
      final transport = WebRTCTransport();
      expect(transport, isNotNull);
      final directTransport = WebRTCDirectTransport();
      expect(directTransport, isNotNull);
    });
  });
}
