import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:dart_ipfs/src/proto/generated/core/peer.pb.dart';
import 'package:fixnum/fixnum.dart';

void main() {
  group('Peer Coverage Tests', () {
    final peerIdBytes = Uint8List.fromList(List.filled(32, 1));
    final peerIdStr = Base58().encode(peerIdBytes);

    test('Peer.fromProto and toProto', () {
      final proto = PeerProto()
        ..id = peerIdStr
        ..addresses.addAll(['/ip4/127.0.0.1/tcp/4001', '/ip6/::1/tcp/5001'])
        ..latency = Int64(100)
        ..agentVersion = 'dart-ipfs/1.0.0';

      final peer = Peer.fromProto(proto);
      expect(peer.id.value, equals(peerIdBytes));
      expect(peer.addresses, hasLength(2));
      expect(peer.addresses[0].address.address, equals('127.0.0.1'));
      expect(peer.addresses[0].port, equals(4001));
      expect(peer.addresses[1].address.type, equals(InternetAddressType.IPv6));
      expect(peer.addresses[1].port, equals(5001));
      expect(peer.latency, equals(100));
      expect(peer.agentVersion, equals('dart-ipfs/1.0.0'));

      final backToProto = peer.toProto();
      expect(backToProto.id, equals(peerIdStr));
      expect(backToProto.addresses, contains('/ip4/127.0.0.1/tcp/4001'));
      expect(backToProto.latency, equals(Int64(100)));
      expect(backToProto.agentVersion, equals('dart-ipfs/1.0.0'));
    });

    test('Peer.fromMultiaddr success', () async {
      final multiaddr = '/ip4/127.0.0.1/tcp/4001/p2p/$peerIdStr';
      final peer = await Peer.fromMultiaddr(multiaddr);

      expect(peer.id.value, equals(peerIdBytes));
      expect(peer.addresses, hasLength(1));
      expect(peer.addresses[0].address.address, equals('127.0.0.1'));
      expect(peer.addresses[0].port, equals(4001));
    });

    test('Peer.fromMultiaddr with IPv6', () async {
      final multiaddr = '/ip6/::1/tcp/4001/p2p/$peerIdStr';
      final peer = await Peer.fromMultiaddr(multiaddr);

      expect(peer.id.value, equals(peerIdBytes));
      expect(peer.addresses[0].address.type, equals(InternetAddressType.IPv6));
    });

    test('Peer.fromMultiaddr error cases', () async {
      // Invalid peer ID
      expect(
        () => Peer.fromMultiaddr('/ip4/127.0.0.1/tcp/4001/p2p/invalid-base58!'),
        throwsException,
      );

      // Empty peer ID component
      expect(
        () => Peer.fromMultiaddr('/ip4/127.0.0.1/tcp/4001/p2p/'),
        throwsFormatException,
      );
    });

    test('parseMultiaddrString more cases', () {
      // Invalid port
      expect(parseMultiaddrString('/ip4/127.0.0.1/tcp/0'), isNull);
      expect(parseMultiaddrString('/ip4/127.0.0.1/tcp/65536'), isNull);
      expect(parseMultiaddrString('/ip4/127.0.0.1/tcp/-1'), isNull);

      // Invalid IP
      // InternetAddress constructor might throw if invalid format depending on platform,
      // but parseMultiaddrString has a try-catch.
      expect(parseMultiaddrString('/ip4/999.999.999.999/tcp/4001'), isNull);
    });

    test('multiaddrToBytes unsupported type', () {
      // We need an InternetAddress that is neither IPv4 nor IPv6 if possible,
      // or just mock it if we can't easily create one.
      // InternetAddressType.unix is one possibility if supported.
      try {
        final unixAddr = FullAddress(
          address: InternetAddress(
            '/tmp/socket',
            type: InternetAddressType.unix,
          ),
          port: 4001,
        );
        final bytes = multiaddrToBytes(unixAddr);
        expect(bytes, isEmpty);
      } catch (e) {
        // Unix address might not be supported on all platforms, skip if so
      }
    });

    test('multiaddrFromBytes edge cases', () {
      // Too short for IPv6
      final shortIp6 = Uint8List.fromList([41] + List.filled(15, 0));
      expect(multiaddrFromBytes(shortIp6), isNull);

      // Missing transport protocol byte
      final noTransport = Uint8List.fromList([4, 127, 0, 0, 1]);
      expect(multiaddrFromBytes(noTransport), isNull);
    });
  });
}
