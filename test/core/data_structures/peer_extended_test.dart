import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/utils/base58.dart';

void main() {
  group('Peer Extended Tests', () {
    final peerIdBytes = Uint8List.fromList(List.filled(32, 1));
    final peerIdStr = Base58().encode(peerIdBytes);

    test('FullAddress toString', () {
      final addr = FullAddress(
        address: InternetAddress('127.0.0.1'),
        port: 4001,
      );
      expect(addr.toString(), equals('/ip4/127.0.0.1/tcp/4001'));
    });

    test('Peer.fromId', () {
      final peer = Peer.fromId(peerIdStr);
      expect(peer.id.value, equals(peerIdBytes));
      expect(peer.addresses, isEmpty);
      expect(peer.latency, equals(0));
      expect(peer.agentVersion, isEmpty);
    });

    test('Peer.toString', () {
      final peer = Peer(
        id: PeerId(value: peerIdBytes),
        addresses: [
          FullAddress(address: InternetAddress('127.0.0.1'), port: 4001),
        ],
        latency: 50,
        agentVersion: 'ipfs/1.0.0',
      );
      final str = peer.toString();
      expect(str, contains('Peer{id:'));
      expect(str, contains('127.0.0.1'));
      expect(str, contains('latency: 50'));
      expect(str, contains('agentVersion: ipfs/1.0.0'));
    });

    test('Peer.fromMultiaddr edge cases', () async {
      // Missing p2p
      expect(
        () => Peer.fromMultiaddr('/ip4/127.0.0.1/tcp/4001'),
        throwsFormatException,
      );

      // Invalid address
      expect(
        () => Peer.fromMultiaddr('/ip4/invalid/tcp/4001/p2p/$peerIdStr'),
        throwsFormatException,
      );

      // Empty string
      expect(() => Peer.fromMultiaddr(''), throwsFormatException);
    });

    test('parseMultiaddrString IPv6', () {
      final addr = parseMultiaddrString('/ip6/::1/tcp/4001');
      expect(addr, isNotNull);
      expect(addr!.address.type, equals(InternetAddressType.IPv6));
      expect(addr.port, equals(4001));
    });

    test('parseMultiaddrString invalid formats', () {
      expect(parseMultiaddrString('/ip4/127.0.0.1'), isNull); // Too short
      expect(
        parseMultiaddrString('/ip4/127.0.0.1/sctp/4001'),
        isNull,
      ); // Protocol not supported

      final udpAddr = parseMultiaddrString('/ip4/127.0.0.1/udp/4001');
      expect(udpAddr, isNotNull);
      expect(udpAddr!.port, equals(4001));

      expect(parseMultiaddrString('/ip4/127.0.0.1/tcp/not-a-number'), isNull);
    });

    test('multiaddrToBytes and multiaddrFromBytes IPv4', () {
      final addr = FullAddress(
        address: InternetAddress('127.0.0.1'),
        port: 4001,
      );
      final bytes = multiaddrToBytes(addr);
      expect(bytes, isNotEmpty);
      expect(bytes[0], equals(4)); // ip4

      final decoded = multiaddrFromBytes(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.address.address, equals('127.0.0.1'));
      expect(decoded.port, equals(4001));
    });

    test('multiaddrToBytes and multiaddrFromBytes IPv6', () {
      final addr = FullAddress(address: InternetAddress('::1'), port: 4001);
      final bytes = multiaddrToBytes(addr);
      expect(bytes, isNotEmpty);
      expect(bytes[0], equals(41)); // ip6

      final decoded = multiaddrFromBytes(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.address.type, equals(InternetAddressType.IPv6));
      expect(decoded.port, equals(4001));
    });

    test('multiaddrFromBytes invalid', () {
      expect(
        multiaddrFromBytes(Uint8List.fromList([99, 1, 2, 3, 4])),
        isNull,
      ); // Invalid protocol
      expect(
        multiaddrFromBytes(Uint8List.fromList([4, 1, 2, 3])),
        isNull,
      ); // Too short for ip4
      expect(
        multiaddrFromBytes(Uint8List.fromList([4, 1, 2, 3, 4, 99])),
        isNull,
      ); // Invalid transport protocol
      expect(
        multiaddrFromBytes(Uint8List.fromList([4, 1, 2, 3, 4, 6, 1])),
        isNull,
      ); // Too short for port
    });

    test('multiaddrFromBytes UDP', () {
      // Construct UDP bytes manually
      final builder = BytesBuilder();
      builder.addByte(4); // ip4
      builder.add([127, 0, 0, 1]);
      builder.addByte(17); // udp
      builder.addByte(15); // port 4001 high
      builder.addByte(161); // port 4001 low (4001 = 0x0FA1)

      final decoded = multiaddrFromBytes(builder.toBytes());
      expect(decoded, isNotNull);
      expect(decoded!.port, equals(4001));
    });
  });
}
