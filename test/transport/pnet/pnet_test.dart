// test/transport/pnet/pnet_test.dart
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/transport/pnet/pnet_transport_conn.dart';
import 'package:dart_ipfs/src/transport/pnet/pnet_transport_wrapper.dart';
import 'package:dart_ipfs/src/transport/pnet/swarm_key_loader.dart';
import 'package:ipfs_libp2p/core/crypto/keys.dart';
import 'package:ipfs_libp2p/core/multiaddr.dart';
import 'package:ipfs_libp2p/core/network/conn.dart' show ConnState, ConnStats;
import 'package:ipfs_libp2p/core/network/context.dart';
import 'package:ipfs_libp2p/core/network/rcmgr.dart' show ConnScope;
import 'package:ipfs_libp2p/core/network/stream.dart' show P2PStream;
import 'package:ipfs_libp2p/core/network/transport_conn.dart';
import 'package:ipfs_libp2p/core/peer/peer_id.dart';
import 'package:ipfs_libp2p/p2p/host/resource_manager/limiter.dart';
import 'package:ipfs_libp2p/p2p/host/resource_manager/resource_manager_impl.dart';
import 'package:ipfs_libp2p/p2p/transport/tcp_transport.dart';
import 'package:test/test.dart';

void main() {
  group('Swarm key loader', () {
    test('decodeV1Psk parses the test swarm key', () {
      const keyText = '/key/swarm/psk/1.0.0/\n/base16/\n'
          '5842d22f5df5b6efd95eb1293e30ef82284654d53d4d4956333ad9437bcabdb4\n';
      final psk = decodeV1Psk(Uint8List.fromList(keyText.codeUnits));

      expect(psk, hasLength(32));
      expect(
        psk,
        equals(
          Uint8List.fromList([
            0x58, 0x42, 0xd2, 0x2f, 0x5d, 0xf5, 0xb6, 0xef,
            0xd9, 0x5e, 0xb1, 0x29, 0x3e, 0x30, 0xef, 0x82,
            0x28, 0x46, 0x54, 0xd5, 0x3d, 0x4d, 0x49, 0x56,
            0x33, 0x3a, 0xd9, 0x43, 0x7b, 0xca, 0xbd, 0xb4,
          ]),
        ),
      );
    });

    test('decodeV1Psk rejects an invalid version marker', () {
      const badKey = '/key/swarm/psk/2.0.0/\n/base16/\n'
          '5842d22f5df5b6efd95eb1293e30ef82284654d53d4d4956333ad9437bcabdb4';
      expect(
        () => decodeV1Psk(Uint8List.fromList(badKey.codeUnits)),
        throwsA(isA<FormatException>()),
      );
    });

    test('decodeV1Psk rejects a wrong-length hex key', () {
      const badKey = '/key/swarm/psk/1.0.0/\n/base16/\n'
          '5842d22f5df5b6efd95eb1293e30ef82284654d53d4d4956333ad9437bcabdb';
      expect(
        () => decodeV1Psk(Uint8List.fromList(badKey.codeUnits)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PNET handshake and cipher state', () {
    test('handshake produces matching keystreams and round-trips data', () async {
      final psk = Uint8List.fromList(List<int>.generate(32, (i) => i));

      final pair = _ConnectedFakeConns();
      final aFuture = PnetTransportConn.create(
        pair.a,
        psk,
        isInitiator: true,
      );
      final bFuture = PnetTransportConn.create(
        pair.b,
        psk,
        isInitiator: false,
      );
      final a = await aFuture;
      final b = await bFuture;

      final messages = [
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.fromList(List<int>.generate(100, (i) => i % 256)),
        Uint8List.fromList(List<int>.generate(137, (i) => (i * 7) % 256)),
        Uint8List.fromList([0xff, 0xfe, 0xfd]),
      ];

      for (final message in messages) {
        await a.write(message);
        final received = await b.read(message.length);
        expect(received, equals(message),
            reason: 'message length ${message.length} did not round-trip');
      }

      await a.close();
      await b.close();
    });

    test('mismatched PSKs fail the handshake or corrupt data', () async {
      final pskA = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final pskB = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

      final pair = _ConnectedFakeConns();
      final aFuture = PnetTransportConn.create(
        pair.a,
        pskA,
        isInitiator: true,
      );
      final bFuture = PnetTransportConn.create(
        pair.b,
        pskB,
        isInitiator: false,
      );
      final a = await aFuture;
      final b = await bFuture;

      // Handshake nonces are exchanged in the clear, so the handshake itself
      // succeeds even with a wrong PSK. The first encrypted payload will be
      // decrypted to garbage.
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);
      await a.write(plaintext);
      final received = await b.read(plaintext.length);
      expect(received, isNot(equals(plaintext)));

      await a.close();
      await b.close();
    });
  });

  group('PNET transport wrapper round-trip over TCP', () {
    test('wrapped TCP transport round-trips data', () async {
      final psk = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final resourceManager = ResourceManagerImpl(limiter: FixedLimiter());
      final inner = TCPTransport(resourceManager: resourceManager);
      final wrapper = PnetTransportWrapper(inner: inner, psk: psk);

      final listenAddr = MultiAddr('/ip4/127.0.0.1/tcp/0');
      final listener = await wrapper.listen(listenAddr);
      final boundAddr = listener.addr;

      final dialConnFuture = wrapper.dial(boundAddr);
      final acceptConn = await listener.accept();
      final dialConn = await dialConnFuture;

      expect(acceptConn, isNotNull);

      final plaintext = Uint8List.fromList(List<int>.generate(200, (i) => i));
      await dialConn.write(plaintext);
      final received = await acceptConn!.read(plaintext.length);
      expect(received, equals(plaintext));

      await dialConn.close();
      await acceptConn.close();
      await listener.close();
      await wrapper.dispose();
    });
  });
}

/// A pair of fake [TransportConn]s wired together so that bytes written to one
/// appear on the other's [read] stream.
class _ConnectedFakeConns {
  _ConnectedFakeConns() {
    final aToB = StreamController<Uint8List>();
    final bToA = StreamController<Uint8List>();

    a = _FakeTransportConn(
      outgoing: aToB.sink,
      incoming: bToA.stream,
    );
    b = _FakeTransportConn(
      outgoing: bToA.sink,
      incoming: aToB.stream,
    );
  }

  late final _FakeTransportConn a;
  late final _FakeTransportConn b;
}

/// Minimal [TransportConn] implementation backed by Dart streams.
class _FakeTransportConn implements TransportConn {
  _FakeTransportConn({
    required this.outgoing,
    required Stream<Uint8List> incoming,
  }) : _incoming = incoming;

  final StreamSink<Uint8List> outgoing;
  final Stream<Uint8List> _incoming;

  final _buffer = BytesBuilder();
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _pendingRead;

  void _ensureSubscribed() {
    _subscription ??= _incoming.listen(
      (chunk) {
        _buffer.add(chunk);
        _completePendingRead();
      },
      onDone: () {
        _completePendingRead();
      },
      onError: (Object e, StackTrace st) {
        _completePendingRead(error: e, stackTrace: st);
      },
    );
  }

  void _completePendingRead({Object? error, StackTrace? stackTrace}) {
    final completer = _pendingRead;
    if (completer == null || completer.isCompleted) return;
    if (error != null) {
      completer.completeError(error, stackTrace);
    } else {
      completer.complete();
    }
  }

  @override
  Future<Uint8List> read([int? length]) async {
    _ensureSubscribed();

    while (true) {
      if (length != null) {
        if (_buffer.length >= length) {
          final bytes = _buffer.toBytes();
          final result = bytes.sublist(0, length);
          _buffer.clear();
          if (bytes.length > length) {
            _buffer.add(bytes.sublist(length));
          }
          return Uint8List.fromList(result);
        }
      } else {
        if (_buffer.isNotEmpty) {
          final result = _buffer.toBytes();
          _buffer.clear();
          return Uint8List.fromList(result);
        }
      }
      _pendingRead = Completer<void>();
      await _pendingRead!.future;
      _pendingRead = null;
    }
  }

  @override
  Future<void> write(Uint8List data) async {
    outgoing.add(Uint8List.fromList(data));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await outgoing.close();
  }

  @override
  Socket get socket => throw UnimplementedError();

  @override
  void setReadTimeout(Duration timeout) {}

  @override
  void setWriteTimeout(Duration timeout) {}

  @override
  void notifyActivity() {}

  @override
  String get id => 'fake';

  @override
  // ignore: strict_raw_type
  Future<P2PStream> newStream(Context context) => throw UnimplementedError();

  @override
  // ignore: strict_raw_type
  Future<List<P2PStream>> get streams => Future.value([]);

  @override
  bool get isClosed => false;

  @override
  PeerId get localPeer => throw UnimplementedError();

  @override
  PeerId get remotePeer => throw UnimplementedError();

  @override
  Future<PublicKey?> get remotePublicKey => Future.value(null);

  @override
  ConnState get state => const ConnState(
        streamMultiplexer: '',
        security: '',
        transport: 'fake',
        usedEarlyMuxerNegotiation: false,
      );

  @override
  MultiAddr get localMultiaddr => MultiAddr('/ip4/127.0.0.1/tcp/0');

  @override
  MultiAddr get remoteMultiaddr => MultiAddr('/ip4/127.0.0.1/tcp/0');

  @override
  ConnStats get stat => throw UnimplementedError();

  @override
  ConnScope get scope => throw UnimplementedError();
}
