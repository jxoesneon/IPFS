// test/protocols/dht/dht_protocol_handler_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SimpleKeyPair;
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart' as dht_pb;
import 'package:dart_ipfs/src/proto/generated/dht/kademlia.pb.dart' as kad;
import 'package:dart_ipfs/src/protocols/dht/dht_protocol_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_routing_table_interface.dart';
import 'package:dart_ipfs/src/protocols/dht/rate_limiter.dart';
import 'package:dart_ipfs/src/transport/router_events.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

class _FakeRouter implements RouterInterface {
  final _sent = <(String, Uint8List)>[];
  final _handlers = <String, void Function(NetworkPacket)>{};

  @override
  String get peerID => 'localPeer';

  @override
  bool get hasStarted => true;

  @override
  bool get isInitialized => true;

  @override
  Set<String> get connectedPeers => {};

  @override
  Set<String> get supportedProtocols => const {};

  @override
  Stream<ConnectionEvent> get connectionEvents => const Stream.empty();

  @override
  Stream<MessageEvent> get messageEvents => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> connect(String multiaddress) async {}

  @override
  Future<void> disconnect(String peerIdOrMultiaddress) async {}

  @override
  List<String> get listeningAddresses => [];

  @override
  List<String> listConnectedPeers() => [];

  @override
  bool isConnectedPeer(String peerIdStr) => false;

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    _sent.add((peerIdStr, message));
  }

  @override
  Future<Uint8List?> sendRequest(
    String peerId,
    String protocolId,
    Uint8List request,
  ) async => null;

  @override
  Stream<Uint8List> receiveMessages(String peerId) => const Stream.empty();

  @override
  void registerProtocolHandler(
    String protocolId,
    void Function(NetworkPacket) handler,
  ) {
    _handlers[protocolId] = handler;
  }

  @override
  void unregisterProtocolHandler(String protocolId) {
    _handlers.remove(protocolId);
  }

  @override
  void removeMessageHandler(String protocolId) => _handlers.remove(protocolId);

  @override
  Future<Uint8List> sendMessageWithResponse(
    String peerId,
    Uint8List message, {
    String? protocolId,
    Duration? timeout,
  }) async => Uint8List(0);

  @override
  void registerProtocol(String protocolId) {}

  @override
  DHTRoutingTable? get dhtRoutingTable => null;

  @override
  Future<void> broadcastMessage(String protocolId, Uint8List message) async {}

  @override
  void emitEvent(String topic, Uint8List data) {}

  @override
  void onEvent(String topic, void Function(dynamic) handler) {}

  @override
  void offEvent(String topic, void Function(dynamic) handler) {}

  @override
  Object? parseMultiaddr(String multiaddr) => null;

  @override
  List<String> resolvePeerId(String peerIdStr) => [];

  @override
  void registerRelayedConnection(String targetPeerId, String relayAddr) {}

  List<(String, Uint8List)> takeSent() {
    final result = List<(String, Uint8List)>.from(_sent);
    _sent.clear();
    return result;
  }
}

class _FakeDatastore implements Datastore {
  final _values = <Key, Uint8List>{};

  @override
  Future<void> init() async {}

  @override
  Future<Uint8List?> get(Key key) async => _values[key];

  @override
  Future<void> put(Key key, Uint8List value) async {
    _values[key] = value;
  }

  @override
  Future<bool> has(Key key) async => _values.containsKey(key);

  @override
  Future<void> delete(Key key) async {
    _values.remove(key);
  }

  @override
  Stream<QueryEntry> query(Query q) async* {
    for (final entry in _values.entries) {
      if (q.prefix == null || entry.key.toString().startsWith(q.prefix!)) {
        yield QueryEntry(entry.key, entry.value);
      }
    }
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DHTProtocolHandler', () {
    late _FakeRouter router;
    late _FakeDatastore datastore;

    setUp(() {
      router = _FakeRouter();
      datastore = _FakeDatastore();
    });

    test('responds to PING with PING', () async {
      DHTProtocolHandler(router, datastore);
      final handler = router._handlers[DHTProtocolHandler.protocolId];
      expect(handler, isNotNull);

      final request = kad.Message()
        ..type = kad.Message_MessageType.PING
        ..key = Uint8List.fromList([1, 2, 3]);
      final packet = NetworkPacket(
        srcPeerId: 'peer1',
        datagram: request.writeToBuffer(),
      );
      handler!(packet);

      // Give the async handler a moment to complete.
      await Future.delayed(const Duration(milliseconds: 50));

      final sent = router.takeSent();
      expect(sent.length, equals(1));
      final (_, bytes) = sent.first;
      final response = kad.Message.fromBuffer(bytes);
      expect(response.type, equals(kad.Message_MessageType.PING));
    });

    test('rate limiter drops messages when queue is full', () async {
      final rateLimiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 10),
        maxQueueSize: 0,
      );
      // Hold the single permit so subsequent messages are dropped.
      await rateLimiter.acquire();

      DHTProtocolHandler(router, datastore, rateLimiter: rateLimiter);
      final handler = router._handlers[DHTProtocolHandler.protocolId]!;

      final request = kad.Message()..type = kad.Message_MessageType.PING;
      final packet = NetworkPacket(
        srcPeerId: 'peer2',
        datagram: request.writeToBuffer(),
      );
      handler(packet);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(router.takeSent(), isEmpty);

      rateLimiter.release();
    });

    test('rate limiter releases permit after handling', () async {
      final rateLimiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 10),
        maxQueueSize: 1,
      );

      DHTProtocolHandler(router, datastore, rateLimiter: rateLimiter);
      final handler = router._handlers[DHTProtocolHandler.protocolId]!;

      final request = kad.Message()..type = kad.Message_MessageType.PING;
      final packet = NetworkPacket(
        srcPeerId: 'peer3',
        datagram: request.writeToBuffer(),
      );
      handler(packet);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(router.takeSent().length, equals(1));
      expect(rateLimiter.queueLength, equals(0));
    });
  });

  group('PUT_VALUE validation', () {
    late _FakeRouter router;
    late _FakeDatastore datastore;

    setUp(() {
      router = _FakeRouter();
      datastore = _FakeDatastore();
    });

    kad.Message putValueMessage(String key, List<int> value) {
      return kad.Message()
        ..type = kad.Message_MessageType.PUT_VALUE
        ..key = utf8.encode(key)
        ..record = (dht_pb.Record()..value = Uint8List.fromList(value));
    }

    Future<kad.Message> drive(kad.Message request) async {
      DHTProtocolHandler(router, datastore);
      final handler = router._handlers[DHTProtocolHandler.protocolId]!;
      handler(
        NetworkPacket(srcPeerId: 'peerPut', datagram: request.writeToBuffer()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final sent = router.takeSent();
      expect(sent, hasLength(1));
      return kad.Message.fromBuffer(sent.first.$2);
    }

    test('rejects keys outside the /ipns/ namespace', () async {
      final response = await drive(putValueMessage('/dht/foo', [1, 2, 3]));

      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
      expect(datastore._values, isEmpty);
    });

    test('rejects empty values', () async {
      final response = await drive(putValueMessage('/ipns/QmKey', []));

      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
      expect(datastore._values, isEmpty);
    });

    test('rejects values exceeding the 1 MiB cap', () async {
      final oversized = Uint8List(1024 * 1024 + 1);
      final response = await drive(putValueMessage('/ipns/QmKey', oversized));

      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
      expect(datastore._values, isEmpty);
    });

    test('rejects undecodable values under an /ipns/ key', () async {
      final kp = await _keyPair(1);
      final dhtKey = ipnsDhtKey(await _publicKeyBytes(kp));

      final response = await drive(
        putValueMessage(utf8.decode(dhtKey, allowMalformed: true), [1, 2, 3]),
      );

      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
      expect(datastore._values, isEmpty);
    });

    test('stores a valid signed /ipns/ record under its DHT key', () async {
      final kp = await _keyPair(1);
      final dhtKey = ipnsDhtKey(await _publicKeyBytes(kp));
      final record = await IPNSRecord.create(
        value: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        keyPair: kp,
        sequence: 5,
      );
      final value = record.toIpnsEntry();

      final request = kad.Message()
        ..type = kad.Message_MessageType.PUT_VALUE
        ..key = dhtKey
        ..record = (dht_pb.Record()..value = value);
      final response = await drive(request);

      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
      final keyStr = utf8.decode(dhtKey, allowMalformed: true);
      final storedKey = Key('/dht/values/$keyStr');
      expect(datastore._values[storedKey], equals(value));
    });

    test('rejects a valid record stored under the wrong /ipns/ key', () async {
      final kp = await _keyPair(1);
      final otherKp = await _keyPair(2);
      final wrongKey = ipnsDhtKey(await _publicKeyBytes(otherKp));
      final record = await IPNSRecord.create(
        value: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        keyPair: kp,
        sequence: 5,
      );

      final request = kad.Message()
        ..type = kad.Message_MessageType.PUT_VALUE
        ..key = wrongKey
        ..record = (dht_pb.Record()..value = record.toIpnsEntry());
      final response = await drive(request);

      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
      expect(datastore._values, isEmpty);
    });

    test('rejects a record whose sequence does not advance', () async {
      final kp = await _keyPair(1);
      final pubKey = await _publicKeyBytes(kp);
      final dhtKey = ipnsDhtKey(pubKey);
      final keyStr = utf8.decode(dhtKey, allowMalformed: true);

      // A newer record (seq 10) is already stored.
      final newer = await IPNSRecord.create(
        value: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        keyPair: kp,
        sequence: 10,
      );
      datastore._values[Key('/dht/values/$keyStr')] = newer.toIpnsEntry();

      final stale = await IPNSRecord.create(
        value: CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        keyPair: kp,
        sequence: 5,
      );
      final request = kad.Message()
        ..type = kad.Message_MessageType.PUT_VALUE
        ..key = dhtKey
        ..record = (dht_pb.Record()..value = stale.toIpnsEntry());
      final response = await drive(request);

      expect(response.type, equals(kad.Message_MessageType.PUT_VALUE));
      // Stored record remains the newer one.
      expect(
        datastore._values[Key('/dht/values/$keyStr')],
        equals(newer.toIpnsEntry()),
      );
    });
  });
}

Future<SimpleKeyPair> _keyPair(int seed) => Ed25519Signer().generateKeyPair(
  seed: Uint8List.fromList(List.filled(32, seed)),
);

Future<Uint8List> _publicKeyBytes(SimpleKeyPair kp) async =>
    Uint8List.fromList((await kp.extractPublicKey()).bytes);
