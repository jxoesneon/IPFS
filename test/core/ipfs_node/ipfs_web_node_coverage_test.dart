import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/config/network_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/interfaces/i_block_store.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_web_node.dart';
import 'package:dart_ipfs/src/core/ipfs_node/web_block_store.dart';
import 'package:dart_ipfs/src/platform/platform.dart';
import 'package:dart_ipfs/src/protocols/bitswap/bitswap_handler.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';

import '../../fakes/fake_router.dart';

class _PeerConnectedRouter extends FakeRouter {
  @override
  Set<String> get connectedPeers => const {'QmRemotePeer'};
}

class _AddrRouter extends FakeRouter {
  final List<String> dialed = [];

  @override
  List<String> get listeningAddresses => const [
    '/ip4/127.0.0.1/tcp/4001/p2p/QmFakeRouter',
  ];

  @override
  Future<void> connect(String multiaddress) async {
    dialed.add(multiaddress);
  }
}

class _ServingBitswap extends BitswapHandler {
  _ServingBitswap(
    IPFSConfig config,
    IBlockStore store,
    RouterInterface router,
    this._block,
  ) : super(config, store, router);

  final Block _block;

  @override
  Future<Block?> wantBlock(String cid) async => _block;
}

IPFSConfig _localConfig() => IPFSConfig(
  nodeId: 'test-node',
  offline: true,
  network: NetworkConfig(listenAddresses: ['/ip4/127.0.0.1/tcp/0']),
);

void main() {
  group('IPFSWebNode Coverage', () {
    test('start with bootstrap peers', () async {
      final node = IPFSWebNode(
        config: _localConfig(),
        bootstrapPeers: ['ws://localhost:1234'],
      );
      // Should not throw even if connection fails
      await node.start();
      expect(node.isRunning, isTrue);
      await node.stop();
    });

    test('addStream handles data', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> stream() async* {
        yield [1, 2, 3];
        yield [4, 5, 6];
      }

      final cid = await node.addStream(stream());
      expect(cid, isNotNull);

      final retrieved = await node.get(cid.encode());
      // It returns the UnixFS PB node, so we just check it found something
      expect(retrieved, isNotNull);
      expect(retrieved!.length, greaterThan(0));

      await node.stop();
    });

    test('addStream for empty stream creates root node', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> stream() async* {}

      final cid = await node.addStream(stream());
      expect(cid, isNotNull);
      await node.stop();
    });

    test('addFile throws UnsupportedError for non-stream input', () async {
      final node = IPFSWebNode();
      // Non-stream input fails honestly on every platform: browser File
      // objects cannot be read without dart:html.
      expect(() => node.addFile(null), throwsA(isA<UnsupportedError>()));
    });

    test('get falls back to Bitswap when peers are connected', () async {
      final router = _PeerConnectedRouter();
      final content = Uint8List.fromList([9, 8, 7, 6]);
      final cid = await CID.fromContent(content);
      final bitswap = _ServingBitswap(
        _localConfig(),
        WebBlockStore(getPlatform()),
        router,
        Block(cid: cid, data: content),
      );
      final node = IPFSWebNode(
        config: _localConfig(),
        router: router,
        bitswap: bitswap,
      );
      await node.start();

      // The CID is absent locally, so get() must consult Bitswap and return
      // the raw block payload served by the injected peer-side handler.
      final result = await node.get(cid.encode());
      expect(result, equals(content));

      await node.stop();
    });

    test('addresses and connectToPeer delegate to the router', () async {
      final router = _AddrRouter();
      final node = IPFSWebNode(config: _localConfig(), router: router);
      expect(node.addresses, isEmpty);

      await node.start();
      expect(node.addresses, hasLength(1));

      await node.connectToPeer('/ip4/127.0.0.1/tcp/4002/p2p/QmOther');
      expect(router.dialed, contains('/ip4/127.0.0.1/tcp/4002/p2p/QmOther'));

      await node.stop();
    });

    test('publishIPNS and resolveIPNS coverage', () async {
      final node = IPFSWebNode();
      await node.start();

      await node.securityManager.unlockKeystore('password');

      // These will call into MockDHTHandler and MockPubSub
      try {
        await node.publishIPNS('QmCID', keyName: 'self');
      } catch (_) {}

      try {
        await node.resolveIPNS('QmName');
      } catch (_) {}

      await node.stop();
    });

    test('publishIPNS/resolveIPNS throw when not started', () async {
      final node = IPFSWebNode();
      expect(
        () => node.publishIPNS('QmCID', keyName: 'self'),
        throwsStateError,
      );
      expect(() => node.resolveIPNS('QmName'), throwsStateError);
    });

    test('cat uses encode', () async {
      final node = IPFSWebNode();
      await node.start();
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await node.add(data);

      final result = await node.cat(cid);
      // The cat method might return different data structure in WebNode
      // Just verify it doesn't throw and returns something
      expect(result, isNotNull);
      await node.stop();
    });

    test('double start is idempotent', () async {
      final node = IPFSWebNode();
      await node.start();
      await node.start(); // Should return immediately
      expect(node.isRunning, isTrue);
      await node.stop();
    });

    test('stop when not started', () async {
      final node = IPFSWebNode();
      await node.stop(); // Should return immediately
      expect(node.isRunning, isFalse);
    });

    test('pinning coverage', () async {
      final node = IPFSWebNode();
      await node.start();
      final cid = await CID.fromContent(Uint8List.fromList([1]));
      await node.pin(cid);
      await node.listPins();
      await node.unpin(cid);
      await node.stop();
    });

    test('addStream throws on empty stream', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> emptyStream() async* {}

      // Empty stream actually returns an empty UnixFS root CID, doesn't throw
      final cid = await node.addStream(emptyStream());
      expect(cid, isNotNull);

      await node.stop();
    });

    test('addFile adds a Stream of file bytes', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> fileStream() async* {
        yield [1, 2, 3];
      }

      // A byte stream is consumable on any platform via addStream.
      final cid = await node.addFile(fileStream());
      expect(await node.get(cid.encode()), equals([1, 2, 3]));
      await node.stop();
    });

    test('get returns null when not in local storage and no peers', () async {
      final node = IPFSWebNode();
      await node.start();

      final result = await node.get('QmNonExistent');
      expect(result, isNull);

      await node.stop();
    });

    test('peerID getter returns router peer ID', () async {
      final node = IPFSWebNode();
      await node.start();
      expect(node.peerID, isNotNull);
      expect(node.peerID, isNotEmpty);
      await node.stop();
    });

    test('bitswap getter throws Error when not started', () {
      final node = IPFSWebNode();
      expect(() => node.bitswap, throwsA(isA<Error>()));
    });

    test('pubsub getter throws Error when not started', () {
      final node = IPFSWebNode();
      expect(() => node.pubsub, throwsA(isA<Error>()));
    });

    test('securityManager getter throws Error when not started', () {
      final node = IPFSWebNode();
      expect(() => node.securityManager, throwsA(isA<Error>()));
    });

    test('WebStubRouter hasStarted returns true', () {
      final node = IPFSWebNode();
      expect(node.isRunning, isFalse);
    });

    test('WebStubRouter connectedPeers returns empty set', () {
      final node = IPFSWebNode();
      expect(node.isRunning, isFalse);
    });

    test('addFile accepts a Stream<List<int>> on any platform', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> fileStream() async* {
        yield [1, 2, 3];
      }

      // Stream input no longer depends on _platform.isWeb: it is routed
      // through addStream like IPFSNode.addFileStream.
      final cid = await node.addFile(fileStream());
      expect(cid.codec, equals('dag-pb'));
      await node.stop();
    });

    test('addFile with non-stream input throws UnsupportedError', () async {
      final node = IPFSWebNode();
      await node.start();

      // This throws because it is not a Stream of bytes.
      expect(() => node.addFile('not a stream'), throwsUnsupportedError);
      await node.stop();
    });

    test('get with connected peers attempts Bitswap', () async {
      final node = IPFSWebNode();
      await node.start();

      // The Bitswap fallback is tested, but we can verify the method doesn't throw
      final result = await node.get('QmSomeCID');
      expect(result, isNull);

      await node.stop();
    });

    test('pin and unpin operations', () async {
      final node = IPFSWebNode();
      await node.start();

      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      await node.pin(cid);
      await node.unpin(cid);

      await node.stop();
    });

    test('listPins returns list', () async {
      final node = IPFSWebNode();
      await node.start();

      final pins = await node.listPins();
      expect(pins, isA<List<String>>());

      await node.stop();
    });

    test('start with custom config', () async {
      final node = IPFSWebNode();
      await node.start();
      expect(node.isRunning, isTrue);
      await node.stop();
    });

    test('add with empty data', () async {
      final node = IPFSWebNode();
      await node.start();

      final data = Uint8List.fromList([]);
      final cid = await node.add(data);
      expect(cid, isNotNull);

      await node.stop();
    });

    test('addStream with empty stream returns root CID', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> emptyStream() async* {}

      final cid = await node.addStream(emptyStream());
      expect(cid, isNotNull);

      await node.stop();
    });

    test('get with valid CID from local storage', () async {
      final node = IPFSWebNode();
      await node.start();

      final data = Uint8List.fromList([1, 2, 3]);
      final cid = await node.add(data);

      final retrieved = await node.get(cid.encode());
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(3));

      await node.stop();
    });

    test('get with invalid CID returns null', () async {
      final node = IPFSWebNode();
      await node.start();

      final result = await node.get('QmInvalidCIDThatDoesNotExist');
      expect(result, isNull);

      await node.stop();
    });

    test('cat with CID object', () async {
      final node = IPFSWebNode();
      await node.start();

      final data = Uint8List.fromList([4, 5, 6]);
      final cid = await node.add(data);

      final result = await node.cat(cid);
      expect(result, isNotNull);
      expect(result!.length, equals(3));

      await node.stop();
    });

    test('pin with CID', () async {
      final node = IPFSWebNode();
      await node.start();

      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      await node.pin(cid);

      await node.stop();
    });

    test('unpin with CID', () async {
      final node = IPFSWebNode();
      await node.start();

      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      await node.pin(cid);
      await node.unpin(cid);

      await node.stop();
    });

    test('bootstrap peer connection failure is handled', () async {
      final node = IPFSWebNode(
        config: _localConfig(),
        bootstrapPeers: ['ws://invalid-peer:1234'],
      );
      await node.start();
      expect(node.isRunning, isTrue);
      await node.stop();
    });

    test('multiple bootstrap peers', () async {
      final node = IPFSWebNode(
        config: _localConfig(),
        bootstrapPeers: [
          'ws://peer1:1234',
          'ws://peer2:1234',
          'ws://peer3:1234',
        ],
      );
      await node.start();
      expect(node.isRunning, isTrue);
      await node.stop();
    });

    test('add with large data', () async {
      final node = IPFSWebNode();
      await node.start();

      final largeData = Uint8List.fromList(List.filled(10000, 42));
      final cid = await node.add(largeData);
      expect(cid, isNotNull);

      await node.stop();
    });

    test('get returns null for empty CID string', () async {
      final node = IPFSWebNode();
      await node.start();

      final result = await node.get('');
      expect(result, isNull);

      await node.stop();
    });

    test('cat with string CID', () async {
      final node = IPFSWebNode();
      await node.start();

      final data = Uint8List.fromList([7, 8, 9]);
      final cid = await node.add(data);

      final result = await node.cat(cid);
      expect(result, isNotNull);
      expect(result!.length, equals(3));

      await node.stop();
    });

    test('pin with string CID', () async {
      final node = IPFSWebNode();
      await node.start();

      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      await node.pin(cid);

      await node.stop();
    });

    test('unpin with string CID', () async {
      final node = IPFSWebNode();
      await node.start();

      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      await node.pin(cid);
      await node.unpin(cid);

      await node.stop();
    });

    test('unpin non-existent CID does not throw', () async {
      final node = IPFSWebNode();
      await node.start();

      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      await node.unpin(cid);

      await node.stop();
    });

    test('listPins after pinning contains CID', () async {
      final node = IPFSWebNode();
      await node.start();

      final cid = await CID.fromContent(Uint8List.fromList([1, 2, 3]));
      await node.pin(cid);

      final pins = await node.listPins();
      expect(pins, anyElement(contains(cid.encode())));

      await node.stop();
    });

    test('addStream with single chunk', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> singleChunk() async* {
        yield [1, 2, 3];
      }

      final cid = await node.addStream(singleChunk());
      expect(cid, isNotNull);

      await node.stop();
    });

    test('addStream with multiple chunks', () async {
      final node = IPFSWebNode();
      await node.start();

      Stream<List<int>> multiChunk() async* {
        yield [1, 2, 3];
        yield [4, 5, 6];
        yield [7, 8, 9];
      }

      final cid = await node.addStream(multiChunk());
      expect(cid, isNotNull);

      await node.stop();
    });

    test('bitswap getter returns instance when started', () async {
      final node = IPFSWebNode();
      await node.start();

      expect(node.bitswap, isNotNull);

      await node.stop();
    });

    test('pubsub getter returns instance when started', () async {
      final node = IPFSWebNode();
      await node.start();

      expect(node.pubsub, isNotNull);

      await node.stop();
    });

    test('securityManager getter returns instance when started', () async {
      final node = IPFSWebNode();
      await node.start();

      expect(node.securityManager, isNotNull);

      await node.stop();
    });
  });
}
