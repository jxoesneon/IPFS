// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/bitswap/bitswap.pb.dart';

void main() {
  group('Message_Wantlist_Entry', () {
    test('round-trips and accessors work', () {
      final original = Message_Wantlist_Entry(block: const [0, 1, 2], priority: 1, cancel: true, wantType: Message_Wantlist_WantType.values.first, sendDontHave: true);
      expect(original.block, const [0, 1, 2]);
      expect(original.priority, 1);
      expect(original.cancel, true);
      expect(original.wantType, isNotNull);
      expect(original.sendDontHave, true);
      original.hasBlock();
      original.clearBlock();
      original.hasPriority();
      original.clearPriority();
      original.hasCancel();
      original.clearCancel();
      original.hasWantType();
      original.clearWantType();
      original.hasSendDontHave();
      original.clearSendDontHave();
      expect(Message_Wantlist_Entry.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Message_Wantlist_Entry.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Message_Wantlist_Entry.fromJson(json), isNotNull);
    });
  });

  group('Message_Wantlist', () {
    test('round-trips and accessors work', () {
      final original = Message_Wantlist(entries: [Message_Wantlist_Entry.create()], full: true);
      expect(original.entries.length, 1);
      expect(original.full, true);
      original.entries.clear();
      original.hasFull();
      original.clearFull();
      expect(Message_Wantlist.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Message_Wantlist.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Message_Wantlist.fromJson(json), isNotNull);
    });
  });

  group('Message_Block', () {
    test('round-trips and accessors work', () {
      final original = Message_Block(prefix: const [0, 1, 2], data: const [0, 1, 2]);
      expect(original.prefix, const [0, 1, 2]);
      expect(original.data, const [0, 1, 2]);
      original.hasPrefix();
      original.clearPrefix();
      original.hasData();
      original.clearData();
      expect(Message_Block.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Message_Block.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Message_Block.fromJson(json), isNotNull);
    });
  });

  group('Message_BlockPresence', () {
    test('round-trips and accessors work', () {
      final original = Message_BlockPresence(cid: const [0, 1, 2], type: Message_BlockPresence_Type.values.first);
      expect(original.cid, const [0, 1, 2]);
      expect(original.type, isNotNull);
      original.hasCid();
      original.clearCid();
      original.hasType();
      original.clearType();
      expect(Message_BlockPresence.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Message_BlockPresence.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Message_BlockPresence.fromJson(json), isNotNull);
    });
  });

  group('Message', () {
    test('round-trips and accessors work', () {
      final original = Message(wantlist: Message_Wantlist.create(), blocks: [[0, 1]], payload: [Message_Block.create()], blockPresences: [Message_BlockPresence.create()], pendingBytes: 1);
      expect(original.wantlist, isNotNull);
      expect(original.blocks, [[0, 1]]);
      expect(original.payload.length, 1);
      expect(original.blockPresences.length, 1);
      expect(original.pendingBytes, 1);
      original.hasWantlist();
      original.clearWantlist();
      original.blocks.clear();
      original.payload.clear();
      original.blockPresences.clear();
      original.hasPendingBytes();
      original.clearPendingBytes();
      original.ensureWantlist();
      expect(Message.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = Message.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) { });
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(Message.fromJson(json), isNotNull);
    });
  });

}
