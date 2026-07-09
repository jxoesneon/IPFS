// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as $0;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart';

void main() {
  group('Message', () {
    test('round-trips and accessors work', () {
      final original = Message(type: Message_MessageType.values.first, key: const [0, 1, 2], record: $0.Record.create(), closerPeers: [Peer.create()], providerPeers: [Peer.create()], clusterLevelRaw: 1);
      expect(original.type, isNotNull);
      expect(original.key, const [0, 1, 2]);
      expect(original.record, isNotNull);
      expect(original.closerPeers.length, 1);
      expect(original.providerPeers.length, 1);
      expect(original.clusterLevelRaw, 1);
      original.hasType();
      original.clearType();
      original.hasKey();
      original.clearKey();
      original.hasRecord();
      original.clearRecord();
      original.closerPeers.clear();
      original.providerPeers.clear();
      original.hasClusterLevelRaw();
      original.clearClusterLevelRaw();
      expect(Message.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Message.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Message.fromJson(json), isNotNull);
    });
  });

  group('Peer', () {
    test('round-trips and accessors work', () {
      final original = Peer(id: const [0, 1, 2], addrs: [[0, 1]], connection: ConnectionType.values.first);
      expect(original.id, const [0, 1, 2]);
      expect(original.addrs, [[0, 1]]);
      expect(original.connection, isNotNull);
      original.hasId();
      original.clearId();
      original.addrs.clear();
      original.hasConnection();
      original.clearConnection();
      expect(Peer.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Peer.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Peer.fromJson(json), isNotNull);
    });
  });

}
