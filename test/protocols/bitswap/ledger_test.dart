import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/bitswap/ledger.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart'
    as bitswap;

void main() {
  group('BitLedger', () {
    test('constructor initializes with peerId', () {
      final ledger = BitLedger('peer1');
      expect(ledger.peerId, equals('peer1'));
      expect(ledger.sentBytes, equals(0));
      expect(ledger.receivedBytes, equals(0));
    });

    test('addSentBytes updates sentBytes', () {
      final ledger = BitLedger('peer1');
      ledger.addSentBytes(100);
      expect(ledger.sentBytes, equals(100));
    });

    test('addSentBytes throws on negative bytes', () {
      final ledger = BitLedger('peer1');
      expect(() => ledger.addSentBytes(-10), throwsArgumentError);
    });

    test('addReceivedBytes updates receivedBytes', () {
      final ledger = BitLedger('peer1');
      ledger.addReceivedBytes(50);
      expect(ledger.receivedBytes, equals(50));
    });

    test('addReceivedBytes throws on negative bytes', () {
      final ledger = BitLedger('peer1');
      expect(() => ledger.addReceivedBytes(-5), throwsArgumentError);
    });

    test('getDebt calculates difference', () {
      final ledger = BitLedger('peer1');
      ledger.addSentBytes(100);
      ledger.addReceivedBytes(30);
      expect(ledger.getDebt(), equals(70));
    });

    test('storeBlockData and getBlockData', () {
      final ledger = BitLedger('peer1');
      final data = Uint8List.fromList([1, 2, 3]);
      ledger.storeBlockData('QmTest', data);

      expect(ledger.hasBlock('QmTest'), isTrue);
      expect(ledger.getBlockData('QmTest'), equals(data));
    });

    test('getBlockData throws for non-existent block', () {
      final ledger = BitLedger('peer1');
      expect(() => ledger.getBlockData('QmNonExistent'), throwsStateError);
    });

    test('hasBlock returns false for non-existent block', () {
      final ledger = BitLedger('peer1');
      expect(ledger.hasBlock('QmNonExistent'), isFalse);
    });

    test('toString returns formatted string', () {
      final ledger = BitLedger('peer1');
      ledger.addSentBytes(100);
      ledger.addReceivedBytes(50);
      final str = ledger.toString();
      expect(str, contains('peer1'));
      expect(str, contains('sentBytes=100'));
      expect(str, contains('receivedBytes=50'));
      expect(str, contains('debt=50'));
    });

    test('receivedMessage updates received bytes from blocks', () {
      final ledger = BitLedger('peer1');
      final message = bitswap.Message();
      message.blocks.add(Uint8List.fromList([1, 2, 3]));
      message.blocks.add(Uint8List.fromList([4, 5]));

      ledger.receivedMessage('peer1', message);
      expect(ledger.receivedBytes, equals(5));
    });
  });

  group('LedgerManager', () {
    test('getLedger creates new ledger if not exists', () {
      final manager = LedgerManager();
      final ledger = manager.getLedger('peer1');
      expect(ledger.peerId, equals('peer1'));
    });

    test('getLedger returns existing ledger', () {
      final manager = LedgerManager();
      final ledger1 = manager.getLedger('peer1');
      ledger1.addSentBytes(100);

      final ledger2 = manager.getLedger('peer1');
      expect(ledger2.sentBytes, equals(100));
    });

    test('clearLedger removes specific ledger', () {
      final manager = LedgerManager();
      manager.getLedger('peer1');
      manager.getLedger('peer2');

      manager.clearLedger('peer1');
      final ledger = manager.getLedger('peer1');
      expect(ledger.sentBytes, equals(0));
    });

    test('clearAllLedgers removes all ledgers', () {
      final manager = LedgerManager();
      manager.getLedger('peer1');
      manager.getLedger('peer2');

      manager.clearAllLedgers();
      final ledger1 = manager.getLedger('peer1');
      final ledger2 = manager.getLedger('peer2');
      expect(ledger1.sentBytes, equals(0));
      expect(ledger2.sentBytes, equals(0));
    });

    test('getBandwidthStats returns total stats', () {
      final manager = LedgerManager();
      final ledger1 = manager.getLedger('peer1');
      ledger1.addSentBytes(100);
      ledger1.addReceivedBytes(50);

      final ledger2 = manager.getLedger('peer2');
      ledger2.addSentBytes(200);
      ledger2.addReceivedBytes(100);

      final stats = manager.getBandwidthStats();
      expect(stats['sent'], equals(300));
      expect(stats['received'], equals(150));
    });

    test('getBandwidthStats returns zeros for no ledgers', () {
      final manager = LedgerManager();
      final stats = manager.getBandwidthStats();
      expect(stats['sent'], equals(0));
      expect(stats['received'], equals(0));
    });

    test('ledgers are bounded and evict oldest peers', () {
      final manager = LedgerManager();
      manager.getLedger('peer-oldest').addSentBytes(42);
      for (int i = 0; i < LedgerManager.maxLedgers; i++) {
        manager.getLedger('peer-$i');
      }
      // The oldest peer was evicted to stay within the bound — a fresh
      // ledger comes back with zeroed stats.
      expect(manager.getLedger('peer-oldest').sentBytes, equals(0));
      // A mid-range peer survives (its stats persisted).
      manager.getLedger('peer-500').addSentBytes(7);
      expect(manager.getLedger('peer-500').sentBytes, equals(7));
    });

    test('block data storage is bounded per ledger', () {
      final ledger = BitLedger('peer1');
      for (int i = 0; i < BitLedger.maxBlockDataEntries + 5; i++) {
        ledger.storeBlockData('cid-$i', Uint8List.fromList([i & 0xff]));
      }
      // The first entry was evicted once the bound was exceeded.
      expect(ledger.hasBlock('cid-0'), isFalse);
      // Recent entries remain available.
      expect(
        ledger.hasBlock('cid-${BitLedger.maxBlockDataEntries + 4}'),
        isTrue,
      );
    });
  });
}
