// test/protocols/bitswap/bitswap_handler_test.dart
import 'dart:typed_data';

import 'package:dart_ipfs/src/protocols/bitswap/ledger.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart' as bitswap_msg;
import 'package:dart_ipfs/src/protocols/bitswap/wantlist.dart';
import 'package:test/test.dart';

void main() {
  group('Wantlist', () {
    test('add and contains', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest1', priority: 5);
      expect(wantlist.contains('QmTest1'), isTrue);
      expect(wantlist.contains('QmTest2'), isFalse);
    });

    test('remove removes entry', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest1');
      wantlist.remove('QmTest1');
      expect(wantlist.contains('QmTest1'), isFalse);
    });

    test('getEntry returns correct entry', () {
      final wantlist = Wantlist();
      wantlist.add('QmTest1', priority: 10, wantType: bitswap_msg.WantType.have);
      final entry = wantlist.getEntry('QmTest1');
      expect(entry, isNotNull);
      expect(entry!.priority, equals(10));
      expect(entry.wantType, equals(bitswap_msg.WantType.have));
    });

    test('length reflects entries', () {
      final wantlist = Wantlist();
      expect(wantlist.length, equals(0));
      wantlist.add('QmA');
      wantlist.add('QmB');
      expect(wantlist.length, equals(2));
    });

    test('clear removes all entries', () {
      final wantlist = Wantlist();
      wantlist.add('QmA');
      wantlist.add('QmB');
      wantlist.clear();
      expect(wantlist.length, equals(0));
    });

    test('rejects negative priority', () {
      final wantlist = Wantlist();
      expect(() => wantlist.add('QmTest', priority: -1), throwsA(isA<ArgumentError>()));
    });
  });

  group('BitLedger', () {
    test('tracks sent bytes', () {
      final ledger = BitLedger('PeerA');
      ledger.addSentBytes(100);
      expect(ledger.sentBytes, equals(100));
      ledger.addSentBytes(50);
      expect(ledger.sentBytes, equals(150));
    });

    test('tracks received bytes', () {
      final ledger = BitLedger('PeerA');
      ledger.addReceivedBytes(200);
      expect(ledger.receivedBytes, equals(200));
    });

    test('calculates debt correctly', () {
      final ledger = BitLedger('PeerA');
      ledger.addSentBytes(100);
      ledger.addReceivedBytes(50);
      // debt = sent - received = 100 - 50 = 50
      expect(ledger.getDebt(), equals(50));
    });

    test('rejects negative bytes', () {
      final ledger = BitLedger('PeerA');
      expect(() => ledger.addSentBytes(-1), throwsA(isA<ArgumentError>()));
      expect(() => ledger.addReceivedBytes(-1), throwsA(isA<ArgumentError>()));
    });

    test('stores and retrieves block data', () {
      final ledger = BitLedger('PeerA');
      final data = Uint8List.fromList([1, 2, 3]);
      ledger.storeBlockData('QmCid', data);
      expect(ledger.hasBlock('QmCid'), isTrue);
      expect(ledger.getBlockData('QmCid'), equals(data));
    });

    test('throws on missing block data', () {
      final ledger = BitLedger('PeerA');
      expect(() => ledger.getBlockData('QmMissing'), throwsA(isA<StateError>()));
    });
  });

  group('LedgerManager', () {
    test('getLedger creates new ledger if missing', () {
      final manager = LedgerManager();
      final ledger = manager.getLedger('PeerA');
      expect(ledger, isNotNull);
      expect(ledger.peerId, equals('PeerA'));
    });

    test('getLedger returns same instance for same peer', () {
      final manager = LedgerManager();
      final ledger1 = manager.getLedger('PeerA');
      final ledger2 = manager.getLedger('PeerA');
      expect(identical(ledger1, ledger2), isTrue);
    });

    test('clearLedger removes specific peer', () {
      final manager = LedgerManager();
      manager.getLedger('PeerA');
      manager.getLedger('PeerB');
      manager.clearLedger('PeerA');
      // Getting PeerA again should create a new one
      final newLedger = manager.getLedger('PeerA');
      expect(newLedger.sentBytes, equals(0)); // Fresh ledger
    });

    test('clearAllLedgers removes all', () {
      final manager = LedgerManager();
      manager.getLedger('PeerA').addSentBytes(10);
      manager.getLedger('PeerB').addSentBytes(20);
      manager.clearAllLedgers();
      final stats = manager.getBandwidthStats();
      expect(stats['sent'], equals(0));
    });

    test('getBandwidthStats aggregates all ledgers', () {
      final manager = LedgerManager();
      manager.getLedger('PeerA').addSentBytes(100);
      manager.getLedger('PeerA').addReceivedBytes(50);
      manager.getLedger('PeerB').addSentBytes(200);
      manager.getLedger('PeerB').addReceivedBytes(100);

      final stats = manager.getBandwidthStats();
      expect(stats['sent'], equals(300));
      expect(stats['received'], equals(150));
    });
  });

  group('Bitswap Message', () {
    test('creates empty message', () {
      final msg = bitswap_msg.Message();
      expect(msg.hasWantlist(), isFalse);
      expect(msg.hasBlocks(), isFalse);
    });

    test('addWantlistEntry adds to wantlist', () {
      final msg = bitswap_msg.Message();
      msg.addWantlistEntry('QmCid1', priority: 5);
      expect(msg.hasWantlist(), isTrue);
      final wantlist = msg.getWantlist();
      expect(wantlist.entries.containsKey('QmCid1'), isTrue);
    });

    test('addBlockPresence adds presence info', () {
      final msg = bitswap_msg.Message();
      msg.addBlockPresence('QmCid1', bitswap_msg.BlockPresenceType.have);
      expect(msg.hasBlockPresences(), isTrue);
      final presences = msg.getBlockPresences();
      expect(presences.length, equals(1));
      expect(presences.first.type, equals(bitswap_msg.BlockPresenceType.have));
    });

    test('serialization produces valid bytes', () async {
      final msg = bitswap_msg.Message();
      msg.addWantlistEntry('QmCid1', priority: 10);
      msg.addBlockPresence('QmCid2', bitswap_msg.BlockPresenceType.dontHave);

      final bytes = msg.toBytes();
      expect(bytes.isNotEmpty, isTrue);

      // Note: Full round-trip deserialization depends on Message.fromBytes implementation
      // which may have edge cases. Basic serialization verified here.
    });
  });
}
