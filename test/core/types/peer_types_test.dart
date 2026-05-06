import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/types/peer_types.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/proto/generated/core/peer.pb.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:fixnum/fixnum.dart';

void main() {
  group('IPFSPeer', () {
    final peerId = PeerId(value: Uint8List.fromList([1, 2, 3]));
    final peer = IPFSPeer(
      id: peerId,
      addresses: [],
      latency: 10,
      agentVersion: '1.0',
    );

    test('toProto and fromProto', () {
      final pb = peer.toProto();
      expect(pb.latency, equals(Int64(10)));

      final fromPb = IPFSPeer.fromProto(pb);
      expect(fromPb.latency, equals(10));
      expect(fromPb.id.value, equals(peerId.value));
    });

    test('toKadPeer and fromKadPeer', () {
      final kadPeer = peer.toKadPeer();
      expect(kadPeer.id, equals(peerId.value));

      final fromKad = IPFSPeer.fromKadPeer(kadPeer);
      expect(fromKad.id.value, equals(peerId.value));
    });
  });
}
