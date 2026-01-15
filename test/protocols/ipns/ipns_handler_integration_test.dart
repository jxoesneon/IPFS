import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/security/security_manager_interface.dart';
import 'package:dart_ipfs/src/proto/generated/dht/dht.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_interface.dart';
import 'package:test/test.dart';

class MockSecurityManager implements ISecurityManager {
  bool keystoreUnlocked = false;

  @override
  bool get isKeystoreUnlocked => keystoreUnlocked;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDHTHandler implements IDHTHandler {
  bool started = false;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<Value> getValue(Key key) async {
    return Value(
      Uint8List.fromList([18, 32, ...List.filled(32, 0)]),
    ); // Fake CID bytes
  }

  @override
  Future<void> putValue(Key key, Value value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPubSub implements IPubSub {
  List<String> subscribedTopics = [];
  List<String> publishedTopics = [];

  @override
  Future<void> subscribe(String topic) async {
    subscribedTopics.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    subscribedTopics.remove(topic);
  }

  @override
  Future<void> publish(String topic, String message) async {
    publishedTopics.add(topic);
  }

  @override
  void onMessage(String topic, void Function(String) handler) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IPNSHandler', () {
    late IPFSConfig config;
    late MockSecurityManager mockSecurity;
    late MockDHTHandler mockDHT;
    late MockPubSub mockPubSub;
    late IPNSHandler handler;

    setUp(() {
      config = IPFSConfig(offline: true);
      mockSecurity = MockSecurityManager();
      mockDHT = MockDHTHandler();
      mockPubSub = MockPubSub();
      handler = IPNSHandler(config, mockSecurity, mockDHT, mockPubSub);
    });

    group('start/stop lifecycle', () {
      test('start initializes handler and starts DHT', () async {
        await handler.start();
        expect(mockDHT.started, isTrue);
        expect(
          mockPubSub.subscribedTopics.contains('/ipfs/ipns-1.0.0'),
          isTrue,
        );
      });

      test('start is idempotent', () async {
        await handler.start();
        await handler.start(); // Should not throw
        expect(mockDHT.started, isTrue);
      });

      test('stop clears cache and unsubscribes', () async {
        await handler.start();
        await handler.stop();
        expect(
          mockPubSub.subscribedTopics.contains('/ipfs/ipns-1.0.0'),
          isFalse,
        );
      });

      test('stop is idempotent', () async {
        await handler.stop();
        await handler.stop(); // Should not throw
      });
    });

    group('getStatus', () {
      test('returns running state', () async {
        var status = await handler.getStatus();
        expect(status['running'], isFalse);

        await handler.start();
        status = await handler.getStatus();
        expect(status['running'], isTrue);
      });

      test('returns cache info', () async {
        final status = await handler.getStatus();
        expect(status['cache_size'], isNotNull);
        expect(status['cache_duration_minutes'], equals(30));
      });
    });

    group('resolve', () {
      test('resolves IPNS name to CID', () async {
        await handler.start();
        final result = await handler.resolve('test-name');
        // MockDHTHandler returns a fake CID, so result should be non-null
        expect(result, isNotNull);
      });

      test('subscribes to topic when resolving with PubSub', () async {
        await handler.start();
        await handler.resolve('12D3KooWNxnY1oMhGCX');
        // Should have subscribed to key-specific topic
        expect(mockPubSub.subscribedTopics.length, greaterThanOrEqualTo(2));
      });
    });

    group('publish validation', () {
      test('publish throws for invalid CID format', () async {
        await handler.start();
        // Temporarily suppress logs if possible, or accept the log.
        // The test passes, so we just ensure it's clean.
        expect(
          () => handler.publish('invalid!cid', keyName: 'test'),
          throwsArgumentError,
        );
      });

      test('publish throws when keystore is locked', () async {
        await handler.start();
        mockSecurity.keystoreUnlocked = false;
        expect(
          () => handler.publish('QmTestCID123', keyName: 'mykey'),
          throwsStateError,
        );
      });
    });

    group('without PubSub', () {
      test('handler works without PubSub', () async {
        final offlineHandler = IPNSHandler(config, mockSecurity, mockDHT, null);
        await offlineHandler.start();
        await offlineHandler.stop();
      });

      test('resolve works without PubSub', () async {
        final offlineHandler = IPNSHandler(config, mockSecurity, mockDHT, null);
        await offlineHandler.start();
        final result = await offlineHandler.resolve('test-name');
        expect(result, isNotNull);
        await offlineHandler.stop();
      });
    });

    group('createRecord (deprecated)', () {
      test('creates an unsigned Record', () async {
        final cid = CID.decode(
          'QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z',
        );
        final keyBytes = Uint8List.fromList([1, 2, 3, 4]);
        final record = await handler.createRecord(cid, keyBytes);

        expect(record.key, equals(keyBytes));
        expect(record.value, isNotEmpty);
        expect(record.sequence.toInt(), greaterThan(0));
      });
    });

    group('publishRecord validation', () {
      test('throws StateError on unsigned record', () async {
        // Create unsigned record via CBOR (no signature field)
        final cborBytes = _createUnsignedRecordCBOR();
        final unsignedRecord = IPNSRecord.fromCBOR(cborBytes);

        expect(() => handler.publishRecord(unsignedRecord), throwsStateError);
      });
    });

    group('resolve caching', () {
      test('caches resolution and returns cached value', () async {
        await handler.start();

        // First resolve
        final result1 = await handler.resolve('cached-name');
        expect(result1, isNotNull);

        // Second resolve should return cached value
        final result2 = await handler.resolve('cached-name');
        expect(result2, equals(result1));

        await handler.stop();
      });
    });
  });
}

/// Helper function to create unsigned IPNS record CBOR
Uint8List _createUnsignedRecordCBOR() {
  // Manually create CBOR without signature
  // Simple approach: just return enough bytes to parse
  final value = utf8.encode('/ipfs/QmTest');
  final validity = utf8.encode(
    DateTime.now().add(Duration(hours: 1)).toUtc().toIso8601String(),
  );
  final publicKey = Uint8List(32); // Empty public key

  // Use cbor package
  final cborValue = CborMap({
    CborString('Value'): CborBytes(value),
    CborString('Validity'): CborBytes(validity),
    CborString('ValidityType'): const CborSmallInt(0),
    CborString('Sequence'): const CborSmallInt(1),
    CborString('TTL'): const CborSmallInt(3600000000),
    CborString('PublicKey'): CborBytes(publicKey),
    // No Signature field = unsigned
  });

  return Uint8List.fromList(cbor.encode(cborValue));
}
