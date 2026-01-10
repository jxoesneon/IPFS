import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/proto/generated/circuit_relay.pb.dart';
import 'package:dart_ipfs/src/transport/circuit_relay_service.dart';
import 'package:dart_ipfs/src/transport/p2plib_router.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/utils/base58.dart';
import 'package:p2plib/p2plib.dart' as p2p;
import 'package:test/test.dart';

// Manual Mock to avoid Mockito null-safety issues
class MockP2plibRouter implements P2plibRouter {
  final Map<String, void Function(NetworkPacket)> handlers = {};
  final List<SentMessage> sentMessages = [];
  final List<SentRequest> sentRequests = [];

  @override
  void registerProtocolHandler(String protocolId, void Function(NetworkPacket) handler) {
    handlers[protocolId] = handler;
  }

  @override
  Future<void> sendMessage(String peerId, Uint8List message, {String? protocolId}) async {
    sentMessages.add(SentMessage(peerId, message));
  }

  @override
  Future<Uint8List> sendRequest(String peerId, String protocolId, Uint8List request) async {
    sentRequests.add(SentRequest(peerId, protocolId, request));

    // Auto-respond for STOP Connect
    if (protocolId == CircuitRelayService.stopProtocolId) {
      final msg = StopMessage.fromBuffer(request);
      if (msg.type == StopMessage_Type.CONNECT) {
        final response = StopMessage()
          ..type = StopMessage_Type.STATUS
          ..status = Status.OK;
        return Uint8List.fromList(response.writeToBuffer());
      }
    }
    return Uint8List(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class SentMessage {
  SentMessage(this.peerId, this.message);
  final String peerId;
  final Uint8List message;
}

class SentRequest {
  SentRequest(this.peerId, this.protocolId, this.request);
  final String peerId;
  final String protocolId;
  final Uint8List request;
}

void main() {
  group('CircuitRelayService', () {
    late CircuitRelayService service;
    late MockP2plibRouter mockRouter;
    late IPFSConfig config;

    setUp(() {
      mockRouter = MockP2plibRouter();
      config = IPFSConfig(enableCircuitRelay: true);
      service = CircuitRelayService(mockRouter, config);
      service.start();
    });

    test('should register protocol handlers on start', () {
      expect(mockRouter.handlers.containsKey(CircuitRelayService.hopProtocolId), isTrue);
      expect(mockRouter.handlers.containsKey(CircuitRelayService.stopProtocolId), isTrue);
    });

    test('handleReserve should grant reservation', () async {
      final srcPeerId = p2p.PeerId(
        value: (Uint8List(64)
          ..[0] = 0x12
          ..[1] = 0x20
          ..fillRange(2, 64, 1)),
      );
      final reserveMsg = HopMessage()..type = HopMessage_Type.RESERVE;

      // Simulate incoming packet
      final packet = p2p.Packet(
        datagram: Uint8List.fromList(reserveMsg.writeToBuffer()),
        header: const p2p.PacketHeader(id: 1, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 0),
      )..srcPeerId = srcPeerId;

      mockRouter.handlers[CircuitRelayService.hopProtocolId]!(
        NetworkPacket(datagram: packet.datagram, srcPeerId: Base58().encode(srcPeerId.value)),
      );

      expect(mockRouter.sentMessages.length, 1);
      final sent = mockRouter.sentMessages.first;
      expect(sent.peerId, Base58().encode(srcPeerId.value));

      final response = HopMessage.fromBuffer(sent.message);
      expect(response.type, HopMessage_Type.STATUS);
      expect(response.status, Status.OK);
      expect(response.hasReservation(), isTrue);
    });

    test('handleConnect should fail if no reservation', () async {
      final srcPeerId = p2p.PeerId(
        value: (Uint8List(64)
          ..[0] = 0x12
          ..[1] = 0x20
          ..fillRange(2, 64, 1)),
      );
      final destPeerId = p2p.PeerId(
        value: (Uint8List(64)
          ..[0] = 0x12
          ..[1] = 0x20
          ..fillRange(2, 64, 2)),
      );

      final connectMsg = HopMessage()
        ..type = HopMessage_Type.CONNECT
        ..peer = (Peer()..id = destPeerId.value);

      // Simulate incoming packet
      final packet = p2p.Packet(
        datagram: Uint8List.fromList(connectMsg.writeToBuffer()),
        header: const p2p.PacketHeader(id: 2, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 0),
      )..srcPeerId = srcPeerId;

      mockRouter.handlers[CircuitRelayService.hopProtocolId]!(
        NetworkPacket(datagram: packet.datagram, srcPeerId: Base58().encode(srcPeerId.value)),
      );

      // Should invoke sendMessage with FAILED status
      expect(mockRouter.sentMessages.length, 1);
      final response = HopMessage.fromBuffer(mockRouter.sentMessages.first.message);
      expect(response.status, Status.FAILED);
    });

    test('should forward packets after successful connection', () async {
      final srcPeerId = p2p.PeerId(
        value: (Uint8List(64)
          ..[0] = 0x12
          ..[1] = 0x20
          ..fillRange(2, 64, 1)),
      );
      final destPeerId = p2p.PeerId(
        value: (Uint8List(64)
          ..[0] = 0x12
          ..[1] = 0x20
          ..fillRange(2, 64, 2)),
      );

      // 1. Establish Reservation for Dest (Dest must reserve to accept incoming)
      final reservePacket = p2p.Packet(
        datagram: Uint8List.fromList(
          (HopMessage()..type = HopMessage_Type.RESERVE).writeToBuffer(),
        ),
        header: const p2p.PacketHeader(id: 1, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 0),
      )..srcPeerId = destPeerId;

      mockRouter.handlers[CircuitRelayService.hopProtocolId]!(
        NetworkPacket(
          datagram: reservePacket.datagram,
          srcPeerId: Base58().encode(destPeerId.value),
        ),
      );
      expect(mockRouter.sentMessages.length, 1); // Status OK for reservation
      mockRouter.sentMessages.clear();

      // 2. Connect Source -> Dest
      final connectMsg = HopMessage()
        ..type = HopMessage_Type.CONNECT
        ..peer = (Peer()..id = destPeerId.value);

      final connectPacket = p2p.Packet(
        datagram: Uint8List.fromList(connectMsg.writeToBuffer()),
        header: const p2p.PacketHeader(id: 2, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 0),
      )..srcPeerId = srcPeerId;

      // Handle Connect (Should trigger STOP to Dest)
      // Because 'sendRequest' in Mock auto-responds with STATUS.OK via Future return,
      // _handleConnect should complete successfully.
      // Wait for async handler
      await (mockRouter.handlers[CircuitRelayService.hopProtocolId]!(
            NetworkPacket(
              datagram: connectPacket.datagram,
              srcPeerId: Base58().encode(srcPeerId.value),
            ),
          )
          as Future?);

      // Wait a tick for async execution inside _handleConnect
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(mockRouter.sentRequests.length, 1); // STOP request sent
      expect(mockRouter.sentMessages.length, 1); // STATUS OK to Source
      mockRouter.sentMessages.clear();

      // 3. Bridging: Send packet from Source
      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final transportPacket = p2p.Packet(
        datagram: payload,
        header: const p2p.PacketHeader(id: 3, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 0),
      )..srcPeerId = srcPeerId;

      mockRouter.handlers[CircuitRelayService.transportProtocolId]!(
        NetworkPacket(
          datagram: transportPacket.datagram,
          srcPeerId: Base58().encode(srcPeerId.value),
        ),
      );

      // Expect forwarding to Dest
      expect(mockRouter.sentMessages.length, 1);
      final forwarded = mockRouter.sentMessages.first;
      expect(
        forwarded.peerId,
        Base58().encode(destPeerId.value),
      ); // Actually checks equality of values or ref?
      // PeerId equality should work if values match. logic uses toString for map keys.
      // But sendMessage uses the stored PeerId object from context.
      expect(forwarded.message, payload);

      mockRouter.sentMessages.clear();

      // 4. Bridging: Reply from Dest
      final replyPayload = Uint8List.fromList([5, 6, 7, 8]);
      final replyPacket = p2p.Packet(
        datagram: replyPayload,
        header: const p2p.PacketHeader(id: 4, issuedAt: 0),
        srcFullAddress: p2p.FullAddress(address: InternetAddress.loopbackIPv4, port: 0),
      )..srcPeerId = destPeerId;

      mockRouter.handlers[CircuitRelayService.transportProtocolId]!(
        NetworkPacket(datagram: replyPacket.datagram, srcPeerId: Base58().encode(destPeerId.value)),
      );

      // Expect forwarding back to Source
      expect(mockRouter.sentMessages.length, 1);
      final forwardedReply = mockRouter.sentMessages.first;
      expect(forwardedReply.peerId, Base58().encode(srcPeerId.value));
      expect(forwardedReply.message, replyPayload);
    });
  });
}
