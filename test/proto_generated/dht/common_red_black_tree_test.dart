// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $0;
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';

void main() {
  group('RBTreePeerId', () {
    test('round-trips and accessors work', () {
      final original = RBTreePeerId(id: 'a');
      expect(original.id, 'a');
      original.hasId();
      original.clearId();
      expect(RBTreePeerId.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = RBTreePeerId.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(RBTreePeerId.fromJson(json), isNotNull);
    });
  });

  group('Node', () {
    test('round-trips and accessors work', () {
      final original = Node(
        peerId: RBTreePeerId.create(),
        data: const [0, 1, 2],
      );
      expect(original.peerId, isNotNull);
      expect(original.data, const [0, 1, 2]);
      original.hasPeerId();
      original.clearPeerId();
      original.hasData();
      original.clearData();
      original.ensurePeerId();
      expect(Node.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Node.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Node.fromJson(json), isNotNull);
    });
  });

  group('K_PeerId', () {
    test('round-trips and accessors work', () {
      final original = K_PeerId(id: const [0, 1, 2]);
      expect(original.id, const [0, 1, 2]);
      original.hasId();
      original.clearId();
      expect(K_PeerId.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = K_PeerId.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(K_PeerId.fromJson(json), isNotNull);
    });
  });

  group('V_PeerInfo', () {
    test('round-trips and accessors work', () {
      final original = V_PeerInfo(
        peerId: const [0, 1, 2],
        ipAddress: 'a',
        port: 1,
        protocols: ['a'],
        latency: 1,
        connectionStatus: V_PeerInfo_ConnectionStatus.values.first,
        lastSeen: $0.Timestamp.create(),
        agentVersion: 'a',
        publicKey: const [0, 1, 2],
        addresses: ['a'],
        observedAddr: 'a',
      );
      expect(original.peerId, const [0, 1, 2]);
      expect(original.ipAddress, 'a');
      expect(original.port, 1);
      expect(original.protocols, ['a']);
      expect(original.latency, 1);
      expect(original.connectionStatus, isNotNull);
      expect(original.lastSeen, isNotNull);
      expect(original.agentVersion, 'a');
      expect(original.publicKey, const [0, 1, 2]);
      expect(original.addresses, ['a']);
      expect(original.observedAddr, 'a');
      original.hasPeerId();
      original.clearPeerId();
      original.hasIpAddress();
      original.clearIpAddress();
      original.hasPort();
      original.clearPort();
      original.protocols.clear();
      original.hasLatency();
      original.clearLatency();
      original.hasConnectionStatus();
      original.clearConnectionStatus();
      original.hasLastSeen();
      original.clearLastSeen();
      original.hasAgentVersion();
      original.clearAgentVersion();
      original.hasPublicKey();
      original.clearPublicKey();
      original.addresses.clear();
      original.hasObservedAddr();
      original.clearObservedAddr();
      expect(V_PeerInfo.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = V_PeerInfo.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(V_PeerInfo.fromJson(json), isNotNull);
    });
  });
}
