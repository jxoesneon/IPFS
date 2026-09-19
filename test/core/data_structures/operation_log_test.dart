import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/operation_log.dart';
import 'package:dart_ipfs/src/proto/generated/core/node_type.pbenum.dart';
import 'package:dart_ipfs/src/proto/generated/core/operation_log.pb.dart';
import 'package:test/test.dart';

void main() {
  group('OperationLog', () {
    test('addEntry/getEntries/clear', () {
      final log = OperationLog();
      log.addEntry(
        operation: 'add',
        details: 'added a block',
        nodeType: NodeTypeProto.NODE_TYPE_FILE,
      );

      final entries = log.getEntries();
      expect(entries, hasLength(1));
      expect(entries.single.operation, 'add');
      expect(entries.single.details, 'added a block');
      expect(entries.single.cid, isNull);
      expect(entries.single.nodeType, NodeTypeProto.NODE_TYPE_FILE);
      expect(() => entries.add(entries.single), throwsUnsupportedError);

      log.clear();
      expect(log.getEntries(), isEmpty);
    });

    test('serialize/deserialize roundtrip preserves CID', () async {
      final cid = await CID.fromContent(
        Uint8List.fromList('operation log cid payload'.codeUnits),
      );

      final log = OperationLog();
      log.addEntry(
        operation: 'pin',
        details: 'pinned cid',
        cid: cid,
        nodeType: NodeTypeProto.NODE_TYPE_FILE,
      );

      final restored = OperationLog()..deserialize(log.serialize());
      final entries = restored.getEntries();
      expect(entries, hasLength(1));

      expect(entries[0].cid, isNotNull);
      expect(entries[0].cid!.toBytes(), equals(cid.toBytes()));
      expect(entries[0].operation, 'pin');
      expect(entries[0].nodeType, NodeTypeProto.NODE_TYPE_FILE);
    });

    test('fromProto returns null CID when the field is unset', () {
      final pbEntry = OperationLogEntryProto()
        ..operation = 'status'
        ..details = 'no cid'
        ..nodeType = NodeTypeProto.NODE_TYPE_UNSPECIFIED;

      final entry = OperationLogEntry.fromProto(pbEntry);
      expect(entry.cid, isNull);
      expect(entry.operation, 'status');
    });

    test('toString renders entries', () {
      final log = OperationLog();
      log.addEntry(operation: 'add', details: 'something');
      expect(log.toString(), contains('add'));
    });
  });
}
