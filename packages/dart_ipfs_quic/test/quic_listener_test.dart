import 'dart:async';

import 'package:ipfs_libp2p/core/multiaddr.dart' as libp2p;
import 'package:quic_lib/libp2p.dart' as quic_lib;
import 'package:test/test.dart';

import 'package:dart_ipfs_quic/src/quic_listener.dart';

void main() {
  group('QuicListener', () {
    late StreamController<quic_lib.Libp2pQuicConnection> controller;
    late QuicListener listener;
    final addr = libp2p.MultiAddr('/ip4/127.0.0.1/udp/4001/quic-v1');
    final localAddr = libp2p.MultiAddr('/ip4/127.0.0.1/udp/4002/quic-v1');

    setUp(() {
      controller = StreamController<quic_lib.Libp2pQuicConnection>.broadcast();
      listener = QuicListener(
        stream: controller.stream,
        addr: addr,
        localAddr: localAddr,
      );
    });

    tearDown(() async {
      await listener.close();
      if (!controller.isClosed) await controller.close();
    });

    test('exposes addr and connectionStream', () {
      expect(listener.addr, equals(addr));
      expect(listener.connectionStream, isNotNull);
      expect(listener.isClosed, isFalse);
    });

    test('accept returns a connection from pending', () async {
      final fakeConn = quic_lib.Libp2pQuicConnection('fake');
      controller.add(fakeConn);
      await Future.delayed(Duration.zero);

      final accepted = await listener.accept();
      expect(accepted, isNotNull);
    });

    test('accept waits for the first connection when pending is empty',
        () async {
      final fakeConn = quic_lib.Libp2pQuicConnection('fake');
      final acceptFuture = listener.accept();
      controller.add(fakeConn);

      final accepted = await acceptFuture;
      expect(accepted, isNotNull);
    });

    test('accept returns null when closed', () async {
      await listener.close();
      final accepted = await listener.accept();
      expect(accepted, isNull);
    });

    test('accept returns null when stream is done', () async {
      await controller.close();
      final accepted = await listener.accept();
      expect(accepted, isNull);
    });

    test('supportsAddr recognizes QUIC multiaddrs', () {
      expect(
        listener.supportsAddr(
          libp2p.MultiAddr('/ip4/127.0.0.1/udp/4001/quic-v1'),
        ),
        isTrue,
      );
      expect(
        listener.supportsAddr(
          libp2p.MultiAddr('/ip4/127.0.0.1/tcp/4001'),
        ),
        isFalse,
      );
      expect(
        listener.supportsAddr(
          libp2p.MultiAddr('/ip4/127.0.0.1/udp/4001'),
        ),
        isFalse,
      );
    });

    test('close is idempotent', () async {
      await listener.close();
      await listener.close();
      expect(listener.isClosed, isTrue);
    });

    test('forwards stream errors to connectionStream', () async {
      final errors = <Object>[];
      listener.connectionStream.listen(
        (_) {},
        onError: (Object e) => errors.add(e),
      );
      controller.addError(Exception('test error'));
      await Future.delayed(Duration.zero);
      expect(errors, hasLength(1));
    });

    test('closes connectionStream when underlying stream is done', () async {
      final done = <bool>[];
      listener.connectionStream.listen(
        (_) {},
        onDone: () => done.add(true),
      );
      await controller.close();
      await Future.delayed(Duration.zero);
      expect(done, isNotEmpty);
    });
  });
}
