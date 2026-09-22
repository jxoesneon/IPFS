// test/services/gateway/gateway_hamt_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_directory.dart';
import 'package:dart_ipfs/src/core/unixfs/unixfs_hamt.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/proto/generated/unixfs/unixfs.pb.dart'
    as unixfs_pb;
import 'package:dart_ipfs/src/services/gateway/gateway_handler.dart';
import 'package:fixnum/fixnum.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// In-memory [BlockStore] so the HAMT builder can persist real shard and
/// leaf blocks that the gateway handler then resolves end to end.
class _MemoryBlockStore implements BlockStore {
  final _blocks = <String, Block>{};

  void add(Block block) => _blocks[block.cid.encode()] = block;

  void remove(String cid) => _blocks.remove(cid);

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    final block = _blocks[cid];
    if (block == null) {
      return GetBlockResponse()..found = false;
    }
    return GetBlockResponse()
      ..found = true
      ..block = block.toProto();
  }

  @override
  Future<AddBlockResponse> putBlock(Block block) async {
    add(block);
    return AddBlockResponse()..success = true;
  }

  @override
  Future<bool> hasBlock(String cid) async => _blocks.containsKey(cid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('GatewayHandler HAMT directories', () {
    late _MemoryBlockStore store;
    late GatewayHandler handler;

    setUp(() {
      store = _MemoryBlockStore();
      handler = GatewayHandler(store);
    });

    Future<Block> rawFile(List<int> bytes) async {
      final block = await Block.fromData(
        Uint8List.fromList(bytes),
        format: 'raw',
      );
      await store.putBlock(block);
      return block;
    }

    /// Builds a real HAMT-sharded directory whose blocks live in [store].
    Future<Block> hamtDir(Map<String, Block> files) async {
      final entries = <UnixFSDirectoryEntry>[
        for (final e in files.entries)
          UnixFSDirectoryEntry(
            name: e.key,
            cid: e.value.cid,
            tsize: e.value.data.length,
          ),
      ];
      final node = await UnixFSHAMTBuilder(
        fanout: 256,
        shardThreshold: 0,
        maxBucketSize: 1,
      ).build(store, entries);
      expect(node.isHAMTShard, isTrue);
      return Block(cid: node.cid, data: node.data, format: 'dag-pb');
    }

    /// Returns a name whose level-0 bucket index equals [target].
    String nameForBucket(int target) {
      for (var i = 0; ; i++) {
        final name = 'k$i.txt';
        final digest = murmur3X64Hash64Digest(utf8.encode(name));
        if (hamtBucketIndex(digest, 0, 8) == target) return name;
      }
    }

    /// Returns two names that share a level-0 bucket, forcing the builder
    /// to place them in a child shard.
    (String, String) collidingPair() {
      final byBucket = <int, String>{};
      for (var i = 0; ; i++) {
        final name = 'c$i.txt';
        final digest = murmur3X64Hash64Digest(utf8.encode(name));
        final idx = hamtBucketIndex(digest, 0, 8);
        final first = byBucket[idx];
        if (first != null) return (first, name);
        byBucket[idx] = name;
      }
    }

    /// Hand-builds a HAMT shard block with the given [links].
    Future<Block> shardBlock(List<dag_pb.PBLink> links) {
      final node = dag_pb.PBNode(
        data: unixfs_pb.Data(
          type: unixfs_pb.Data_DataType.HAMTShard,
          data: Uint8List(256 ~/ 8),
          hashType: Int64(kUnixFSHAMTHashType),
          fanout: Int64(256),
        ).writeToBuffer(),
        links: links,
      );
      return Block.fromData(node.writeToBuffer(), format: 'dag-pb');
    }

    Future<Response> get(String cidStr, [String subPath = '']) {
      return handler.handlePath(
        Request('GET', Uri.parse('http://localhost/ipfs/$cidStr$subPath')),
      );
    }

    test('serves a file inside a HAMT-sharded directory', () async {
      final file = await rawFile('hello hamt'.codeUnits);
      final root = await hamtDir({'hello.txt': file});

      final response = await get(root.cid.encode(), '/hello.txt');
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      expect(body, equals('hello hamt'.codeUnits));
    });

    test('returns 404 for a missing name in a HAMT shard', () async {
      final file = await rawFile('x'.codeUnits);
      final root = await hamtDir({'present.txt': file});

      final response = await get(root.cid.encode(), '/absent.txt');
      expect(response.statusCode, equals(404));
      expect(await response.readAsString(), contains('Path not found'));
    });

    test('resolves an entry that lives in a sub-shard', () async {
      final (a, b) = collidingPair();
      final fileA = await rawFile('first'.codeUnits);
      final fileB = await rawFile('second'.codeUnits);
      final root = await hamtDir({a: fileA, b: fileB});

      // Sanity check: the shared bucket produced a child shard link whose
      // name is exactly the 2-char hash prefix.
      final rootNode = dag_pb.PBNode.fromBuffer(root.data);
      expect(rootNode.links.any((l) => l.name.length == 2), isTrue);

      for (final (name, want) in [(a, 'first'), (b, 'second')]) {
        final response = await get(root.cid.encode(), '/$name');
        expect(response.statusCode, equals(200));
        expect(await response.readAsString(), equals(want));
      }
    });

    test('serves index.html from a HAMT root', () async {
      final index = await rawFile('<html>hamt index</html>'.codeUnits);
      final other = await rawFile('other'.codeUnits);
      final root = await hamtDir({'index.html': index, 'other.txt': other});

      final response = await get(root.cid.encode(), '/');
      expect(response.statusCode, equals(200));
      final body = await response.read().expand((i) => i).toList();
      expect(body, equals('<html>hamt index</html>'.codeUnits));
    });

    test(
      'renders a prefix-stripped listing for a HAMT root without index.html',
      () async {
        final file = await rawFile('x'.codeUnits);
        final root = await hamtDir({'visible.txt': file});

        final response = await get(root.cid.encode(), '/');
        expect(response.statusCode, equals(200));
        final body = await response.readAsString();
        expect(body, contains('visible.txt'));
        // The raw link name carries a 2-char hash prefix that must not
        // leak into the rendered listing.
        expect(body, isNot(contains('>00visible.txt')));
      },
    );

    test('redirects a HAMT root without a trailing slash', () async {
      final file = await rawFile('x'.codeUnits);
      final root = await hamtDir({'a.txt': file});

      final response = await get(root.cid.encode());
      expect(response.statusCode, equals(301));
      expect(
        response.headers['location'],
        endsWith('/ipfs/${root.cid.encode()}/'),
      );
    });

    test('missing sub-shard block returns 500', () async {
      // A sub-shard link (name == 2-char bucket prefix) whose block is not
      // in the store must fail traversal rather than serve raw bytes.
      final name = nameForBucket(0xAB);
      final absent = await Block.fromData(Uint8List.fromList('gone'.codeUnits));
      final root = await shardBlock([
        dag_pb.PBLink(name: 'AB', hash: absent.cid.toBytes()),
      ]);
      store.add(root);

      final response = await get(root.cid.encode(), '/$name');
      expect(response.statusCode, equals(500));
      expect(
        await response.readAsString(),
        contains('Missing HAMT sub-shard block'),
      );
    });

    test('sub-shard link pointing at a non-shard returns 500', () async {
      final name = nameForBucket(0xCD);
      final notAShard = await rawFile('leaf'.codeUnits);
      final root = await shardBlock([
        dag_pb.PBLink(name: 'CD', hash: notAShard.cid.toBytes()),
      ]);
      store.add(root);

      final response = await get(root.cid.encode(), '/$name');
      expect(response.statusCode, equals(500));
      expect(await response.readAsString(), contains('not a shard'));
    });

    test('leaf link resolving to a missing block returns 404', () async {
      // Leaf link name is <2-char prefix> + entry name; the target block is
      // absent so _serveContent reports 404.
      final name = nameForBucket(0x7E);
      final digest = murmur3X64Hash64Digest(utf8.encode(name));
      final prefix = hamtBucketIndex(
        digest,
        0,
        8,
      ).toRadixString(16).toUpperCase().padLeft(2, '0');
      expect(prefix, equals('7E'));

      final absent = await Block.fromData(Uint8List.fromList([1, 2, 3]));
      final root = await shardBlock([
        dag_pb.PBLink(name: '$prefix$name', hash: absent.cid.toBytes()),
      ]);
      store.add(root);

      final response = await get(root.cid.encode(), '/$name');
      expect(response.statusCode, equals(404));
      expect(await response.readAsString(), contains('Block not found'));
    });

    test('link name shorter than the HAMT prefix fails the listing', () async {
      final entry = await rawFile('x'.codeUnits);
      // Fanout 256 → 2-char prefix; a 1-char link name is invalid.
      final root = await shardBlock([
        dag_pb.PBLink(name: 'Z', hash: entry.cid.toBytes()),
      ]);
      store.add(root);

      final response = await get(root.cid.encode(), '/');
      expect(response.statusCode, equals(500));
      expect(
        await response.readAsString(),
        contains('shorter than the 2-char prefix'),
      );
    });

    test('serves index.html that lives in a sub-shard', () async {
      // index.html's level-0 bucket holds a child shard, so the lookup
      // must descend one level before finding the leaf entry.
      final index = await rawFile('<html>deep index</html>'.codeUnits);
      final digest = murmur3X64Hash64Digest(utf8.encode('index.html'));
      // hamtBucketIndex takes a bit offset: level N uses bits [8N, 8N+8).
      String prefix(int level) => hamtBucketIndex(
        digest,
        level * 8,
        8,
      ).toRadixString(16).toUpperCase().padLeft(2, '0');

      final subShard = await shardBlock([
        dag_pb.PBLink(
          name: '${prefix(1)}index.html',
          hash: index.cid.toBytes(),
        ),
      ]);
      store.add(subShard);
      final root = await shardBlock([
        dag_pb.PBLink(name: prefix(0), hash: subShard.cid.toBytes()),
      ]);
      store.add(root);

      final response = await get(root.cid.encode(), '/');
      expect(response.statusCode, equals(200));
      expect(await response.readAsString(), equals('<html>deep index</html>'));
    });

    test('renders a listing that traverses sub-shards', () async {
      // The root shard mixes a top-level leaf with a sub-shard link; the
      // listing must descend and strip each level's hash prefix.
      final file = await rawFile('deep'.codeUnits);
      final subShard = await shardBlock([
        dag_pb.PBLink(name: '11nested.txt', hash: file.cid.toBytes()),
      ]);
      store.add(subShard);

      // Keep the sub-shard link name away from index.html's level-0
      // bucket so the index lookup terminates immediately.
      final indexBucket = hamtBucketIndex(
        murmur3X64Hash64Digest(utf8.encode('index.html')),
        0,
        8,
      );
      final subName = ((indexBucket + 1) & 0xFF)
          .toRadixString(16)
          .toUpperCase()
          .padLeft(2, '0');
      final root = await shardBlock([
        dag_pb.PBLink(name: subName, hash: subShard.cid.toBytes()),
        dag_pb.PBLink(name: '22toplevel.txt', hash: file.cid.toBytes()),
      ]);
      store.add(root);

      final response = await get(root.cid.encode(), '/');
      expect(response.statusCode, equals(200));
      final body = await response.readAsString();
      expect(body, contains('toplevel.txt'));
      expect(body, contains('nested.txt'));
      // Neither level's hash prefix may leak into the rendered names.
      expect(body, isNot(contains('>22toplevel.txt')));
      expect(body, isNot(contains('>11nested.txt')));
    });

    test('HAMT listing beyond the node cap returns 500', () async {
      // A linear chain of sub-shards longer than the traversal cap must
      // abort with an error instead of walking the whole DAG.
      final indexBucket = hamtBucketIndex(
        murmur3X64Hash64Digest(utf8.encode('index.html')),
        0,
        8,
      );
      final rootLinkName = ((indexBucket + 1) & 0xFF)
          .toRadixString(16)
          .toUpperCase()
          .padLeft(2, '0');

      // Build the chain tail-first so each parent knows its child's CID.
      final tail = await shardBlock(<dag_pb.PBLink>[]);
      store.add(tail);
      var childCid = tail.cid;
      for (var i = 0; i < 10001; i++) {
        final isRoot = i == 10000;
        final block = await shardBlock([
          dag_pb.PBLink(
            name: isRoot ? rootLinkName : 'AA',
            hash: childCid.toBytes(),
          ),
        ]);
        store.add(block);
        childCid = block.cid;
      }

      final response = await get(childCid.encode(), '/');
      expect(response.statusCode, equals(500));
      expect(
        await response.readAsString(),
        contains('HAMT listing exceeded maximum node count'),
      );
    });

    test('index.html chain ending in a HAMT honors the depth cap', () async {
      final index = await rawFile('leaf'.codeUnits);
      final hamt = await hamtDir({'index.html': index});

      // Chain of 8 plain directories, each index.html pointing at the next,
      // terminating at the HAMT root. The shard is reached at indexDepth 8
      // so the depth cap inside _serveHamtShard must fire.
      var childCid = hamt.cid;
      for (var i = 0; i < 8; i++) {
        final node = dag_pb.PBNode(
          data: unixfs_pb.Data(
            type: unixfs_pb.Data_DataType.Directory,
          ).writeToBuffer(),
          links: [dag_pb.PBLink(name: 'index.html', hash: childCid.toBytes())],
        );
        final block = await Block.fromData(
          node.writeToBuffer(),
          format: 'dag-pb',
        );
        store.add(block);
        childCid = block.cid;
      }

      final response = await get(childCid.encode(), '/');
      expect(response.statusCode, equals(500));
      expect(
        await response.readAsString(),
        contains('index.html resolution depth exceeded'),
      );
    });
  });
}
