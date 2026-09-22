// test/protocols/bitswap/bitswap_denylist_test.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as message;
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'bitswap_handler_coverage_test.mocks.dart';

class _MockMetricsCollector implements MetricsCollector {
  final List<String> securityEvents = [];

  @override
  void recordSecurityEvent(String type) => securityEvents.add(type);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockIBlockStore mockBlockStore;
  late MockRouterInterface mockRouter;
  late _MockMetricsCollector metrics;

  DenylistService makeDenylist({String action = 'block', bool enabled = true}) {
    return DenylistService(
      SecurityConfig(enableDenylist: enabled, denylistDefaultAction: action),
      metrics,
    );
  }

  BitswapHandler makeHandler(DenylistService? denylist) {
    return BitswapHandler(
      IPFSConfig(),
      mockBlockStore,
      mockRouter,
      denylistService: denylist,
    );
  }

  /// Starts [handler] and returns the registered protocol handler used to
  /// inject inbound packets.
  Future<Future<void> Function(NetworkPacket)> packetHandler(
    BitswapHandler handler,
  ) async {
    await handler.start();
    final captured = verify(
      mockRouter.registerProtocolHandler(any, captureAny),
    ).captured;
    return captured.last as Future<void> Function(NetworkPacket);
  }

  GetBlockResponse foundResponse(Block block) {
    return GetBlockResponse()
      ..found = true
      ..block = block.toProto();
  }

  setUp(() {
    mockBlockStore = MockIBlockStore();
    mockRouter = MockRouterInterface();
    metrics = _MockMetricsCollector();
    when(
      mockBlockStore.getBlock(any),
    ).thenAnswer((_) async => GetBlockResponse()..found = false);
    when(mockRouter.peerID).thenReturn('localPeer');
  });

  group('wantlist serving', () {
    test('blocked CID is never sent as a block', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);
      final send = await packetHandler(handler);

      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);
      when(
        mockBlockStore.getBlock(cidStr),
      ).thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));

      final msg = message.Message()
        ..addWantlistEntry(
          cidStr,
          priority: 1,
          wantType: message.WantType.block,
        );
      await send(NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes()));

      verifyNever(
        mockRouter.sendMessage(
          'peerA',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      );
      final hits = denylist.getAuditLog();
      expect(hits.single.cidOrMultihash, equals(cidStr));
      expect(hits.single.source, equals('bitswap'));
      expect(hits.single.action, equals('block'));
    });

    test(
      'blocked CID with sendDontHave replies DONT_HAVE, not a block',
      () async {
        final denylist = makeDenylist();
        final handler = makeHandler(denylist);
        final send = await packetHandler(handler);

        final data = Uint8List.fromList([4, 5, 6]);
        final cid = await CID.computeForData(data);
        final cidStr = cid.encode();
        denylist.blockCidString(cidStr);
        when(
          mockBlockStore.getBlock(cidStr),
        ).thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));

        final msg = message.Message()
          ..addWantlistEntry(
            cidStr,
            priority: 1,
            wantType: message.WantType.block,
            sendDontHave: true,
          );
        await send(NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes()));

        final captured = verify(
          mockRouter.sendMessage(
            'peerA',
            captureAny,
            protocolId: anyNamed('protocolId'),
          ),
        ).captured;
        final reply = await message.Message.fromBytes(
          captured.first as Uint8List,
        );
        expect(reply.hasBlocks(), isFalse);
        final presences = reply.getBlockPresences();
        expect(presences.single.cid, equals(cidStr));
        expect(
          presences.single.type,
          equals(message.BlockPresenceType.dontHave),
        );
      },
    );

    test('blocked CID never advertises HAVE', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);
      final send = await packetHandler(handler);

      final data = Uint8List.fromList([7, 8, 9]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);
      when(
        mockBlockStore.getBlock(cidStr),
      ).thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));

      final msg = message.Message()
        ..addWantlistEntry(
          cidStr,
          priority: 1,
          wantType: message.WantType.have,
          sendDontHave: true,
        );
      await send(NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes()));

      final captured = verify(
        mockRouter.sendMessage(
          'peerA',
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured;
      final reply = await message.Message.fromBytes(
        captured.first as Uint8List,
      );
      expect(reply.hasBlocks(), isFalse);
      expect(
        reply.getBlockPresences().single.type,
        equals(message.BlockPresenceType.dontHave),
      );
    });

    test('log action still serves the block and records the hit', () async {
      final denylist = makeDenylist(action: 'log');
      final handler = makeHandler(denylist);
      final send = await packetHandler(handler);

      final data = Uint8List.fromList([10, 11, 12]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);
      when(
        mockBlockStore.getBlock(cidStr),
      ).thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));

      final msg = message.Message()
        ..addWantlistEntry(
          cidStr,
          priority: 1,
          wantType: message.WantType.block,
        );
      await send(NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes()));

      final captured = verify(
        mockRouter.sendMessage(
          'peerA',
          captureAny,
          protocolId: anyNamed('protocolId'),
        ),
      ).captured;
      final reply = await message.Message.fromBytes(
        captured.first as Uint8List,
      );
      expect(reply.hasBlocks(), isTrue);
      expect(denylist.getAuditLog().single.action, equals('log'));
      expect(metrics.securityEvents, contains('denylist_logged'));
    });

    test('disabled denylist service is a no-op', () async {
      final denylist = makeDenylist(enabled: false);
      final handler = makeHandler(denylist);
      final send = await packetHandler(handler);

      final data = Uint8List.fromList([13, 14, 15]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);
      when(
        mockBlockStore.getBlock(cidStr),
      ).thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));

      final msg = message.Message()
        ..addWantlistEntry(
          cidStr,
          priority: 1,
          wantType: message.WantType.block,
        );
      await send(NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes()));

      verify(
        mockRouter.sendMessage(
          'peerA',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
      expect(denylist.getAuditLog(), isEmpty);
    });

    test('no denylist service serves normally', () async {
      final handler = makeHandler(null);
      final send = await packetHandler(handler);

      final data = Uint8List.fromList([16, 17, 18]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();
      when(
        mockBlockStore.getBlock(cidStr),
      ).thenAnswer((_) async => foundResponse(Block(cid: cid, data: data)));

      final msg = message.Message()
        ..addWantlistEntry(
          cidStr,
          priority: 1,
          wantType: message.WantType.block,
        );
      await send(NetworkPacket(srcPeerId: 'peerA', datagram: msg.toBytes()));

      verify(
        mockRouter.sendMessage(
          'peerA',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      ).called(1);
    });
  });

  group('want() egress', () {
    test('want() returns empty and never requests a blocked CID', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      final cid = await CID.computeForData(Uint8List.fromList([19, 20, 21]));
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);

      final result = await handler.want([cidStr]);
      expect(result, isEmpty);
      verifyNever(
        mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
      );
      expect(denylist.getAuditLog().single.source, equals('bitswap'));
      expect(denylist.getAuditLog().single.action, equals('block'));
    });

    test('want() requests only the allowed CIDs', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      final allowedData = Uint8List.fromList([22, 23, 24]);
      final allowedCid = await CID.computeForData(allowedData);
      final blockedCid = await CID.computeForData(
        Uint8List.fromList([25, 26, 27]),
      );
      denylist.blockCidString(blockedCid.encode());

      Timer(const Duration(milliseconds: 50), () async {
        await handler.handleBlocks([Block(cid: allowedCid, data: allowedData)]);
      });

      final results = await handler.want([
        allowedCid.encode(),
        blockedCid.encode(),
      ]);
      expect(results.single.data, equals(allowedData));
      expect(
        denylist.getAuditLog().single.cidOrMultihash,
        equals(blockedCid.encode()),
      );
    });

    test('want() under log action still requests the CID', () async {
      final denylist = makeDenylist(action: 'log');
      final handler = makeHandler(denylist);
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      final data = Uint8List.fromList([28, 29, 30]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);

      Timer(const Duration(milliseconds: 50), () async {
        await handler.handleBlocks([Block(cid: cid, data: data)]);
      });

      final results = await handler.want([cidStr]);
      expect(results.single.data, equals(data));
      expect(denylist.getAuditLog().single.action, equals('log'));
    });

    test('handleWantRequest does not broadcast a blocked CID', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);
      await handler.start();
      when(mockRouter.connectedPeers).thenReturn({'peerA'});
      clearInteractions(mockRouter);
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      final cid = await CID.computeForData(Uint8List.fromList([31, 32, 33]));
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);

      await handler.handleWantRequest(cidStr);

      verifyNever(
        mockRouter.sendMessage(any, any, protocolId: anyNamed('protocolId')),
      );
      expect(denylist.getAuditLog().single.source, equals('bitswap'));
    });
  });

  group('forwarding and retrieval', () {
    test('blocked block is not forwarded to interested peers', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);
      final send = await packetHandler(handler);
      when(mockRouter.connectedPeers).thenReturn({'peerA'});

      final data = Uint8List.fromList([34, 35, 36]);
      final cid = await CID.computeForData(data);
      final cidStr = cid.encode();

      // peerA records a want while the CID is still allowed; the block is
      // missing locally and sendDontHave is false, so nothing is sent yet.
      final wantMsg = message.Message()
        ..addWantlistEntry(
          cidStr,
          priority: 1,
          wantType: message.WantType.block,
        );
      await send(
        NetworkPacket(srcPeerId: 'peerA', datagram: wantMsg.toBytes()),
      );

      // The CID is denylisted before the block arrives.
      denylist.blockCidString(cidStr);
      await handler.handleBlocks([Block(cid: cid, data: data)]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verifyNever(
        mockRouter.sendMessage(
          'peerA',
          any,
          protocolId: anyNamed('protocolId'),
        ),
      );
      expect(denylist.getAuditLog().single.source, equals('bitswap'));
    });

    test('wantBlock returns null for a blocked CID', () async {
      final denylist = makeDenylist();
      final handler = makeHandler(denylist);
      await handler.start();

      final cid = await CID.computeForData(Uint8List.fromList([37, 38, 39]));
      final cidStr = cid.encode();
      denylist.blockCidString(cidStr);

      final result = await handler.wantBlock(cidStr);
      expect(result, isNull);
      final hits = denylist.getAuditLog();
      expect(hits.single.source, equals('bitswap'));
      expect(hits.single.action, equals('block'));
    });
  });
}
