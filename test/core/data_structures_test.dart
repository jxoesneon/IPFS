import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/metadata.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/data_structures/pin.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

// Mock BlockStore for Pin testing
class MockBlockStore implements BlockStore {
  @override
  PinManager get pinManager => throw UnimplementedError('Mock');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IPLDMetadata Tests', () {
    test('should create and serialize correctly', () {
      final now = DateTime.now();
      final metadata = IPLDMetadata(
        size: 1024,
        properties: {'key': 'value'},
        lastModified: now,
        contentType: 'text/plain',
      );

      expect(metadata.size, 1024);
      expect(metadata.properties['key'], 'value');
      expect(metadata.contentType, 'text/plain');

      final json = metadata.toJson();
      expect(json['size'], 1024);
      expect(json['contentType'], 'text/plain');
      expect(json['lastModified'], now.toIso8601String());
    });
  });

  group('Peer Tests', () {
    test('should create from multiaddr', () async {
      // Generate a 64-byte ID to satisfy PeerId expectation (p2plib requirement?)
      final bytes = Uint8List.fromList(List.filled(64, 1));
      final peerIdStr = Base58().encode(bytes);
      final multiaddr = '/ip4/127.0.0.1/tcp/4001/p2p/$peerIdStr';

      final peer = await Peer.fromMultiaddr(multiaddr);

      // Verify bytes match (toString might be Base64 or other format)
      expect(peer.id.value, equals(bytes));
      expect(peer.addresses.length, 1);
      expect(peer.addresses.first.port, 4001);
    });

    test('should serialize to/from protobuf', () {
      final bytes = Uint8List.fromList(List.filled(64, 1));
      final id = PeerId(value: bytes);
      final address = FullAddress(
        address: InternetAddress('127.0.0.1'),
        port: 4001,
      );

      final peer = Peer(
        id: id,
        addresses: [address],
        latency: 100,
        agentVersion: 'v1.0.0',
      );

      final proto = peer.toProto();
      expect(proto.latency, Int64(100));
      expect(proto.agentVersion, 'v1.0.0');

      final reconstructed = Peer.fromProto(proto);
      expect(reconstructed.latency, 100);
      expect(reconstructed.agentVersion, 'v1.0.0');
      // Note: Address reconstruction might depend on exact string format matching
    });

    test('validates multiaddr parsing', () {
      // Invalid protocol
      expect(parseMultiaddrString('/invalid/127.0.0.1/tcp/4001'), isNull);

      // Invalid port
      expect(parseMultiaddrString('/ip4/127.0.0.1/tcp/0'), isNull);
    });
  });

  group('Pin Tests', () {
    late MockBlockStore mockStore;
    late CID mockCid;

    setUp(() {
      mockStore = MockBlockStore();
      mockCid = CID.v0(Uint8List.fromList(List.filled(32, 1)));
    });

    test('should create and serialize', () {
      final pin = Pin(
        cid: mockCid,
        type: PinTypeProto.PIN_TYPE_RECURSIVE,
        blockStore: mockStore,
      );

      expect(pin.type, PinTypeProto.PIN_TYPE_RECURSIVE);
      // Note: isPinned() requires pinManager which isn't mocked
      // Just verify proto serialization works

      final proto = pin.toProto();
      expect(proto.type, PinTypeProto.PIN_TYPE_RECURSIVE);

      final reconstructed = Pin.fromProto(proto, mockStore);
      expect(reconstructed.cid.encode(), mockCid.encode());
    });
  });
}
