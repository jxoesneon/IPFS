// test/protocols/identify/identify_handler_test.dart
//
// Tests for the libp2p Identify protocol handler and push handler.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/peer/peer_record.dart';
import 'package:dart_ipfs/src/core/peer/peer_record_pb.dart';
import 'package:dart_ipfs/src/protocols/identify/identify_handler.dart';
import 'package:dart_ipfs/src/protocols/identify/identify_pb.dart';
import 'package:dart_ipfs/src/protocols/identify/identify_push_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_routing_table_interface.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

/// A mock router for testing protocol handlers.
class MockRouter implements RouterInterface {
  final Map<String, void Function(NetworkPacket)> _handlers = {};
  final Set<String> _protocols = {};
  final Set<String> _connectedPeers = {};
  final List<String> _listenAddresses = [];

  /// Responses keyed by peerId for sendRequest.
  final Map<String, Uint8List?> _requestResponses = {};

  /// Messages sent via sendMessage (peerId, protocolId, data).
  final List<_SentMessage> _sentMessages = [];

  @override
  String get peerID => 'QmTestPeerId';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => _connectedPeers;

  @override
  Stream<ConnectionEvent> get connectionEvents =>
      const Stream<ConnectionEvent>.empty();

  @override
  Stream<MessageEvent> get messageEvents => const Stream<MessageEvent>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> connect(String multiaddress) async {
    _connectedPeers.add(multiaddress);
  }

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {
    _connectedPeers.remove(peerIdOrMultiaddress);
  }

  @override
  List<String> get listeningAddresses => List.unmodifiable(_listenAddresses);

  @override
  List<String> listConnectedPeers() => _connectedPeers.toList();

  @override
  bool isConnectedPeer(String peerIdStr) => _connectedPeers.contains(peerIdStr);

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    _sentMessages.add(
      _SentMessage(peerIdStr, protocolId ?? '/ipfs/1.0.0', message),
    );
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async {
    return _requestResponses[peerId];
  }

  @override
  Stream<Uint8List> receiveMessages(String peerId) =>
      const Stream<Uint8List>.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _handlers[protocolId] = handler;
  }

  @override
  void removeMessageHandler(String protocolId) {
    _handlers.remove(protocolId);
  }

  @override
  void unregisterProtocolHandler(String protocolId) {
    removeMessageHandler(protocolId);
  }

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  void registerProtocol(String protocolId) {
    _protocols.add(protocolId);
  }

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}

  @override
  void emitEvent(String topic, Uint8List data) {}

  @override
  void onEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  void offEvent(String topic, void Function(NetworkMessage) handler) {}

  @override
  Object? parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {}

  @override
  DHTRoutingTable? get dhtRoutingTable => null;

  // --- Test helpers ---

  void setListenAddresses(List<String> addrs) {
    _listenAddresses
      ..clear()
      ..addAll(addrs);
  }

  void setConnectedPeers(List<String> peers) {
    _connectedPeers
      ..clear()
      ..addAll(peers);
  }

  void setRequestResponse(String peerId, Uint8List? response) {
    _requestResponses[peerId] = response;
  }

  /// Simulates an incoming protocol message.
  void simulateIncoming(String protocolId, String srcPeerId, Uint8List data) {
    final handler = _handlers[protocolId];
    expect(handler, isNotNull, reason: 'No handler registered for $protocolId');
    handler!(
      NetworkPacket(
        srcPeerId: srcPeerId,
        datagram: data,
        responder: (response) async {
          _lastResponse = response;
        },
      ),
    );
  }

  Uint8List? _lastResponse;
  Uint8List? get lastResponse => _lastResponse;

  List<_SentMessage> get sentMessages => _sentMessages;
}

class _SentMessage {
  _SentMessage(this.peerId, this.protocolId, this.data);
  final String peerId;
  final String protocolId;
  final Uint8List data;
}

void main() {
  late MockRouter router;
  late SimpleKeyPair keyPair;
  late Uint8List publicKeyBytes;
  late Uint8List peerIdBytes;
  late PeerRecordSigner signer;

  setUp(() async {
    router = MockRouter();
    final ed25519 = Ed25519();
    keyPair = await ed25519.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    publicKeyBytes = Uint8List.fromList(pubKey.bytes);
    peerIdBytes = Uint8List.fromList(pubKey.bytes);
    signer = PeerRecordSigner(
      keyPair: keyPair,
      peerIdBytes: peerIdBytes,
      publicKeyBytes: publicKeyBytes,
    );
  });

  group('IdentifyHandler', () {
    test('start registers protocol handler', () async {
      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
        protocols: ['/ipfs/bitswap/1.2.0', '/ipfs/ping/1.0.0'],
      );

      await handler.start();
      expect(handler.isStarted, isTrue);

      // Verify the handler was registered
      router.simulateIncoming('/ipfs/id/1.0.0', 'QmRemote', Uint8List(0));

      // Wait for async response
      await Future.delayed(const Duration(milliseconds: 100));

      expect(router.lastResponse, isNotNull);
      final identify = IdentifyPb.decode(router.lastResponse!);
      expect(identify.agentVersion, equals('dart_ipfs/1.11.5'));
      expect(identify.protocolVersion, equals('ipfs/0.1.0'));
      expect(identify.protocols, contains('/ipfs/bitswap/1.2.0'));
      expect(identify.protocols, contains('/ipfs/ping/1.0.0'));
    });

    test('stop removes protocol handler', () async {
      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );

      await handler.start();
      expect(handler.isStarted, isTrue);

      await handler.stop();
      expect(handler.isStarted, isFalse);
    });

    test('response includes listen addresses', () async {
      router.setListenAddresses([
        '/ip4/0.0.0.0/tcp/4001',
        '/ip4/127.0.0.1/tcp/4002',
      ]);

      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
        protocols: ['/ipfs/id/1.0.0'],
      );

      await handler.start();
      router.simulateIncoming('/ipfs/id/1.0.0', 'QmRemote', Uint8List(0));
      await Future.delayed(const Duration(milliseconds: 100));

      final identify = IdentifyPb.decode(router.lastResponse!);
      expect(identify.listenAddrs.length, equals(2));
      expect(
        utf8.decode(identify.listenAddrs[0]),
        equals('/ip4/0.0.0.0/tcp/4001'),
      );
    });

    test('response includes public key', () async {
      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );

      await handler.start();
      router.simulateIncoming('/ipfs/id/1.0.0', 'QmRemote', Uint8List(0));
      await Future.delayed(const Duration(milliseconds: 100));

      final identify = IdentifyPb.decode(router.lastResponse!);
      expect(identify.publicKey, isNotNull);
      final pubKey = PublicKeyPb.decode(identify.publicKey!);
      expect(pubKey.type, equals(KeyType.ed25519));
      expect(pubKey.data, equals(publicKeyBytes));
    });

    test('response includes signed peer record when signer provided', () async {
      router.setListenAddresses(['/ip4/0.0.0.0/tcp/4001']);

      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
        protocols: ['/ipfs/ping/1.0.0'],
        peerRecordSigner: signer,
      );

      await handler.start();
      router.simulateIncoming('/ipfs/id/1.0.0', 'QmRemote', Uint8List(0));
      await Future.delayed(const Duration(milliseconds: 200));

      final identify = IdentifyPb.decode(router.lastResponse!);
      expect(identify.signedPeerRecord, isNotNull);

      // Verify the signed peer record
      final verifier = PeerRecordVerifier();
      final spr = await verifier.verify(identify.signedPeerRecord!);
      expect(spr, isNotNull);
      expect(spr!.record.addresses.length, equals(1));
    });

    test('response works without signed peer record', () async {
      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );

      await handler.start();
      router.simulateIncoming('/ipfs/id/1.0.0', 'QmRemote', Uint8List(0));
      await Future.delayed(const Duration(milliseconds: 100));

      final identify = IdentifyPb.decode(router.lastResponse!);
      expect(identify.signedPeerRecord, isNull);
    });

    test('addProtocol and removeProtocol modify supported list', () async {
      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
        protocols: ['/ipfs/ping/1.0.0'],
      );

      expect(handler.protocols, equals(['/ipfs/ping/1.0.0']));

      handler.addProtocol('/ipfs/bitswap/1.2.0');
      expect(handler.protocols, contains('/ipfs/bitswap/1.2.0'));

      handler.removeProtocol('/ipfs/ping/1.0.0');
      expect(handler.protocols, isNot(contains('/ipfs/ping/1.0.0')));

      // Adding duplicate does nothing
      handler.addProtocol('/ipfs/bitswap/1.2.0');
      final count = handler.protocols
          .where((p) => p == '/ipfs/bitswap/1.2.0')
          .length;
      expect(count, equals(1));
    });

    test('identify queries remote peer', () async {
      final remoteIdentify = IdentifyPb(
        protocolVersion: 'ipfs/0.1.0',
        agentVersion: 'go-ipfs/0.12.0',
        protocols: ['/ipfs/bitswap/1.2.0', '/ipfs/kad/1.0.0'],
        listenAddrs: [Uint8List.fromList(utf8.encode('/ip4/1.2.3.4/tcp/4001'))],
      );
      router.setRequestResponse('QmRemote', remoteIdentify.encode());

      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );

      final result = await handler.identify('QmRemote');
      expect(result, isNotNull);
      expect(result!.agentVersion, equals('go-ipfs/0.12.0'));
      expect(result.protocols.length, equals(2));
    });

    test('identify returns null on empty response', () async {
      router.setRequestResponse('QmRemote', Uint8List(0));

      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );

      final result = await handler.identify('QmRemote');
      expect(result, isNull);
    });

    test('identify returns null on null response', () async {
      router.setRequestResponse('QmRemote', null);

      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );

      final result = await handler.identify('QmRemote');
      expect(result, isNull);
    });

    test('buildIdentifyMessage returns valid message', () async {
      router.setListenAddresses(['/ip4/0.0.0.0/tcp/4001']);

      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
        protocols: ['/ipfs/ping/1.0.0'],
      );

      final message = await handler.buildIdentifyMessage();
      expect(message.agentVersion, equals('dart_ipfs/1.11.5'));
      expect(message.protocolVersion, equals('ipfs/0.1.0'));
      expect(message.protocols, equals(['/ipfs/ping/1.0.0']));
      expect(message.listenAddrs.length, equals(1));
    });

    test('peerIdBytes getter returns copy', () async {
      final handler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );

      final bytes = handler.peerIdBytes;
      expect(bytes, equals(peerIdBytes));
      // Verify it's a copy
      expect(identical(bytes, peerIdBytes), isFalse);
    });
  });

  group('IdentifyPushHandler', () {
    test('start registers push protocol handler', () async {
      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
        protocols: ['/ipfs/ping/1.0.0'],
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      await pushHandler.start();
      expect(pushHandler.isStarted, isTrue);
    });

    test('stop cleans up', () async {
      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      await pushHandler.start();
      await pushHandler.stop();
      expect(pushHandler.isStarted, isFalse);
    });

    test('receives push from remote peer and emits event', () async {
      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      await pushHandler.start();

      final events = <IdentifyPushEvent>[];
      pushHandler.pushEvents.listen(events.add);

      final remoteIdentify = IdentifyPb(
        agentVersion: 'go-ipfs/0.12.0',
        protocols: ['/ipfs/bitswap/1.2.0'],
        listenAddrs: [
          Uint8List.fromList([1, 2, 3]),
        ],
      );

      router.simulateIncoming(
        '/ipfs/id/push/1.0.0',
        'QmRemote',
        remoteIdentify.encode(),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(events.length, equals(1));
      expect(events[0].peerId, equals('QmRemote'));
      expect(events[0].identify.agentVersion, equals('go-ipfs/0.12.0'));
    });

    test('ignores empty push message', () async {
      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      await pushHandler.start();

      final events = <IdentifyPushEvent>[];
      pushHandler.pushEvents.listen(events.add);

      router.simulateIncoming('/ipfs/id/push/1.0.0', 'QmRemote', Uint8List(0));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(events, isEmpty);
    });

    test('pushUpdate sends to all connected peers', () async {
      router.setConnectedPeers(['QmPeer1', 'QmPeer2', 'QmPeer3']);
      router.setListenAddresses(['/ip4/0.0.0.0/tcp/4001']);

      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
        protocols: ['/ipfs/ping/1.0.0'],
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      await pushHandler.start();
      await pushHandler.pushUpdate();

      expect(router.sentMessages.length, equals(3));
      for (final msg in router.sentMessages) {
        expect(msg.protocolId, equals('/ipfs/id/push/1.0.0'));
      }
    });

    test('pushUpdate does nothing when no connected peers', () async {
      router.setConnectedPeers([]);

      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      await pushHandler.start();
      await pushHandler.pushUpdate();

      expect(router.sentMessages, isEmpty);
    });

    test('pushUpdate warns when not started', () async {
      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      // Not started
      await pushHandler.pushUpdate();
      expect(router.sentMessages, isEmpty);
    });

    test('pushToPeer sends to single peer', () async {
      router.setListenAddresses(['/ip4/0.0.0.0/tcp/4001']);

      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      await pushHandler.start();
      await pushHandler.pushToPeer('QmTarget');

      expect(router.sentMessages.length, equals(1));
      expect(router.sentMessages[0].peerId, equals('QmTarget'));
      expect(router.sentMessages[0].protocolId, equals('/ipfs/id/push/1.0.0'));
    });

    test('pushToPeer warns when not started', () async {
      final identifyHandler = IdentifyHandler(
        router: router,
        keyPair: keyPair,
        publicKeyBytes: publicKeyBytes,
        peerIdBytes: peerIdBytes,
      );
      final pushHandler = IdentifyPushHandler(
        router: router,
        identifyHandler: identifyHandler,
      );

      // Not started — should return without sending
      await pushHandler.pushToPeer('QmTarget');
      expect(router.sentMessages, isEmpty);
    });
  });

  group('IdentifyPb', () {
    test('encode/decode roundtrip with all fields', () {
      final msg = IdentifyPb(
        publicKey: Uint8List.fromList([1, 2, 3]),
        listenAddrs: [
          Uint8List.fromList([4, 5]),
          Uint8List.fromList([6, 7]),
        ],
        protocols: ['/ipfs/ping/1.0.0', '/ipfs/bitswap/1.2.0'],
        observedAddr: Uint8List.fromList([8, 9]),
        protocolVersion: 'ipfs/0.1.0',
        agentVersion: 'dart_ipfs/1.11.5',
        signedPeerRecord: Uint8List.fromList([10, 11, 12]),
      );

      final encoded = msg.encode();
      final decoded = IdentifyPb.decode(encoded);

      expect(decoded, equals(msg));
    });

    test('encode/decode with minimal fields', () {
      final msg = IdentifyPb(
        protocolVersion: 'ipfs/0.1.0',
        agentVersion: 'test/0.0.1',
      );

      final encoded = msg.encode();
      final decoded = IdentifyPb.decode(encoded);

      expect(decoded.protocolVersion, equals('ipfs/0.1.0'));
      expect(decoded.agentVersion, equals('test/0.0.1'));
      expect(decoded.listenAddrs, isEmpty);
      expect(decoded.protocols, isEmpty);
    });

    test('encode/decode with empty message', () {
      final msg = IdentifyPb();
      final encoded = msg.encode();
      final decoded = IdentifyPb.decode(encoded);

      expect(decoded.protocolVersion, isNull);
      expect(decoded.agentVersion, isNull);
      expect(decoded.listenAddrs, isEmpty);
    });

    test('toString contains useful info', () {
      final msg = IdentifyPb(
        protocolVersion: 'ipfs/0.1.0',
        agentVersion: 'dart_ipfs/1.11.5',
        protocols: ['/ipfs/ping/1.0.0'],
        signedPeerRecord: Uint8List.fromList([1]),
      );
      final s = msg.toString();
      expect(s, contains('dart_ipfs/1.11.5'));
      expect(s, contains('ipfs/0.1.0'));
      expect(s, contains('hasSignedPeerRecord: true'));
    });
  });
}
