// test/core/data_structures/directory_test.dart
import 'package:dart_ipfs/src/core/data_structures/directory.dart';
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

void main() {
  group('IPFSDirectoryEntry', () {
    test('creates entry with required fields', () {
      final entry = IPFSDirectoryEntry(
        name: 'test.txt',
        hash: [1, 2, 3, 4],
        size: Int64(1024),
        isDirectory: false,
      );

      expect(entry.name, equals('test.txt'));
      expect(entry.hash, equals([1, 2, 3, 4]));
      expect(entry.size.toInt(), equals(1024));
      expect(entry.isDirectory, isFalse);
      expect(entry.mode, isNull);
      expect(entry.mtime, isNull);
    });

    test('creates entry with optional mode and mtime', () {
      final mtime = DateTime(2024, 1, 15, 10, 30);
      final entry = IPFSDirectoryEntry(
        name: 'dir',
        hash: [5, 6, 7],
        size: Int64(512),
        isDirectory: true,
        mode: 493,
        mtime: mtime,
      );

      expect(entry.mode, equals(493));
      expect(entry.mtime, equals(mtime));
    });

    test('toLink() creates PBLink', () {
      final entry = IPFSDirectoryEntry(
        name: 'linked_file',
        hash: [10, 20, 30],
        size: Int64(2048),
        isDirectory: false,
      );

      final link = entry.toLink();
      expect(link.name, equals('linked_file'));
      expect(link.hash, equals([10, 20, 30]));
      expect(link.size.toInt(), equals(2048));
    });
  });

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

    test('addEntry adds entries to directory', () {
      final manager = IPFSDirectoryManager();
      manager.addEntry(
        IPFSDirectoryEntry(
          name: 'file1.txt',
          hash: [1],
          size: Int64(100),
          isDirectory: false,
        ),
      );
      manager.addEntry(
        IPFSDirectoryEntry(
          name: 'file2.txt',
          hash: [2],
          size: Int64(200),
          isDirectory: false,
        ),
      );

      final node = manager.build();
      expect(node.links.length, equals(2));
    });

    test('build sorts entries by name', () {
      final manager = IPFSDirectoryManager();
      manager.addEntry(
        IPFSDirectoryEntry(
          name: 'z_last',
          hash: [1],
          size: Int64(10),
          isDirectory: false,
        ),
      );
      manager.addEntry(
        IPFSDirectoryEntry(
          name: 'a_first',
          hash: [2],
          size: Int64(20),
          isDirectory: false,
        ),
      );
      manager.addEntry(
        IPFSDirectoryEntry(
          name: 'm_middle',
          hash: [3],
          size: Int64(30),
          isDirectory: false,
        ),
      );

      final node = manager.build();
      expect(node.links[0].name, equals('a_first'));
      expect(node.links[1].name, equals('m_middle'));
      expect(node.links[2].name, equals('z_last'));
    });

    test('build sorts entries by UTF-8 byte order, not UTF-16', () {
      // Kubo/go sorts directory links by raw UTF-8 name bytes. UTF-16
      // code-unit ordering (Dart's String.compareTo) disagrees for names
      // containing supplementary-plane characters: U+10000 is encoded as a
      // surrogate pair (0xD800..) which sorts *before* BMP characters in
      // U+E000–U+FFFF under UTF-16, but its UTF-8 encoding (0xF0...) sorts
      // *after* theirs (0xEE...).
      const bmpPrivateUse = ''; // U+E000, UTF-8: EE 80 80
      const supplementary = '𐀀'; // U+10000, UTF-8: F0 90 80 80

      // Sanity check that the two orderings actually diverge for this pair.
      expect(
        bmpPrivateUse.compareTo(supplementary) > 0,
        isTrue,
        reason: 'UTF-16 sorts the surrogate pair first',
      );

      final utf8Order = ['b.txt', 'é.txt', bmpPrivateUse, supplementary];
      final utf16Order = ['b.txt', 'é.txt', supplementary, bmpPrivateUse];

      final manager = IPFSDirectoryManager();
      // Add in reverse UTF-8 order to exercise the sort.
      for (final name in utf8Order.reversed) {
        manager.addEntry(
          IPFSDirectoryEntry(
            name: name,
            hash: [1],
            size: Int64(1),
            isDirectory: false,
          ),
        );
      }

      final linkNames = manager.build().links.map((l) => l.name).toList();
      expect(linkNames, equals(utf8Order));
      expect(linkNames, isNot(equals(utf16Order)));
    });
  });
}
