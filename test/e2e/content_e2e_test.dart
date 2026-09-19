@TestOn('vm')
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import 'e2e_helpers.dart';

void main() {
  group('E2E content operations', () {
    late Directory repo;
    late IPFSNode node;

    setUp(() async {
      repo = await makeRepoDir('content');
      node = await IPFSNode.create(offlineConfig(repo.path));
      await node.start();
    });

    tearDown(() async {
      await stopQuietly(node);
      await deleteRepo(repo);
    });

    test('addFile then cat round-trips arbitrary bytes', () async {
      final data = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));

      final cid = await node.addFile(data);
      expect(cid, isNotEmpty);

      expect(await node.cat(cid), equals(data));
      expect(await node.get(cid), equals(data));
    });

    test('identical content yields an identical CID', () async {
      final data = utf8Bytes('deterministic');
      final cid1 = await node.addFile(data);
      final cid2 = await node.addFile(Uint8List.fromList(data));
      expect(cid1, equals(cid2));
    });

    test('different content yields different CIDs', () async {
      final cid1 = await node.addFile(utf8Bytes('a'));
      final cid2 = await node.addFile(utf8Bytes('b'));
      expect(cid1, isNot(equals(cid2)));
    });

    test('addFileStream reassembles chunks', () async {
      final chunks = [
        utf8Bytes('hello '),
        utf8Bytes('streamed '),
        utf8Bytes('world'),
      ];

      final cid = await node.addFileStream(Stream.fromIterable(chunks));
      expect(await node.cat(cid), equals(utf8Bytes('hello streamed world')));
    });

    test('cat of an unknown CID returns null', () async {
      await node.addFile(utf8Bytes('known'));
      // A valid CID for content that was never added.
      final absent = CID.computeForDataSync(utf8Bytes('absent')).encode();
      expect(await node.cat(absent), isNull);
    });

    test('addDirectory stores a retrievable directory listing', () async {
      final rootCid = await node.addDirectory({
        'alpha.txt': utf8Bytes('alpha'),
        'beta.txt': utf8Bytes('beta'),
      });

      final links = await node.ls(rootCid);
      expect(links, hasLength(2));
      final names = links.map((l) => l.name).toSet();
      expect(names, containsAll(<String>['alpha.txt', 'beta.txt']));
    });

    test('get resolves a file inside a directory by path', () async {
      final rootCid = await node.addDirectory({
        'docs': {'readme.md': utf8Bytes('# readme')},
        'top.txt': utf8Bytes('top-level'),
      });

      expect(
        await node.get(rootCid, path: 'docs/readme.md'),
        equals(utf8Bytes('# readme')),
      );
      expect(
        await node.get(rootCid, path: 'top.txt'),
        equals(utf8Bytes('top-level')),
      );
    });

    test('get resolves deeply nested directory paths', () async {
      final rootCid = await node.addDirectory({
        'a': {
          'b': {
            'c': {'deep.txt': utf8Bytes('deep content')},
          },
        },
      });

      expect(
        await node.get(rootCid, path: 'a/b/c/deep.txt'),
        equals(utf8Bytes('deep content')),
      );
    });

    test('get returns null for a missing path component', () async {
      final rootCid = await node.addDirectory({'exists.txt': utf8Bytes('x')});
      expect(await node.get(rootCid, path: 'missing.txt'), isNull);
    });

    test('ls on a file CID returns an empty list', () async {
      final cid = await node.addFile(utf8Bytes('not a directory'));
      expect(await node.ls(cid), isEmpty);
    });

    test('onNewContent emits the CID of each added file', () async {
      final emitted = <String>[];
      final sub = node.onNewContent.listen(emitted.add);

      final cid = await node.addFile(utf8Bytes('eventful'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, contains(cid));
      await sub.cancel();
    });

    test('binary content survives a round-trip byte-for-byte', () async {
      final data = Uint8List.fromList(
        List<int>.generate(256 * 1024, (i) => (i * 31) & 0xff),
      );
      final cid = await node.addFile(data);
      final back = await node.cat(cid);
      expect(back, isNotNull);
      expect(back!.length, equals(data.length));
      expect(back, equals(data));
    });

    test('cat reassembles a file larger than the 256 KiB chunk size', () async {
      // Kubo parity: add chunks at 256 KiB, so 600 KiB produces a DAG of
      // three leaf nodes under a linked root — cat must traverse the links.
      final data = Uint8List.fromList(
        List<int>.generate(600 * 1024, (i) => (i * 7) & 0xff),
      );
      final cid = await node.addFile(data);
      expect(await node.cat(cid), equals(data));
      expect(await node.get(cid), equals(data));
    });

    test('cat reassembles a Kubo-style chunked UnixFS DAG', () async {
      // Fixture shaped like `ipfs add` output, built by hand rather than by
      // this package's builder: two dag-pb leaf file nodes linked in order
      // from a dag-pb root carrying filesize/blocksizes.
      Future<Block> leaf(List<int> payload) async {
        final unixfs = unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.File,
          data: payload,
          filesize: Int64(payload.length),
        );
        final node_ = dag_pb.PBNode(data: unixfs.writeToBuffer());
        return Block.fromData(node_.writeToBuffer(), format: 'dag-pb');
      }

      final chunk1 = Uint8List.fromList(
        List<int>.generate(300 * 1024, (i) => i & 0xff),
      );
      final chunk2 = Uint8List.fromList(
        List<int>.generate(100 * 1024, (i) => (i * 3) & 0xff),
      );
      final leaf1 = await leaf(chunk1);
      final leaf2 = await leaf(chunk2);

      final rootUnixfs = unixfs_pb.Data(
        type: unixfs_pb.Data_DataType.File,
        filesize: Int64(chunk1.length + chunk2.length),
        blocksizes: [Int64(chunk1.length), Int64(chunk2.length)],
      );
      final rootNode = dag_pb.PBNode(
        data: rootUnixfs.writeToBuffer(),
        links: [
          dag_pb.PBLink(
            hash: leaf1.cid.toBytes(),
            size: Int64(leaf1.data.length),
          ),
          dag_pb.PBLink(
            hash: leaf2.cid.toBytes(),
            size: Int64(leaf2.data.length),
          ),
        ],
      );
      final root = await Block.fromData(
        rootNode.writeToBuffer(),
        format: 'dag-pb',
      );

      await node.blockStore.putBlock(leaf1);
      await node.blockStore.putBlock(leaf2);
      await node.blockStore.putBlock(root);

      final expected = Uint8List.fromList([...chunk1, ...chunk2]);
      expect(await node.cat(root.cid.encode()), equals(expected));
    });

    test('utf8 text survives a round-trip', () async {
      const text = 'héllo wörld — ünïcode ✓';
      final cid = await node.addFile(Uint8List.fromList(utf8.encode(text)));
      final back = await node.cat(cid);
      expect(utf8.decode(back!), equals(text));
    });
  });
}
