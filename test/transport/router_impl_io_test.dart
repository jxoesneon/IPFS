
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/router_impl_io.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:p2plib/p2plib.dart' as p2p;

// Manual Mock
class ManualMockRouterL2 extends Mock implements p2p.RouterL2 {
  
  static final validPeerIdBytes = Uint8List(64); // 64 bytes required by p2plib

  @override
  Duration get messageTTL => super.noSuchMethod(
        Invocation.getter(#messageTTL),
        returnValue: Duration(seconds: 10),
      );

  @override
  Stream<p2p.Message> get messageStream => super.noSuchMethod(
        Invocation.getter(#messageStream),
        returnValue: Stream<p2p.Message>.empty(),
      ); // Wait, messageStream type? check later. Assuming Stream<p2p.Message>.

  @override
  List<p2p.TransportBase> get transports => super.noSuchMethod(
        Invocation.getter(#transports),
        returnValue: <p2p.TransportBase>[],
      );

  @override
  p2p.PeerId get selfId => super.noSuchMethod(
        Invocation.getter(#selfId),
        returnValue: p2p.PeerId(value: validPeerIdBytes),
      );

  @override
  Future<void> start() => super.noSuchMethod(
        Invocation.method(#start, []),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<void> stop() => super.noSuchMethod(
        Invocation.method(#stop, []),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<p2p.PacketHeader> sendMessage({
    required p2p.PeerId? dstPeerId,
    bool? isConfirmable = false,
    Uint8List? payload, // Removed required
    int? protocolId,
    int? ttl,
    int? messageId,
    Duration? ackTimeout,
    Iterable<p2p.FullAddress>? useAddresses, // Added useAddresses
  }) =>
      super.noSuchMethod(
        Invocation.method(#sendMessage, [], {
          #dstPeerId: dstPeerId,
          #isConfirmable: isConfirmable,
          #payload: payload,
          #protocolId: protocolId,
          #ttl: ttl,
          #messageId: messageId,
          #ackTimeout: ackTimeout,
          #useAddresses: useAddresses,
        }),
        returnValue: Future.value(p2p.PacketHeader(id: 0, issuedAt: 0)),
        returnValueForMissingStub: Future.value(p2p.PacketHeader(id: 0, issuedAt: 0)),
      );

  @override
  void addPeerAddress({
    required p2p.PeerId? peerId,
    required p2p.FullAddress? address,
    p2p.AddressProperties? properties,
    bool? canForward = true,
  }) =>
      super.noSuchMethod(
        Invocation.method(#addPeerAddress, [], {
          #peerId: peerId,
          #address: address,
          #properties: properties,
          #canForward: canForward,
        }),
      );
}

void main() {
  late P2plibRouter router;
  late ManualMockRouterL2 mockRouterL2;
  late IPFSConfig config;
  late StreamController<p2p.Message> messageStreamController;

  setUp(() async {
    mockRouterL2 = ManualMockRouterL2();
    messageStreamController = StreamController<p2p.Message>.broadcast();
    
    // Config
    config = IPFSConfig(
      network: NetworkConfig(
        listenAddresses: ['/ip4/127.0.0.1/udp/4001'],
        bootstrapPeers: [],
      ),
      debug: true,
    );

    // Stub behaviors
    when(mockRouterL2.messageStream).thenAnswer((_) => messageStreamController.stream);
    when(mockRouterL2.transports).thenReturn([]);
    when(mockRouterL2.selfId).thenReturn(p2p.PeerId(value: ManualMockRouterL2.validPeerIdBytes));
    
    // Inject mock into router
    router = P2plibRouter(config, router: mockRouterL2);
  });

  tearDown(() async {
    await messageStreamController.close();
  });

  test('Initialization and Start', () async {
    await router.initialize();
    await router.start();

    // Verify start called
    verify(mockRouterL2.start()).called(1);
    expect(router.isInitialized, isTrue);
  });
  
  test('Properties check', () async { 
    await router.initialize();
    
    expect(router.routerL0, equals(mockRouterL2));
    expect(router.peerID, isNotEmpty);
    expect(router.localPeerId, equals(mockRouterL2.selfId));
  });

  test('Message Sending', () async {
    await router.initialize();
    await router.start();
    
    final vectorPeerId = p2p.PeerId(value: Uint8List(64));
    vectorPeerId.value[0] = 2;
    final destPeerId = vectorPeerId.toString(); 
    final payload = Uint8List.fromList([1, 2, 3]);

    // Send without protocol
    await router.sendMessage(destPeerId, payload);
    
    final captured = verify(mockRouterL2.sendMessage(
      dstPeerId: captureAnyNamed('dstPeerId'),
      payload: captureAnyNamed('payload'),
      isConfirmable: anyNamed('isConfirmable'),
      protocolId: anyNamed('protocolId'),
      ttl: anyNamed('ttl'),
      ackTimeout: anyNamed('ackTimeout'), 
    )).captured;
    
    expect(captured.length, equals(2)); 
  });

  test('Receive Message Filtering', () async {
    await router.initialize();
    await router.start();
    
    final realPeerId = p2p.PeerId(value: Uint8List(64));
    realPeerId.value[0] = 2;
    final peerIdStr = realPeerId.toString();

    final payload = 'Hello';
    final packet = Uint8List.fromList(utf8.encode(payload));
    
    final msg = p2p.Message(
      header: p2p.PacketHeader(
        id: 1,
        issuedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      srcPeerId: realPeerId,
      dstPeerId: mockRouterL2.selfId,
      payload: packet,
    );

    final receivedMessages = <String>[];
    final sub = router.receiveMessages(peerIdStr).listen((m) => receivedMessages.add(m));

    messageStreamController.add(msg);
    
    await Future.delayed(Duration(milliseconds: 100));
    expect(receivedMessages, contains(payload));
    await sub.cancel();
  });

  test('Register Protocol Handler', () async {
    await router.initialize();
    
    final protocol = '/test/1.0';
    final msgContent = 'Test Content';
    final completer = Completer<String>();
    
    router.registerProtocolHandler(protocol, (packet) {
      completer.complete(utf8.decode(packet.datagram));
    });
    
    // Construct packet with protocol
    final protocolBytes = utf8.encode(protocol);
    final dataBytes = utf8.encode(msgContent);
    // Packet format: [len (1 byte)][protocol][data]
    
    final packetBytes = BytesBuilder();
    packetBytes.addByte(protocolBytes.length);
    packetBytes.add(protocolBytes);
    packetBytes.add(dataBytes);
    
    final realPeerId = p2p.PeerId(value: Uint8List(64));
    realPeerId.value[0] = 3;
    
    final msg = p2p.Message(
      header: p2p.PacketHeader(id: 2, issuedAt: 0),
      srcPeerId: realPeerId, 
      dstPeerId: mockRouterL2.selfId,
      payload: packetBytes.toBytes(),
    );
    
    messageStreamController.add(msg);
    
    final result = await completer.future.timeout(Duration(seconds: 1));
    expect(result, equals(msgContent));
  });

  test('Connect calls addPeerAddress', () async {
    final targetPeerId = p2p.PeerId(value: Uint8List(64));
    targetPeerId.value[0] = 4;
    final targetPeerIdStr = targetPeerId.toString();
    final multiaddr = '/ip4/1.2.3.4/udp/1234/p2p/$targetPeerIdStr';
    
    await router.connect(multiaddr);
    
    verify(mockRouterL2.addPeerAddress(
      peerId: anyNamed('peerId'),
      address: anyNamed('address'),
      properties: anyNamed('properties'),
      canForward: anyNamed('canForward'),
    )).called(1);
  });
}
