import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/protocols/dht/dht_protocol_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/routing_table.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'dht_protocol_handler_test.mocks.dart';

@GenerateMocks([P2plibRouter, Datastore, RoutingTable])
void main() {
  late MockP2plibRouter mockRouter;
  late MockDatastore mockStorage;
  late MockRoutingTable mockRoutingTable;
  late DHTProtocolHandler handler;
  late Future<void> Function(NetworkPacket) messageHandler;

  setUp(() {
    mockRouter = MockP2plibRouter();
    mockStorage = MockDatastore();
    mockRoutingTable = MockRoutingTable();

    when(mockRouter.getRoutingTable()).thenReturn(mockRoutingTable);

    // Capture the handler
    when(mockRouter.registerProtocolHandler(any, any)).thenAnswer((
      Invocation inv,
    ) {
      if (inv.positionalArguments[0] == DHTProtocolHandler.protocolId) {
        messageHandler = inv.positionalArguments[1];
      }
    });

    handler = DHTProtocolHandler(mockRouter, mockStorage);
  });

  NetworkPacket createPacket(kad.Message message, [String peerId = 'srcPeer']) {
    return NetworkPacket(srcPeerId: peerId, datagram: message.writeToBuffer());
  }

  group('DHTProtocolHandler', () {
    test('handles PING', () async {
      final pingRequest = kad.Message()..type = kad.Message_MessageType.PING;
      final packet = createPacket(pingRequest);

      await messageHandler(packet);

      final captured =
          verify(mockRouter.sendMessage(any, captureAny)).captured.single
              as Uint8List;
      final response = kad.Message.fromBuffer(captured);
      expect(response.type, equals(kad.Message_MessageType.PING));
    });

    test('handles FIND_NODE', () async {
      final targetId = PeerId(value: Uint8List.fromList([1, 2, 3]));
      final findNodeRequest = kad.Message()
        ..type = kad.Message_MessageType.FIND_NODE
        ..key = targetId.value;

      final closerPeerId = PeerId(value: Uint8List.fromList([4, 5, 6]));
      when(
        mockRoutingTable.getNearestPeers(any, any),
      ).thenReturn([closerPeerId]);

      await messageHandler(createPacket(findNodeRequest));

      final captured =
          verify(mockRouter.sendMessage(any, captureAny)).captured.single
              as Uint8List;
      final response = kad.Message.fromBuffer(captured);
      expect(response.type, equals(kad.Message_MessageType.FIND_NODE));
      expect(response.closerPeers.length, 1);
      expect(response.closerPeers.first.id, equals(closerPeerId.value));
    });

    test('handles GET_VALUE found', () async {
      final keyStr = 'testKey';
      final key = utf8.encode(keyStr);
      final value = Uint8List.fromList([10, 20, 30]);

      final getRequest = kad.Message()
        ..type = kad.Message_MessageType.GET_VALUE
        ..key = key;

      when(mockStorage.get(any)).thenAnswer((_) async => value);

      await messageHandler(createPacket(getRequest));

      final captured =
          verify(mockRouter.sendMessage(any, captureAny)).captured.single
              as Uint8List;
      final response = kad.Message.fromBuffer(captured);
      expect(response.type, equals(kad.Message_MessageType.GET_VALUE));
      expect(response.record.value, equals(value));
    });

    test('handles GET_VALUE not found', () async {
      final key = utf8.encode('missingKey');
      final getRequest = kad.Message()
        ..type = kad.Message_MessageType.GET_VALUE
        ..key = key;

      when(mockStorage.get(any)).thenAnswer((_) async => null);
      when(mockRoutingTable.getNearestPeers(any, any)).thenReturn([]);

      await messageHandler(createPacket(getRequest));

      final captured =
          verify(mockRouter.sendMessage(any, captureAny)).captured.single
              as Uint8List;
      final response = kad.Message.fromBuffer(captured);
      expect(response.type, equals(kad.Message_MessageType.GET_VALUE));
      expect(response.hasRecord(), isFalse);
    });

    test('handles PUT_VALUE', () async {
      final keyStr = 'putKey';
      final value = Uint8List.fromList([100, 200]);
      final putRequest = kad.Message()
        ..type = kad.Message_MessageType.PUT_VALUE
        ..key = utf8.encode(keyStr)
        ..record = (dht_pb.Record()..value = value);

      await messageHandler(createPacket(putRequest));

      verify(mockStorage.put(any, any)).called(1);

      final captured =
          verify(mockRouter.sendMessage(any, captureAny)).captured.single
              as Uint8List;
      final response = kad.Message.fromBuffer(captured);
      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
    });

    test('handles unknown message type', () async {
      final unknownMsg = kad.Message()
        ..type = kad
            .Message_MessageType
            .GET_PROVIDERS; // Not explicitly handled in switch
      await messageHandler(createPacket(unknownMsg));
      verifyNever(mockRouter.sendMessage(any, any));
    });
  });
}
