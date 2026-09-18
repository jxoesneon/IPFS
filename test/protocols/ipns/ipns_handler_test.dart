// test/protocols/ipns/ipns_handler_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/dht/common_red_black_tree.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/interface_dht_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_handler.dart';
import 'package:dart_ipfs/src/protocols/ipns/ipns_record.dart';
import 'package:test/test.dart';

/// Minimal [IDHTHandler] that serves a fixed value for every key.
class _StubDHTHandler implements IDHTHandler {
  _StubDHTHandler(this._value);

  final Value _value;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> provideAll(List<CID> cids) async {}

  @override
  Future<Value> getValue(Key key) async => _value;

  @override
  Future<List<V_PeerInfo>> findPeer(PeerId id) async => [];

  @override
  Future<void> provide(CID cid) async {}

  @override
  Future<List<V_PeerInfo>> findProviders(CID cid) async => [];

  @override
  Future<void> putValue(Key key, Value value) async {}

  @override
  Future<void> handleRoutingTableUpdate(V_PeerInfo peer) async {}

  @override
  Future<void> handleProvideRequest(CID cid, PeerId provider) async {}
}

void main() {
  group('IPNSRecord', () {
    late SimpleKeyPair keyPair;
    late CID testCID;

    setUpAll(() async {
      // Generate a test Ed25519 key pair
      final algorithm = Ed25519();
      keyPair = await algorithm.newKeyPair();

      // Create a test CID
      final block = await Block.fromData(
        Uint8List.fromList(utf8.encode('test content')),
      );
      testCID = block.cid;
    });

    test('create generates a signed record', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 1,
      );

      expect(record.isSigned, isTrue);
      expect(record.sequence, equals(1));
      expect(record.publicKey, isNotEmpty);
    });

    test('verify returns true for valid signed record', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 2,
      );

      final isValid = await record.verify();
      expect(isValid, isTrue);
    });

    test('verify returns false for expired record', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 3,
        validity: const Duration(milliseconds: 1), // Expires almost immediately
      );

      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 10));

      final isValid = await record.verify();
      expect(isValid, isFalse);
    });

    test('toCBOR serializes correctly', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 4,
      );

      final cbor = record.toCBOR();
      expect(cbor, isNotEmpty);
    });

    test('fromCBOR deserializes correctly', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 5,
      );

      final cbor = record.toCBOR();
      final restored = IPNSRecord.fromCBOR(cbor);

      expect(restored.sequence, equals(5));
      expect(restored.publicKey, equals(record.publicKey));
      expect(restored.isSigned, isTrue);
    });

    test('roundtrip preserves data and signature validity', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 6,
      );

      final cbor = record.toCBOR();
      final restored = IPNSRecord.fromCBOR(cbor);

      final isValid = await restored.verify();
      expect(isValid, isTrue);
    });

    test('valueCID parses CID from value', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 7,
      );

      final parsedCID = record.valueCID;
      expect(parsedCID, isNotNull);
      expect(parsedCID!.encode(), equals(testCID.encode()));
    });

    test('toString provides readable output', () async {
      final record = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 8,
      );

      final str = record.toString();
      expect(str, contains('IPNSRecord'));
      expect(str, contains('seq: 8'));
      expect(str, contains('signed: true'));
    });

    test('sequence numbers can be incremented', () async {
      final record1 = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 10,
      );

      final record2 = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 11,
      );

      expect(record2.sequence, greaterThan(record1.sequence));
    });

    test('different key pairs produce different signatures', () async {
      final algorithm = Ed25519();
      final otherKeyPair = await algorithm.newKeyPair();

      final record1 = await IPNSRecord.create(
        value: testCID,
        keyPair: keyPair,
        sequence: 12,
      );

      final record2 = await IPNSRecord.create(
        value: testCID,
        keyPair: otherKeyPair,
        sequence: 12,
      );

      expect(record1.signature, isNot(equals(record2.signature)));
      expect(record1.publicKey, isNot(equals(record2.publicKey)));
    });

    test('fromCBOR throws on invalid data', () {
      final invalidData = Uint8List.fromList([1, 2, 3]);
      expect(() => IPNSRecord.fromCBOR(invalidData), throwsFormatException);
    });
  });

  group('IPNSHandler.resolve', () {
    test('rejects DHT bytes that are not a valid IPNS record', () async {
      final garbage = Uint8List.fromList(
        utf8.encode('definitely not an ipns record'),
      );
      final dht = _StubDHTHandler(Value(garbage));
      final handler = IPNSHandler(IPFSConfig(offline: true), null, dht);
      await handler.start();

      final keyPair = await Ed25519().newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final name = deriveIpnsName(Uint8List.fromList(pub.bytes));

      await expectLater(
        handler.resolve(name),
        throwsA(isA<IpnsValidationError>()),
      );

      await handler.stop();
    });
  });
}
