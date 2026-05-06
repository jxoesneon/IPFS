import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/protocols/bitswap/message.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/cid.dart';

void main() {
  group('Message', () {
    test('constructor creates empty message', () {
      final message = Message();
      expect(message.getBlocks(), isEmpty);
      expect(message.getWantlist().entries, isEmpty);
      expect(message.getBlockPresences(), isEmpty);
      expect(message.hasBlocks(), isFalse);
      expect(message.hasWantlist(), isFalse);
      expect(message.hasBlockPresences(), isFalse);
      expect(message.pendingBytes, equals(0));
      expect(message.from, isNull);
    });

    test('addBlock and getBlocks', () async {
      final message = Message();
      final data = Uint8List.fromList([1, 2, 3]);
      final block = await Block.fromData(data);
      
      message.addBlock(block);
      expect(message.hasBlocks(), isTrue);
      expect(message.getBlocks(), hasLength(1));
    });

    test('addWantlistEntry and getWantlist', () {
      final message = Message();
      message.addWantlistEntry('QmTest', priority: 10);
      
      expect(message.hasWantlist(), isTrue);
      final wantlist = message.getWantlist();
      expect(wantlist.entries, hasLength(1));
      expect(wantlist.entries['QmTest']?.priority, equals(10));
    });

    test('addWantlistEntry with all parameters', () {
      final message = Message();
      message.addWantlistEntry(
        'QmTest',
        priority: 5,
        cancel: true,
        wantType: WantType.have,
        sendDontHave: true,
      );
      
      final wantlist = message.getWantlist();
      final entry = wantlist.entries['QmTest'];
      expect(entry?.cancel, isTrue);
      expect(entry?.wantType, equals(WantType.have));
      expect(entry?.sendDontHave, isTrue);
    });

    test('addBlockPresence and getBlockPresences', () {
      final message = Message();
      message.addBlockPresence('QmTest', BlockPresenceType.have);
      
      expect(message.hasBlockPresences(), isTrue);
      final presences = message.getBlockPresences();
      expect(presences, hasLength(1));
      expect(presences.first.cid, equals('QmTest'));
      expect(presences.first.type, equals(BlockPresenceType.have));
    });

    test('pendingBytes can be set', () {
      final message = Message();
      message.pendingBytes = 1000;
      expect(message.pendingBytes, equals(1000));
    });

    test('from can be set', () {
      final message = Message();
      message.from = 'peer1';
      expect(message.from, equals('peer1'));
    });
  });

  group('WantlistEntry', () {
    test('constructor with defaults', () {
      final entry = WantlistEntry(cid: 'QmTest');
      expect(entry.cid, equals('QmTest'));
      expect(entry.priority, equals(1));
      expect(entry.cancel, isFalse);
      expect(entry.wantType, equals(WantType.block));
      expect(entry.sendDontHave, isFalse);
    });

    test('constructor with all parameters', () {
      final entry = WantlistEntry(
        cid: 'QmTest',
        priority: 10,
        cancel: true,
        wantType: WantType.have,
        sendDontHave: true,
      );
      expect(entry.priority, equals(10));
      expect(entry.cancel, isTrue);
      expect(entry.wantType, equals(WantType.have));
      expect(entry.sendDontHave, isTrue);
    });
  });

  group('Wantlist', () {
    test('addEntry and contains', () {
      final wantlist = Wantlist();
      final entry = WantlistEntry(cid: 'QmTest');
      
      wantlist.addEntry(entry);
      expect(wantlist.contains('QmTest'), isTrue);
      expect(wantlist.entries, hasLength(1));
    });

    test('removeEntry', () {
      final wantlist = Wantlist();
      final entry = WantlistEntry(cid: 'QmTest');
      
      wantlist.addEntry(entry);
      expect(wantlist.contains('QmTest'), isTrue);
      
      wantlist.removeEntry('QmTest');
      expect(wantlist.contains('QmTest'), isFalse);
    });

    test('addEntry updates existing entry', () {
      final wantlist = Wantlist();
      final entry1 = WantlistEntry(cid: 'QmTest', priority: 1);
      final entry2 = WantlistEntry(cid: 'QmTest', priority: 10);
      
      wantlist.addEntry(entry1);
      wantlist.addEntry(entry2);
      
      expect(wantlist.entries, hasLength(1));
      expect(wantlist.entries['QmTest']?.priority, equals(10));
    });
  });

  group('BlockPresence', () {
    test('constructor', () {
      final presence = BlockPresence(
        cid: 'QmTest',
        type: BlockPresenceType.have,
      );
      expect(presence.cid, equals('QmTest'));
      expect(presence.type, equals(BlockPresenceType.have));
    });

    test('constructor with dontHave type', () {
      final presence = BlockPresence(
        cid: 'QmTest',
        type: BlockPresenceType.dontHave,
      );
      expect(presence.type, equals(BlockPresenceType.dontHave));
    });
  });

  group('WantType enum', () {
    test('enum values exist', () {
      expect(WantType.block, isNotNull);
      expect(WantType.have, isNotNull);
    });
  });

  group('BlockPresenceType enum', () {
    test('enum values exist', () {
      expect(BlockPresenceType.have, isNotNull);
      expect(BlockPresenceType.dontHave, isNotNull);
    });
  });
}
