// test/core/unixfs/unixfs_directory_test.dart
//
// Kubo-parity tests for UnixFS basic directories: node encoding, link
// ordering, cumulative Tsize semantics, and path resolution. All expected
// CIDs below were cross-checked against the canonical go-unixfs wire format
// (PBNode{Data: unixfs Data{Type: Directory}}, links sorted by name bytes,
// PBLink{Tsize = cumulative child DAG size}).
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_builder.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_errors.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_node.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_resolver.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import '../../mocks/mock_block_store.dart';

void main() {
  late IBlockStore store;
  late UnixFSPathResolver resolver;

  setUp(() async {
    store = MockBlockStore();
    await store.start();
    resolver = UnixFSPathResolver(store: store);
  });

  /// Builds a UnixFS file and stores every emitted block.
  Future<Block> createFile(List<int> data) async {
    final builder = UnixFSBuilder();
    Block? root;
    await for (final block in builder.build(Stream.value(data))) {
      await store.putBlock(block);
      root = block;
    }
    return root!;
  }

  group('Kubo parity: directory node encoding', () {
    test('empty directory matches the well-known Kubo CIDv0', () async {
      final dir = await createDirectory(store, const []);

      // `ipfs add -r` / `ipfs files mkdir` empty directory:
      // PBNode{Data: Data{Type: Directory}} == 0x0a 0x02 0x08 0x01.
      expect(dir.data, equals(Uint8List.fromList([0x0a, 0x02, 0x08, 0x01])));
      expect(
        dir.cid.toString(),
        equals('QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn'),
      );
    });

    test('empty directory matches the Kubo CIDv1 form', () async {
      final dir = await UnixFSDirectoryBuilder(cidVersion: 1)
          .build(store, const []);
      expect(dir.cid.version, equals(1));
      expect(
        dir.cid.toString(),
        equals(
          'bafybeiczsscdsbs7ffqz55asqdf3smv6klcw3gofszvwlyarci47bgf354',
        ),
      );
    });

    test('directory Data carries only Type: Directory', () async {
      final file = await createFile('x'.codeUnits);
      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'f', cid: file.cid, tsize: 0),
      ]);

      final inner = unixfs_pb.Data.fromBuffer(dir.pbNode.data);
      expect(inner.type, equals(unixfs_pb.Data_DataType.Directory));
      // go-unixfs never sets filesize/blocksizes/data on directory nodes;
      // the inner Data message is exactly `08 01` on the wire.
      expect(dir.pbNode.data, equals(Uint8List.fromList([0x08, 0x01])));
      expect(dir.isDirectory, isTrue);
      expect(dir.isDirectoryLike, isTrue);
      expect(dir.isFile, isFalse);
    });

    test('single-chunk file inside directory produces Kubo CIDs', () async {
      // "hello world\n" is the canonical Kubo dag-pb CIDv0 test vector.
      final file = await createFile('hello world\n'.codeUnits);
      expect(
        file.cid.toString(),
        equals('QmT78zSuBmuS4z925WZfrqQ1qHaJ56DQaTfyMUF7F8ff5o'),
      );

      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'hello.txt', cid: file.cid, tsize: 0),
      ]);

      expect(dir.pbNode.links.length, equals(1));
      final link = dir.pbNode.links.single;
      expect(link.name, equals('hello.txt'));
      // Link Hash is the full binary CID of the child (v0: raw multihash).
      expect(link.hash, equals(file.cid.toBytes()));
      // Tsize is the cumulative DAG size = the serialized leaf block, not
      // the logical filesize (12).
      expect(link.size.toInt(), equals(file.data.length));
      expect(link.size.toInt(), equals(20));
      expect(
        dir.cid.toString(),
        equals('QmcAMsiAwoNC8Wp2uSn2RWSTLZe7dPRc5A6XS8BHnvWHS9'),
      );
    });

    test('entries are sorted by UTF-8 byte order, not UTF-16 order', () async {
      // U+FFFD (UTF-8 0xEFBFBD) sorts below '😀' (U+1F600, UTF-8
      // 0xF0...) in byte order, but above it in UTF-16 code-unit order
      // (0xFFFD > surrogate 0xD83D). Kubo uses byte order.
      final file = await createFile([0]);
      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: '\u{1F600}x', cid: file.cid, tsize: 0),
        UnixFSDirectoryEntry(name: '\uFFFD.txt', cid: file.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'a', cid: file.cid, tsize: 0),
      ]);

      expect(
        dir.pbNode.links.map((l) => l.name).toList(),
        equals(['a', '\uFFFD.txt', '\u{1F600}x']),
      );
    });

    test('entry order in the input list does not affect the CID', () async {
      final fileA = await createFile('aaa'.codeUnits);
      final fileB = await createFile('bbb'.codeUnits);

      final dir1 = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'a.txt', cid: fileA.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'b.txt', cid: fileB.cid, tsize: 0),
      ]);
      final dir2 = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'b.txt', cid: fileB.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'a.txt', cid: fileA.cid, tsize: 0),
      ]);
      expect(dir1.cid, equals(dir2.cid));
      expect(dir1.data, equals(dir2.data));
    });
  });

  group('Kubo parity: cumulative Tsize', () {
    test('link Tsize for a multi-chunk file covers the whole file DAG',
        () async {
      // > 256 KiB forces a multi-chunk dag-pb file root with leaf links.
      final data = Uint8List(300 * 1024);
      for (var i = 0; i < data.length; i++) {
        data[i] = i & 0xff;
      }
      final fileRoot = await createFile(data);
      final fileTsize = await computeTsize(store, fileRoot.cid);
      expect(fileTsize, greaterThan(fileRoot.data.length));

      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'big.bin', cid: fileRoot.cid, tsize: 0),
      ]);

      expect(dir.pbNode.links.single.size.toInt(), equals(fileTsize));
    });

    test('link Tsize for a subdirectory is cumulative over descendants',
        () async {
      final file = await createFile('nested'.codeUnits);
      final subdir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'file.txt', cid: file.cid, tsize: 0),
      ]);
      final root = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'sub', cid: subdir.cid, tsize: 0),
      ]);

      final expectedSubdirTsize = subdir.data.length + file.data.length;
      expect(
        root.pbNode.links.single.size.toInt(),
        equals(expectedSubdirTsize),
      );
      expect(
        await computeTsize(store, root.cid),
        equals(root.data.length + expectedSubdirTsize),
      );
    });

    test('computeTsize counts a shared child once per link (diamond DAG)',
        () async {
      // go-merkledag's cumulative size sums per-link Tsize, so a child
      // reachable through two links contributes its size twice.
      final file = await createFile('shared'.codeUnits);
      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'a', cid: file.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'b', cid: file.cid, tsize: 0),
      ]);

      expect(
        await computeTsize(store, dir.cid),
        equals(dir.data.length + 2 * file.data.length),
      );
    });

    test('computeTsize throws when a linked block is missing', () async {
      final ghostCid = await CID.fromContent(
        Uint8List.fromList([9, 9, 9]),
        codec: 'dag-pb',
        version: 0,
      );
      final dir = await UnixFSDirectoryBuilder().build(store, [
        UnixFSDirectoryEntry(name: 'ghost', cid: ghostCid, tsize: 1),
      ]);

      expect(
        () => computeTsize(store, dir.cid),
        throwsA(isA<PathResolutionError>()),
      );
    });
  });

  group('directory entry validation', () {
    final cases = <String, String>{
      'empty': '',
      'contains slash': 'a/b',
      'dot': '.',
      'dot-dot': '..',
    };

    cases.forEach((label, name) {
      test('rejects $label entry name', () async {
        final file = await createFile([1]);
        expect(
          UnixFSDirectoryBuilder().build(store, [
            UnixFSDirectoryEntry(name: name, cid: file.cid, tsize: 0),
          ]),
          throwsArgumentError,
        );
      });
    });

    test('rejects duplicate entry names', () async {
      final file = await createFile([1]);
      expect(
        UnixFSDirectoryBuilder().build(store, [
          UnixFSDirectoryEntry(name: 'dup', cid: file.cid, tsize: 0),
          UnixFSDirectoryEntry(name: 'dup', cid: file.cid, tsize: 0),
        ]),
        throwsArgumentError,
      );
    });

    test('addChildToDirectory rejects invalid names', () async {
      final file = await createFile([1]);
      final dir = await createDirectory(store, const []);

      for (final bad in ['', 'a/b', '.', '..']) {
        expect(
          addChildToDirectory(store, dir.cid, bad, file.cid),
          throwsArgumentError,
        );
      }
    });
  });

  group('path resolution through directories', () {
    Future<UnixFSNode> buildTree() async {
      // root/
      //   a/
      //     b/
      //       deep.txt
      //   top.txt
      final deep = await createFile('deep'.codeUnits);
      final top = await createFile('top'.codeUnits);
      final b = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'deep.txt', cid: deep.cid, tsize: 0),
      ]);
      final a = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'b', cid: b.cid, tsize: 0),
      ]);
      return createDirectory(store, [
        UnixFSDirectoryEntry(name: 'a', cid: a.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'top.txt', cid: top.cid, tsize: 0),
      ]);
    }

    test('empty and slash-only paths resolve to the root', () async {
      final root = await buildTree();
      expect(await resolver.resolve(root.cid, ''), equals(root.cid));
      expect(await resolver.resolve(root.cid, '/'), equals(root.cid));
      expect(await resolver.resolve(root.cid, '//'), equals(root.cid));
    });

    test('resolves nested paths with or without leading/trailing slashes',
        () async {
      final root = await buildTree();
      const deepContent = 'deep';
      final deepCid = (await createFile(deepContent.codeUnits)).cid;

      for (final path in [
        'a/b/deep.txt',
        '/a/b/deep.txt',
        'a/b/deep.txt/',
        '/a/b/deep.txt/',
      ]) {
        expect(await resolver.resolve(root.cid, path), equals(deepCid));
      }
    });

    test('resolveNode returns the directory node for a directory path',
        () async {
      final root = await buildTree();
      final node = await resolver.resolveNode(root.cid, 'a/b/');
      expect(node.isDirectory, isTrue);
      expect(
        node.pbNode.links.map((l) => l.name).toList(),
        equals(['deep.txt']),
      );
    });

    test('cannot traverse into a file', () async {
      final root = await buildTree();
      expect(
        () => resolver.resolve(root.cid, 'top.txt/inner'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('missing intermediate directory fails resolution', () async {
      final root = await buildTree();
      expect(
        () => resolver.resolve(root.cid, 'a/nope/deep.txt'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('fails when a linked block is not in the store', () async {
      final root = await buildTree();
      final fresh = MockBlockStore();
      await fresh.start();
      // Store only the root block so the 'a' lookup misses.
      fresh.setupBlock(
        root.cid.toString(),
        Block(cid: root.cid, data: root.data, format: 'dag-pb'),
      );
      final freshResolver = UnixFSPathResolver(store: fresh);

      expect(
        () => freshResolver.resolve(root.cid, 'a/b/deep.txt'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('directory with duplicate link names fails on decode', () async {
      // The UnixFS spec requires decoders to reject directories whose links
      // carry byte-identical names. Build the malformed block by hand since
      // the encoder refuses to produce it.
      final file = await createFile('dup'.codeUnits);
      final dupNode = dag_pb.PBNode(
        data: unixfs_pb.Data(type: unixfs_pb.Data_DataType.Directory)
            .writeToBuffer(),
        links: [
          dag_pb.PBLink(
            hash: Uint8List.fromList(file.cid.toBytes()),
            name: 'same',
            size: Int64(file.data.length),
          ),
          dag_pb.PBLink(
            hash: Uint8List.fromList(file.cid.toBytes()),
            name: 'same',
            size: Int64(file.data.length),
          ),
        ],
      );
      final dupBytes = dupNode.writeToBuffer();
      final dupCid = await CID.fromContent(
        dupBytes,
        codec: 'dag-pb',
        version: 0,
      );
      (store as MockBlockStore).setupBlock(
        dupCid.toString(),
        Block(cid: dupCid, data: dupBytes, format: 'dag-pb'),
      );

      expect(
        () => resolver.resolve(dupCid, 'same'),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('entry names are matched byte-for-byte (case sensitive)', () async {
      final file = await createFile('case'.codeUnits);
      final root = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'File.txt', cid: file.cid, tsize: 0),
      ]);

      expect(await resolver.resolve(root.cid, 'File.txt'), equals(file.cid));
      expect(
        () => resolver.resolve(root.cid, 'file.txt'),
        throwsA(isA<PathResolutionError>()),
      );
    });
  });

  group('addChildToDirectory', () {
    test('preserves sibling links and updates cumulative Tsize', () async {
      final fileA = await createFile('a'.codeUnits);
      final fileB = await createFile('bb'.codeUnits);
      final fileC = await createFile('ccc'.codeUnits);

      final dir = await createDirectory(store, [
        UnixFSDirectoryEntry(name: 'a', cid: fileA.cid, tsize: 0),
        UnixFSDirectoryEntry(name: 'b', cid: fileB.cid, tsize: 0),
      ]);

      final updated =
          await addChildToDirectory(store, dir.cid, 'c', fileC.cid);

      expect(updated.isDirectory, isTrue);
      expect(
        updated.pbNode.links.map((l) => l.name).toList(),
        equals(['a', 'b', 'c']),
      );
      expect(
        updated.pbNode.links[2].size.toInt(),
        equals(fileC.data.length),
      );
      // The untouched siblings keep their original Tsize values.
      expect(updated.pbNode.links[0].size.toInt(), fileA.data.length);
      expect(updated.pbNode.links[1].size.toInt(), fileB.data.length);
    });

    test('adding to a missing directory throws', () async {
      final file = await createFile('x'.codeUnits);
      final missing = await CID.fromContent(
        Uint8List.fromList([7, 7, 7]),
        codec: 'dag-pb',
        version: 0,
      );
      expect(
        addChildToDirectory(store, missing, 'x', file.cid),
        throwsA(isA<PathResolutionError>()),
      );
    });

    test('adding to a non-directory throws', () async {
      final file = await createFile('x'.codeUnits);
      final other = await createFile('y'.codeUnits);
      expect(
        addChildToDirectory(store, file.cid, 'x', other.cid),
        throwsA(isA<PathResolutionError>()),
      );
    });
  });

  group('utf8 name helpers', () {
    test('compareEntryNamesUtf8 orders by encoded bytes', () {
      expect(compareEntryNamesUtf8('a', 'b'), lessThan(0));
      expect(compareEntryNamesUtf8('b', 'a'), greaterThan(0));
      expect(compareEntryNamesUtf8('a', 'a'), equals(0));
      expect(compareEntryNamesUtf8('a', 'ab'), lessThan(0));
      // U+FFFD (0xEFBFBD) < U+1F600 (0xF09F9880) in byte order.
      expect(compareEntryNamesUtf8('\uFFFD', '\u{1F600}'), lessThan(0));
      // UTF-16 would order these the other way around (0xFFFD > 0xD83D).
      expect('\uFFFD'.compareTo('\u{1F600}'), greaterThan(0));
    });
  });
}
