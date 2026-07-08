import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/crypto/ed25519_signer.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:test/test.dart';

class FakeDHTHandler implements IDHTHandler {
  final Map<String, Uint8List> _values = {};
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
  Future<void> putValue(Key key, Value value) async {
    _values[key.toString()] = Uint8List.fromList(value.bytes);
  }

  @override
  Future<Value> getValue(Key key) async {
    final bytes = _values[key.toString()];
    if (bytes == null) {
      throw Exception('Value not found for key ${key.toString()}');
    }
    return Value(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<SimpleKeyPair> _testKeyPair() async {
  final signer = Ed25519Signer();
  return signer.generateKeyPair(
    seed: Uint8List.fromList(List.generate(32, (i) => i)),
  );
}

Future<String> _testIpnsName(SimpleKeyPair keyPair) async {
  final publicKey = await keyPair.extractPublicKey();
  return deriveIpnsName(Uint8List.fromList(publicKey.bytes));
}

void main() {
  group('IPNS name derivation', () {
    test('deriveIpnsName produces a base36 multibase string', () async {
      final keyPair = await _testKeyPair();
      final name = await _testIpnsName(keyPair);
      expect(name, startsWith('k'));
      expect(name.length, greaterThan(1));
      expect(() => PeerId.fromBase36(name), returnsNormally);
    });

    test('PeerId roundtrip from base36', () async {
      final keyPair = await _testKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final peerId = PeerId.fromPublicKey(
        Uint8List.fromList(publicKey.bytes),
        type: 'Ed25519',
      );
      final name = peerId.toBase36();
      final decoded = PeerId.fromBase36(name);
      expect(decoded, equals(peerId));
    });
  });

  group('IPNSRecord', () {
    test('create signs a record that verifies', () async {
      final keyPair = await _testKeyPair();
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

      final record = await IPNSRecord.create(
        value: cid,
        keyPair: keyPair,
        sequence: 1,
      );

      expect(record.isSigned, isTrue);
      expect(record.valueCID, equals(cid));
      expect(await record.verify(), isTrue);
    });

    test('toCBOR / fromCBOR roundtrip preserves fields', () async {
      final keyPair = await _testKeyPair();
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');

      final record = await IPNSRecord.create(
        value: cid,
        keyPair: keyPair,
        sequence: 42,
        validity: const Duration(hours: 12),
        ttl: const Duration(minutes: 30),
      );

      final bytes = record.toCBOR();
      final decoded = IPNSRecord.fromCBOR(bytes);

      expect(decoded.value, equals(record.value));
      expect(decoded.sequence, equals(record.sequence));
      expect(decoded.ttl, equals(record.ttl));
      expect(decoded.publicKey, equals(record.publicKey));
      expect(decoded.signature, equals(record.signature));
      expect(await decoded.verify(), isTrue);
    });

    test('verify fails for a tampered record', () async {
      final keyPair = await _testKeyPair();
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

      final record = await IPNSRecord.create(
        value: cid,
        keyPair: keyPair,
        sequence: 1,
      );

      // Tamper with the value by rebuilding the record internals manually.
      final tampered = IPNSRecord.internal(
        value: Uint8List.fromList(utf8.encode('/ipfs/QmTampered')),
        validity: record.validity,
        sequence: record.sequence,
        ttl: record.ttl,
        publicKey: record.publicKey,
        signature: record.signature,
      );

      expect(await tampered.verify(), isFalse);
    });
  });

  group('IPNSHandler', () {
    late IPFSConfig config;
    late FakeDHTHandler dht;
    late IPNSHandler handler;
    late SimpleKeyPair keyPair;

    setUp(() async {
      config = IPFSConfig(offline: true);
      dht = FakeDHTHandler();
      handler = IPNSHandler(config, null, dht, null);
      keyPair = await _testKeyPair();
      await handler.start();
    });

    tearDown(() async {
      await handler.stop();
    });

    test('publishWithKeyPair stores a signed record to the DHT', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final name = await _testIpnsName(keyPair);

      await handler.publishWithKeyPair(cid, keyPair, sequence: 1);

      final key = Key.fromString('/ipns/$name');
      final stored = await dht.getValue(key);
      expect(stored.bytes, isNotEmpty);

      final record = IPNSRecord.fromCBOR(stored.bytes);
      expect(record.valueCID, equals(cid));
      expect(record.name, equals(name));
      expect(await record.verify(), isTrue);
    });

    test('resolve returns the CID from a signed record', () async {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final name = await _testIpnsName(keyPair);

      await handler.publishWithKeyPair(cid, keyPair, sequence: 1);

      final resolved = await handler.resolve(name);
      expect(resolved, equals(cid.encode()));
    });

    test('getRecordBytes returns the signed CBOR record', () async {
      final cid = CID.decode('QmYwAPJzv5CZsnA6ULBXebJWvruP6P3wXhHjS2Mtc38E2z');
      final name = await _testIpnsName(keyPair);

      await handler.publishWithKeyPair(cid, keyPair, sequence: 1);

      final bytes = await handler.getRecordBytes(name);
      expect(bytes, isNotNull);
      expect(bytes, isNotEmpty);

      final record = IPNSRecord.fromCBOR(bytes!);
      expect(await record.verify(), isTrue);
    });

    test('resolve throws when no record is found', () async {
      final name = await _testIpnsName(keyPair);
      expect(() => handler.resolve(name), throwsA(isA<IpnsResolutionError>()));
    });

    test('resolve rejects an unsigned record', () async {
      final name = await _testIpnsName(keyPair);
      final publicKey = await keyPair.extractPublicKey();
      final unsignedRecord = IPNSRecord.internal(
        value: Uint8List.fromList(
          utf8.encode('/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        ),
        validity: DateTime.now().add(const Duration(hours: 24)).toUtc(),
        sequence: 1,
        ttl: const Duration(hours: 1),
        publicKey: Uint8List.fromList(publicKey.bytes),
      );

      await dht.putValue(
        Key.fromString('/ipns/$name'),
        Value(unsignedRecord.toCBOR()),
      );

      expect(() => handler.resolve(name), throwsA(isA<IpnsValidationError>()));
    });

    test('resolve rejects an expired record', () async {
      final name = await _testIpnsName(keyPair);
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

      final record = await IPNSRecord.create(
        value: cid,
        keyPair: keyPair,
        sequence: 1,
        validity: const Duration(seconds: -1),
      );

      await dht.putValue(Key.fromString('/ipns/$name'), Value(record.toCBOR()));

      expect(() => handler.resolve(name), throwsA(isA<IpnsValidationError>()));
    });

    test('resolve rejects a name/public key mismatch', () async {
      final name = await _testIpnsName(keyPair);
      final otherKeyPair = await Ed25519().newKeyPair();
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');

      final record = await IPNSRecord.create(
        value: cid,
        keyPair: otherKeyPair,
        sequence: 1,
      );

      await dht.putValue(Key.fromString('/ipns/$name'), Value(record.toCBOR()));

      expect(() => handler.resolve(name), throwsA(isA<IpnsValidationError>()));
    });

    test('publishRecord stores a pre-constructed signed record', () async {
      final cid = CID.decode('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn');
      final name = await _testIpnsName(keyPair);
      final record = await IPNSRecord.create(
        value: cid,
        keyPair: keyPair,
        sequence: 5,
      );

      await handler.publishRecord(record);

      final resolved = await handler.resolve(name);
      expect(resolved, equals(cid.encode()));
    });

    test('publishRecord throws for an unsigned record', () async {
      final publicKey = await keyPair.extractPublicKey();
      final unsignedRecord = IPNSRecord.internal(
        value: Uint8List.fromList(
          utf8.encode('/ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
        ),
        validity: DateTime.now().add(const Duration(hours: 24)).toUtc(),
        sequence: 1,
        ttl: const Duration(hours: 1),
        publicKey: Uint8List.fromList(publicKey.bytes),
      );

      expect(
        () => handler.publishRecord(unsignedRecord),
        throwsA(isA<StateError>()),
      );
    });
  });
}
