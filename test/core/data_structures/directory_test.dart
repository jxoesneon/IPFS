// test/core/data_structures/directory_test.dart
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('IPFSDirectoryManager', () {
    test('build creates a directory node with minimal data', () {
      final manager = IPFSDirectoryManager();
      final node = manager.build();

      final data = Data.fromBuffer(node.data);
      expect(data.type, Data_DataType.Directory);
      expect(data.hasMode(), isFalse);
      expect(data.hasMtime(), isFalse);
    });

    test('build includes mode and mtime if provided', () {
      final now = DateTime.fromMillisecondsSinceEpoch(
        1609459200000,
      ); // 2021-01-01
      final manager = IPFSDirectoryManager(mode: 0755, mtime: now);

      final node = manager.build();
      final data = Data.fromBuffer(node.data);

      expect(data.type, Data_DataType.Directory);
      expect(data.mode, 0755);
      expect(data.mtime, Int64(1609459200));
    });

    test('setMode and setModificationTime update internal state', () {
      final manager = IPFSDirectoryManager();
      final now = DateTime.fromMillisecondsSinceEpoch(
        1672531200000,
      ); // 2023-01-01

      manager.setMode(0644);
      manager.setModificationTime(now);

      final node = manager.build();
      final data = Data.fromBuffer(node.data);

      expect(data.mode, 0644);
      expect(data.mtime, Int64(1672531200));
    });
  });
}
