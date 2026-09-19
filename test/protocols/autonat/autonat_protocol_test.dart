// test/protocols/autonat/autonat_protocol_test.dart
import 'dart:async';
import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/protocols/autonat/autonat_protocol.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';

class _FakeRouter extends FakeRouter {
  final List<_SendMessageWithResponseCall> responseCalls = [];
  final List<_SendMessageCall> sentMessages = [];
  final List<String> connectAttempts = [];
  final List<String> disconnectAttempts = [];
  final Map<String, void Function(NetworkPacket)> handlers = {};
  Uint8List? responseBytes;
  bool connectShouldFail = false;
  bool disconnectShouldFail = false;

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async {
    responseCalls.add(
      _SendMessageWithResponseCall(peerId, message, protocolId, timeout),
    );
    if (responseBytes == null) throw Exception('no response configured');
    return responseBytes!;
  }

  @override
  Future<void> sendMessage(
    String peerId,
    Uint8List message, {
    String? protocolId,
  }) async {
    sentMessages.add(_SendMessageCall(peerId, message, protocolId));
  }

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    handlers[protocolId] = handler;
  }

  @override
  void unregisterProtocolHandler(String protocolId) {
    handlers.remove(protocolId);
  }

  @override
  Future<void> connect(String multiaddress) async {
    connectAttempts.add(multiaddress);
    if (connectShouldFail) throw Exception('connect failed');
  }

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {
    disconnectAttempts.add(peerIdOrMultiaddress);
    if (disconnectShouldFail) throw Exception('disconnect failed');
  }
}

class _SendMessageWithResponseCall {
  _SendMessageWithResponseCall(
    this.peerId,
    this.message,
    this.protocolId,
    this.timeout,
  );

  final String peerId;
  final Uint8List message;
  final String? protocolId;
  final Duration? timeout;
}

class _SendMessageCall {
  _SendMessageCall(this.peerId, this.message, this.protocolId);

  final String peerId;
  final Uint8List message;
  final String? protocolId;
}

void main() {
  group('DialRequest', () {
    test('encode/decode roundtrip', () {
      final addrs = [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5]),
      ];
      final request = DialRequest(addrs: addrs);
      final decoded = DialRequest.decode(request.encode());
      expect(decoded.addrs.length, equals(2));
      expect(decoded.addrs[0], equals(addrs[0]));
      expect(decoded.addrs[1], equals(addrs[1]));
    });

    test('decode empty message yields empty addrs', () {
      final decoded = DialRequest.decode(Uint8List(0));
      expect(decoded.addrs, isEmpty);
    });

    test('decode skips unknown fields', () {
      // Field 2, wire type 0, value 42
      final unknown = Uint8List.fromList([0x10, 0x2a]);
      final request = DialRequest(
        addrs: [
          Uint8List.fromList([1]),
        ],
      );
      final bytes = Uint8List.fromList(
        request.encode().followedBy(unknown).toList(),
      );
      final decoded = DialRequest.decode(bytes);
      expect(decoded.addrs.length, equals(1));
      expect(decoded.addrs.first, equals(Uint8List.fromList([1])));
    });

    test('decode throws FormatException on truncated field', () {
      // Field 1, wire type 2, declared length 10, only 1 byte present.
      final bytes = Uint8List.fromList([0x0a, 0x0a, 0x01]);
      expect(() => DialRequest.decode(bytes), throwsFormatException);
    });

    test('decode skips a length-delimited unknown field', () {
      // Field 2, wire type 2, length 2 followed by 2 bytes — skipped.
      final bytes = Uint8List.fromList([0x12, 0x02, 0xaa, 0xbb]);
      final decoded = DialRequest.decode(bytes);
      expect(decoded.addrs, isEmpty);
    });

    test('decode throws FormatException when an unknown field length '
        'exceeds bounds', () {
      // Field 2, wire type 2, declared length 10, only 1 byte present.
      final bytes = Uint8List.fromList([0x12, 0x0a, 0x01]);
      expect(() => DialRequest.decode(bytes), throwsFormatException);
    });

    test('decode throws FormatException on unsupported wire type', () {
      // Field 3, wire type 1 (fixed64) — unsupported.
      final bytes = Uint8List.fromList([0x19, 0x00]);
      expect(() => DialRequest.decode(bytes), throwsFormatException);
    });
  });

  group('DialResponse', () {
    test('encode/decode roundtrip with status text', () {
      final response = DialResponse(
        status: DialResponseStatus.ok,
        statusText: 'success',
      );
      final decoded = DialResponse.decode(response.encode());
      expect(decoded.status, equals(DialResponseStatus.ok));
      expect(decoded.statusText, equals('success'));
    });

    test('decode without status defaults to dialError', () {
      final decoded = DialResponse.decode(Uint8List(0));
      expect(decoded.status, equals(DialResponseStatus.dialError));
      expect(decoded.statusText, isNull);
    });

    test('decode skips unknown fields', () {
      final response = DialResponse(
        status: DialResponseStatus.dialRefused,
        statusText: 'busy',
      );
      // Field 3, wire type 0, value 7
      final unknown = Uint8List.fromList([0x18, 0x07]);
      final bytes = Uint8List.fromList(
        response.encode().followedBy(unknown).toList(),
      );
      final decoded = DialResponse.decode(bytes);
      expect(decoded.status, equals(DialResponseStatus.dialRefused));
      expect(decoded.statusText, equals('busy'));
    });

    test('decode throws FormatException on out-of-range status', () {
      // Field 1, wire type 0, status value 99.
      final bytes = Uint8List.fromList([0x08, 0x63]);
      expect(() => DialResponse.decode(bytes), throwsFormatException);
    });

    test('decode throws FormatException on truncated statusText', () {
      // Field 2, wire type 2, declared length 8, only 1 byte present.
      final bytes = Uint8List.fromList([0x12, 0x08, 0x61]);
      expect(() => DialResponse.decode(bytes), throwsFormatException);
    });

    test('decode skips a length-delimited unknown field', () {
      // Field 3, wire type 2, length 2 followed by 2 bytes — skipped.
      final bytes = Uint8List.fromList([0x1a, 0x02, 0xaa, 0xbb]);
      final decoded = DialResponse.decode(bytes);
      expect(decoded.status, equals(DialResponseStatus.dialError));
    });

    test('decode throws FormatException when an unknown field length '
        'exceeds bounds', () {
      // Field 3, wire type 2, declared length 10, only 1 byte present.
      final bytes = Uint8List.fromList([0x1a, 0x0a, 0x01]);
      expect(() => DialResponse.decode(bytes), throwsFormatException);
    });

    test('decode throws FormatException on unsupported wire type', () {
      // Field 3, wire type 1 (fixed64) — unsupported.
      final bytes = Uint8List.fromList([0x19, 0x00]);
      expect(() => DialResponse.decode(bytes), throwsFormatException);
    });
  });

  group('AutoNATService', () {
    late _FakeRouter router;
    late AutoNATService service;

    setUp(() {
      router = _FakeRouter();
      service = AutoNATService(router, IPFSConfig(network: NetworkConfig()));
    });

    test('initial status is unknown', () {
      expect(service.natStatus, equals(NATStatus.unknown));
      expect(service.observedAddrs, isEmpty);
    });

    test('updateObservedAddrs stores addresses', () {
      service.updateObservedAddrs(['/ip4/1.2.3.4/tcp/4001']);
      expect(service.observedAddrs, equals(['/ip4/1.2.3.4/tcp/4001']));
    });

    test(
      'performDialback returns unknown with no observed addresses',
      () async {
        final status = await service.performDialback('QmPeer');
        expect(status, equals(NATStatus.unknown));
        expect(router.responseCalls, isEmpty);
      },
    );

    test('performDialback returns unknown on exception', () async {
      service.updateObservedAddrs(['/ip4/1.2.3.4/tcp/4001']);
      router.responseBytes = null; // causes exception
      final status = await service.performDialback('QmPeer');
      expect(status, equals(NATStatus.unknown));
    });

    test('performDialback updates status to public on ok', () async {
      service.updateObservedAddrs(['/ip4/1.2.3.4/tcp/4001']);
      router.responseBytes = DialResponse(
        status: DialResponseStatus.ok,
      ).encode();
      final status = await service.performDialback('QmPeer');
      expect(status, equals(NATStatus.public));
      expect(service.natStatus, equals(NATStatus.public));
      expect(router.responseCalls.length, equals(1));
      expect(router.responseCalls.first.protocolId, equals(autonatProtocolId));
    });

    test('performDialback updates status to private on dialError', () async {
      service.updateObservedAddrs(['/ip4/1.2.3.4/tcp/4001']);
      router.responseBytes = DialResponse(
        status: DialResponseStatus.dialError,
      ).encode();
      final status = await service.performDialback('QmPeer');
      expect(status, equals(NATStatus.private));
      expect(service.natStatus, equals(NATStatus.private));
    });

    test('performDialback leaves status unchanged on dialRefused', () async {
      service.updateObservedAddrs(['/ip4/1.2.3.4/tcp/4001']);
      router.responseBytes = DialResponse(
        status: DialResponseStatus.dialRefused,
      ).encode();
      final status = await service.performDialback('QmPeer');
      expect(status, equals(NATStatus.unknown));
      expect(service.natStatus, equals(NATStatus.unknown));
    });

    test('performDialback is rate limited within one minute', () async {
      service.updateObservedAddrs(['/ip4/1.2.3.4/tcp/4001']);
      router.responseBytes = DialResponse(
        status: DialResponseStatus.ok,
      ).encode();
      await service.performDialback('QmPeer');
      final second = await service.performDialback('QmPeer');
      expect(second, equals(NATStatus.public));
      expect(router.responseCalls.length, equals(1));
    });

    test('resetStatus returns to unknown', () async {
      service.updateObservedAddrs(['/ip4/1.2.3.4/tcp/4001']);
      router.responseBytes = DialResponse(
        status: DialResponseStatus.ok,
      ).encode();
      await service.performDialback('QmPeer');
      service.resetStatus();
      expect(service.natStatus, equals(NATStatus.unknown));
    });
  });

  group('AutoNATServer', () {
    late _FakeRouter router;
    late AutoNATServer server;

    setUp(() {
      router = _FakeRouter();
      server = AutoNATServer(router, IPFSConfig(network: NetworkConfig()));
    });

    test('start and stop register/unregister handler', () {
      server.start();
      expect(router.handlers.containsKey(autonatProtocolId), isTrue);
      server.stop();
      expect(router.handlers.containsKey(autonatProtocolId), isFalse);
    });

    test('handle request with empty addrs returns dialError', () async {
      server.start();
      final handler = router.handlers[autonatProtocolId]!;
      handler(
        NetworkPacket(
          srcPeerId: 'QmPeer',
          datagram: DialRequest(addrs: []).encode(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(router.sentMessages.length, equals(1));
      final response = DialResponse.decode(router.sentMessages.first.message);
      expect(response.status, equals(DialResponseStatus.dialError));
    });

    test('handle successful dialback returns ok', () async {
      server.start();
      final handler = router.handlers[autonatProtocolId]!;
      handler(
        NetworkPacket(
          srcPeerId: 'QmPeer',
          datagram: DialRequest(
            addrs: [
              Uint8List.fromList('/ip4/1.2.3.4/tcp/4001/p2p/QmPeer'.codeUnits),
            ],
          ).encode(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(router.sentMessages.length, equals(1));
      final response = DialResponse.decode(router.sentMessages.first.message);
      expect(response.status, equals(DialResponseStatus.ok));
      expect(router.connectAttempts.length, equals(1));
      expect(router.disconnectAttempts.length, equals(1));
    });

    test('handle failed dialback returns dialError', () async {
      router.connectShouldFail = true;
      server.start();
      final handler = router.handlers[autonatProtocolId]!;
      handler(
        NetworkPacket(
          srcPeerId: 'QmPeer',
          datagram: DialRequest(
            addrs: [
              Uint8List.fromList('/ip4/1.2.3.4/tcp/4001/p2p/QmPeer'.codeUnits),
            ],
          ).encode(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final response = DialResponse.decode(router.sentMessages.first.message);
      expect(response.status, equals(DialResponseStatus.dialError));
    });

    test(
      'refuses dialback to addresses without matching /p2p/ peer id',
      () async {
        server.start();
        final handler = router.handlers[autonatProtocolId]!;
        handler(
          NetworkPacket(
            srcPeerId: 'QmPeer',
            datagram: DialRequest(
              addrs: [
                // No /p2p/ component at all.
                Uint8List.fromList('/ip4/10.0.0.1/tcp/23'.codeUnits),
                // Embeds a *different* peer id (SSRF attempt).
                Uint8List.fromList(
                  '/ip4/10.0.0.2/tcp/4001/p2p/QmOther'.codeUnits,
                ),
              ],
            ).encode(),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(router.connectAttempts, isEmpty);
        expect(router.sentMessages.length, equals(1));
        final response = DialResponse.decode(router.sentMessages.first.message);
        expect(response.status, equals(DialResponseStatus.dialError));
      },
    );

    test('per-peer rate limit refuses repeated dialback requests', () async {
      server.start();
      final handler = router.handlers[autonatProtocolId]!;
      final request = DialRequest(
        addrs: [
          Uint8List.fromList('/ip4/1.2.3.4/tcp/4001/p2p/QmPeer'.codeUnits),
        ],
      ).encode();
      handler(NetworkPacket(srcPeerId: 'QmPeer', datagram: request));
      await Future<void>.delayed(Duration.zero);
      handler(NetworkPacket(srcPeerId: 'QmPeer', datagram: request));
      await Future<void>.delayed(Duration.zero);

      expect(router.sentMessages.length, equals(2));
      final refused = DialResponse.decode(router.sentMessages.last.message);
      expect(refused.status, equals(DialResponseStatus.dialRefused));
      expect(router.connectAttempts.length, equals(1));
    });

    test('rate limits concurrent requests', () async {
      server.start();
      final handler = router.handlers[autonatProtocolId]!;
      // Connect completes asynchronously, so the first 10 requests increment
      // active dial count before the 11th is checked.
      for (var i = 0; i < 11; i++) {
        handler(
          NetworkPacket(
            srcPeerId: 'QmPeer$i',
            datagram: DialRequest(
              addrs: [
                Uint8List.fromList(
                  '/ip4/1.2.3.4/tcp/4001/p2p/QmPeer$i'.codeUnits,
                ),
              ],
            ).encode(),
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      final refused = router.sentMessages
          .where(
            (m) =>
                DialResponse.decode(m.message).status ==
                DialResponseStatus.dialRefused,
          )
          .length;
      expect(refused, equals(1));
    });

    test('handle malformed request returns dialError', () async {
      server.start();
      final handler = router.handlers[autonatProtocolId]!;
      handler(
        NetworkPacket(
          srcPeerId: 'QmPeer',
          datagram: Uint8List.fromList([0xff]),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(router.sentMessages.length, equals(1));
      final response = DialResponse.decode(router.sentMessages.first.message);
      expect(response.status, equals(DialResponseStatus.dialError));
    });

    test('rate-limit map evicts the oldest peer beyond the cap', () async {
      server.start();
      final handler = router.handlers[autonatProtocolId]!;

      // Seed the per-peer rate-limit map to capacity; filling it through
      // the public API would need 1025 sequential dialbacks.
      final library =
          mirrors.reflect(server).type.owner! as mirrors.LibraryMirror;
      final map =
          mirrors
                  .reflect(server)
                  .getField(
                    mirrors.MirrorSystem.getSymbol(
                      '_lastDialbackPerPeer',
                      library,
                    ),
                  )
                  .reflectee
              as Map<String, DateTime>;
      for (var i = 0; i < 1024; i++) {
        map['p$i'] = DateTime.now().subtract(const Duration(minutes: 10));
      }

      handler(
        NetworkPacket(
          srcPeerId: 'QmPeer',
          datagram: DialRequest(
            addrs: [
              Uint8List.fromList('/ip4/1.2.3.4/tcp/4001/p2p/QmPeer'.codeUnits),
            ],
          ).encode(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(map.length, equals(1024));
      expect(map, isNot(contains('p0')));
      expect(router.sentMessages.length, equals(1));
    });

    test('_attemptDialback refuses an address that does not identify the '
        'requesting peer', () async {
      server.start();
      final library =
          mirrors.reflect(server).type.owner! as mirrors.LibraryMirror;

      // The candidate list is filtered before dialing; invoke the defense-
      // in-depth check directly to prove a mismatched /p2p/ never dials.
      final future =
          mirrors.reflect(server).invoke(
                mirrors.MirrorSystem.getSymbol('_attemptDialback', library),
                [
                  'QmPeer',
                  Uint8List.fromList(
                    '/ip4/10.0.0.2/tcp/4001/p2p/QmOther'.codeUnits,
                  ),
                ],
              ).reflectee
              as Future<bool>;

      expect(await future, isFalse);
      expect(router.connectAttempts, isEmpty);
    });
  });
}
