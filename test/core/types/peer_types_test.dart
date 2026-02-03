import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/core/types/peer_types.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:test/test.dart';

void main() {
  group('IPFSPeer', () {
    test('fromKadPeer parses binary addresses (TODO case)', () {
      final peerIdBytes = Uint8List.fromList(List.filled(64, 1));

      // Construct a valid multiaddr binary: /ip4/127.0.0.1/tcp/4001
      // ip4 code (4) + 4 bytes IP + tcp code (6) + 2 bytes port
      final ipBytes = InternetAddress('127.0.0.1').rawAddress;
      final port = 4001;
      final multiaddrBytes = BytesBuilder();
      multiaddrBytes.addByte(4); // ip4
      multiaddrBytes.add(ipBytes);
      multiaddrBytes.addByte(6); // tcp
      multiaddrBytes.addByte((port >> 8) & 0xFF);
      multiaddrBytes.addByte(port & 0xFF);

      final kadPeer = kad.Peer()
        ..id = peerIdBytes
        ..addrs.add(multiaddrBytes.toBytes());

      final peer = IPFSPeer.fromKadPeer(kadPeer);

      expect(peer.addresses, isNotEmpty);
      expect(peer.addresses.first.address.address, equals('127.0.0.1'));
      expect(peer.addresses.first.port, equals(4001));
    });

    test('toKadPeer converts addresses to binary (TODO case)', () {
      final peerId = PeerId(value: Uint8List.fromList(List.filled(64, 1)));
      final address = FullAddress(
        address: InternetAddress('127.0.0.1'),
        port: 4001,
      );

      final peer = IPFSPeer(
        id: peerId,
        addresses: [address],
        latency: 0,
        agentVersion: '',
      );

      final kadPeer = peer.toKadPeer();

      expect(kadPeer.addrs, isNotEmpty);
      final bytes = kadPeer.addrs.first;
      // Expect 0x04 (ip4) ... ...
      expect(bytes[0], equals(4));
    });
  });
}
