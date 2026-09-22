// test/protocols/dht/dht_provide_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/core/blockstore.pb.dart';
import 'package:dart_ipfs/src/proto/generated/core/dag.pb.dart' as dag_pb;
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/provide_result.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:fixnum/fixnum.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';

/// A router whose sends never complete until [release] is called, so tests
/// can hold a provide in flight while exercising the queue.
class _BlockingRouter extends FakeRouter {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) => _gate.future;
}

/// A router whose sends always fail.
class _FailingRouter extends FakeRouter {
  @override
  Future<void> sendMessage(
    String peerIdStr,
    Uint8List message, {
    String? protocolId,
  }) async {
    throw StateError('send failed');
  }
}

/// A handler whose [provideDetailed] throws, so the queue processor's error
/// propagation path can be exercised.
class _ExplodingProvideHandler extends DHTHandler {
  // DHTHandler's router parameter is a private field formal and cannot be a
  // super-parameter, so this constructor forwards explicitly.
  // ignore: use_super_parameters
  _ExplodingProvideHandler(
    IPFSConfig config,
    RouterInterface router,
    NetworkHandler networkHandler, {
    MemoryDatastore? storage,
  }) : super(config, router, networkHandler, storage: storage);

  @override
  Future<ProvideResult> provideDetailed(
    CID cid, {
    bool recursive = false,
    Duration? timeout,
    BlockStore? blockStore,
    bool recordMetrics = true,
  }) {
    throw StateError('simulated provide explosion');
  }
}

/// A block store whose [getBlock] always throws, so the DAG enumeration
/// error path can be exercised.
class _FailingGetBlockStore extends BlockStore {
  _FailingGetBlockStore() : super(path: '');

  @override
  Future<GetBlockResponse> getBlock(String cid) async {
    throw StateError('simulated blockstore read failure');
  }
}

void main() {
  late Directory tempDir;
  late BlockStore blockStore;
  late MemoryDatastore datastore;
  late IPFSConfig nodeConfig;
  late MetricsCollector metrics;

  DHTHandler makeHandler(FakeRouter router) {
    final networkHandler = NetworkHandler(nodeConfig, router: router);
    return DHTHandler(
      nodeConfig,
      router,
      networkHandler,
      storage: datastore,
      metrics: metrics,
    );
  }

  Future<CID> addBlock(Uint8List data) async {
    final block = await Block.fromData(data);
    await blockStore.putBlock(block);
    return block.cid;
  }

  /// Builds a dag-pb root block linking to [child] and stores both.
  Future<CID> addLinkedDag(CID child) async {
    final pbNode = dag_pb.PBNode(
      links: [
        dag_pb.PBLink(
          name: 'child',
          hash: child.toBytes(),
          size: Int64(child.toBytes().length),
        ),
      ],
    );
    final data = pbNode.writeToBuffer();
    final rootCid = await CID.fromContent(data, codec: 'dag-pb');
    await blockStore.putBlock(
      Block(cid: rootCid, data: data, format: 'dag-pb'),
    );
    return rootCid;
  }

  Future<void> seedPeer(DHTHandler handler, int fill) async {
    final peer = PeerId(
      value: Uint8List.fromList(List.generate(32, (i) => (i + fill) & 0xFF)),
    );
    await handler.dhtClient.kademliaRoutingTable.addPeer(peer, peer);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dht_provide_test_');
    blockStore = BlockStore(path: tempDir.path);
    await blockStore.start();
    datastore = MemoryDatastore();
    await datastore.init();
    nodeConfig = IPFSConfig(
      dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
    );
    metrics = MetricsCollector(
      IPFSConfig(metrics: const MetricsConfig(enabled: false)),
    );
  });

  tearDown(() async {
    await blockStore.stop();
    await datastore.close();
    await tempDir.delete(recursive: true);
  });

  group('DHTHandler.provideDetailed', () {
    test('reports per-peer attempts and successes', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);
      await seedPeer(handler, 200);

      final cid = await addBlock(Uint8List.fromList([1, 2, 3]));
      final result = await handler.provideDetailed(cid);

      expect(result.cid.toString(), equals(cid.toString()));
      expect(result.attempts, greaterThan(0));
      expect(result.successes, equals(result.attempts));
      expect(result.failures, equals(0));
      expect(result.success, isTrue);
      // The self provider record is tracked locally.
      expect(handler.getLocalProvidersForCid(cid.toString()), isNotEmpty);
    });

    test('reports failures without throwing', () async {
      final handler = makeHandler(_FailingRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);

      final cid = await addBlock(Uint8List.fromList([4, 5, 6]));
      final result = await handler.provideDetailed(cid);

      expect(result.attempts, greaterThan(0));
      expect(result.successes, equals(0));
      expect(result.failures, equals(result.attempts));
      expect(result.success, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('empty routing table is a successful no-op', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();

      final cid = await addBlock(Uint8List.fromList([7, 8, 9]));
      final result = await handler.provideDetailed(cid);

      expect(result.attempts, equals(0));
      expect(result.failures, equals(0));
      expect(result.success, isTrue);
    });

    test('recursive provides all blocks in a local DAG', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);

      final child = await addBlock(Uint8List.fromList([10, 11, 12]));
      final root = await addLinkedDag(child);

      final result = await handler.provideDetailed(
        root,
        recursive: true,
        blockStore: blockStore,
      );

      expect(result.cidsAnnounced, equals(2));
      expect(result.success, isTrue);
      expect(handler.getLocalProvidersForCid(root.toString()), isNotEmpty);
      expect(handler.getLocalProvidersForCid(child.toString()), isNotEmpty);
    });

    test('recursive without a blockstore announces only the root', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();

      final cid = await addBlock(Uint8List.fromList([13, 14, 15]));
      final result = await handler.provideDetailed(cid, recursive: true);

      expect(result.cidsAnnounced, equals(1));
      expect(result.errors, contains(contains('without blockstore')));
    });

    test('timeout aborts remaining attempts with partial results', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);

      final cid = await addBlock(Uint8List.fromList([16, 17, 18]));
      final result = await handler.provideDetailed(cid, timeout: Duration.zero);

      expect(result.attempts, equals(0));
      expect(result.errors, contains(contains('timeout')));
    });

    test('uninitialized client surfaces as a failed result', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      // Deliberately do not initialize the DHT client.

      final cid = await addBlock(Uint8List.fromList([19, 20, 21]));
      final result = await handler.provideDetailed(cid);

      expect(result.success, isFalse);
      expect(result.failures, greaterThan(0));
      expect(result.errors, isNotEmpty);
    });

    test('recursive provide records blocks missing from the store', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();

      // The root CID's block is intentionally absent from the store.
      final missing = await CID.fromContent(
        Uint8List.fromList([40, 41, 42]),
        codec: 'dag-pb',
      );
      final result = await handler.provideDetailed(
        missing,
        recursive: true,
        blockStore: blockStore,
      );

      expect(result.errors, contains(contains('missing block')));
    });

    test('recursive provide records enumeration failures', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();

      final cid = await addBlock(Uint8List.fromList([43, 44, 45]));
      final result = await handler.provideDetailed(
        cid,
        recursive: true,
        blockStore: _FailingGetBlockStore(),
      );

      expect(result.errors, contains(contains('failed to enumerate')));
    });
  });

  group('DHTHandler provide queue', () {
    test('enqueueProvide returns a position and drains the job', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);

      final cid = await addBlock(Uint8List.fromList([22, 23, 24]));
      final position = handler.enqueueProvide(cid);
      expect(position, equals(1));

      // Wait for the queue to drain.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (handler.provideQueueLength > 0 || handler.provideQueueProcessing) {
        if (DateTime.now().isAfter(deadline)) {
          fail('provide queue did not drain');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(handler.getLocalProvidersForCid(cid.toString()), isNotEmpty);
    });

    test('enqueueProvideAndWait completes with the result', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);

      final cid = await addBlock(Uint8List.fromList([25, 26, 27]));
      final result = await handler.enqueueProvideAndWait(cid);

      expect(result.cid.toString(), equals(cid.toString()));
      expect(result.attempts, greaterThan(0));
    });

    test('returns null when the queue is full', () async {
      final router = _BlockingRouter();
      final handler = makeHandler(router);
      addTearDown(() async {
        router.release();
        await handler.stop();
      });
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);

      final cid = await addBlock(Uint8List.fromList([28, 29, 30]));

      // First job blocks inside sendMessage, keeping the processor busy.
      handler.enqueueProvide(cid);
      // Wait until the processor has dequeued the first job and is blocked
      // on the router gate.
      final startDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (!(handler.provideQueueProcessing &&
          handler.provideQueueLength == 0)) {
        if (DateTime.now().isAfter(startDeadline)) {
          fail('provide queue processor never started');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      for (var i = 0; i < DHTHandler.maxProvideQueueSize; i++) {
        handler.enqueueProvide(cid);
      }
      expect(handler.enqueueProvide(cid), isNull);
    });

    test(
      'enqueueProvideAndWait throws StateError when the queue is full',
      () async {
        final router = _BlockingRouter();
        final handler = makeHandler(router);
        addTearDown(() async {
          router.release();
          await handler.stop();
        });
        await handler.dhtClient.initialize();
        await seedPeer(handler, 1);

        final cid = await addBlock(Uint8List.fromList([31, 32, 33]));

        // First job blocks inside sendMessage, keeping the processor busy.
        handler.enqueueProvide(cid);
        final startDeadline = DateTime.now().add(const Duration(seconds: 5));
        while (!(handler.provideQueueProcessing &&
            handler.provideQueueLength == 0)) {
          if (DateTime.now().isAfter(startDeadline)) {
            fail('provide queue processor never started');
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        for (var i = 0; i < DHTHandler.maxProvideQueueSize; i++) {
          handler.enqueueProvide(cid);
        }
        expect(() => handler.enqueueProvideAndWait(cid), throwsStateError);
      },
    );

    test(
      'enqueueProvideAndWait propagates a job failure to the result',
      () async {
        final router = FakeRouter();
        final networkHandler = NetworkHandler(nodeConfig, router: router);
        final handler = _ExplodingProvideHandler(
          nodeConfig,
          router,
          networkHandler,
          storage: datastore,
        );
        addTearDown(handler.stop);

        final cid = await addBlock(Uint8List.fromList([34, 35, 36]));
        await expectLater(
          handler.enqueueProvideAndWait(cid),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('DHTClient.addProviderDetailed', () {
    test('timeout records an error and skips remaining attempts', () async {
      final handler = makeHandler(FakeRouter());
      addTearDown(handler.stop);
      await handler.dhtClient.initialize();
      await seedPeer(handler, 1);

      final cid = await addBlock(Uint8List.fromList([52, 53, 54]));
      final result = await handler.dhtClient.addProviderDetailed(
        cid.toString(),
        handler.dhtClient.peerId.toBase58(),
        timeout: Duration.zero,
      );

      expect(result.attempts, equals(0));
      expect(result.errors, contains(contains('timeout')));
    });
  });

  group('ProvideResult', () {
    test('toJson serializes every field', () async {
      final cid = await CID.fromContent(
        Uint8List.fromList([60, 61]),
        codec: 'raw',
      );
      final result = ProvideResult(
        cid: cid,
        attempts: 3,
        successes: 2,
        failures: 1,
        duration: const Duration(milliseconds: 42),
        errors: const ['boom'],
        cidsAnnounced: 7,
      );

      expect(
        result.toJson(),
        equals({
          'cid': cid.toString(),
          'attempts': 3,
          'successes': 2,
          'failures': 1,
          'duration_ms': 42,
          'errors': ['boom'],
          'cidsAnnounced': 7,
        }),
      );
    });

    test(
      'PendingProvide.result completes with an error via completeError',
      () async {
        final cid = await CID.fromContent(
          Uint8List.fromList([62, 63]),
          codec: 'raw',
        );
        final job = PendingProvide(cid: cid);
        job.completeError(StateError('boom'));

        await expectLater(job.result, throwsA(isA<StateError>()));
      },
    );
  });
}
