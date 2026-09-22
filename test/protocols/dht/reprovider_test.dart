// test/protocols/dht/reprovider_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/core/security/denylist_service.dart';
import 'package:dart_ipfs/src/core/storage/datastore.dart' as ds;
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/reprovider.dart';
import 'package:dart_ipfs/src/protocols/dht/xor_distance_metric.dart';
import 'package:dart_ipfs/src/transport/router_interface.dart';
import 'package:test/test.dart';

import '../../fakes/fake_router.dart';
import '../../mocks/mock_dht_handler.dart';

/// A [DHTHandler] that records the order in which CIDs are provided, so
/// tests can assert the XOR-ordered sweep.
class _RecordingDHTHandler extends DHTHandler {
  // DHTHandler's router parameter is a private field formal and cannot be a
  // super-parameter, so this constructor forwards explicitly.
  // ignore: use_super_parameters
  _RecordingDHTHandler(
    IPFSConfig config,
    RouterInterface router,
    NetworkHandler networkHandler, {
    ds.Datastore? storage,
    DenylistService? denylistService,
  }) : super(
         config,
         router,
         networkHandler,
         storage: storage,
         denylistService: denylistService,
       );

  /// CIDs passed to [provideAll], in call order.
  final List<CID> providedOrder = [];

  @override
  Future<void> provideAll(List<CID> cids) async {
    providedOrder.addAll(cids);
    await super.provideAll(cids);
  }
}

void main() {
  late Directory tempDir;
  late BlockStore blockStore;
  late PinManager pinManager;
  late MemoryDatastore datastore;
  late MFSManager mfsManager;
  late MockDHTHandler dhtHandler;
  late MetricsCollector metrics;
  late DHTConfig config;
  late Reprovider reprovider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reprovider_test_');
    blockStore = BlockStore(path: tempDir.path);
    await blockStore.start();
    pinManager = blockStore.pinManager;

    datastore = MemoryDatastore();
    await datastore.init();
    mfsManager = MFSManager(blockStore, datastore);
    await mfsManager.start();

    dhtHandler = MockDHTHandler();
    await dhtHandler.start();

    metrics = MetricsCollector(
      IPFSConfig(metrics: const MetricsConfig(enabled: false)),
    );
  });

  tearDown(() async {
    await reprovider.stop();
    await mfsManager.stop();
    await blockStore.stop();
    await datastore.close();
    await tempDir.delete(recursive: true);
  });

  Reprovider createReprovider({DHTConfig? dhtConfig}) {
    config =
        dhtConfig ??
        const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'pinned',
          reproviderBatchSize: 100,
          reproviderConcurrency: 10,
          reproviderSweepOptimization: false,
        );
    return Reprovider(
      config: config,
      dhtHandler: dhtHandler,
      pinManager: pinManager,
      mfsManager: mfsManager,
      metrics: metrics,
    );
  }

  Future<CID> addBlock(Uint8List data) async {
    final block = await Block.fromData(data);
    await blockStore.putBlock(block);
    return block.cid;
  }

  Future<void> pinRecursive(CID cid) async {
    await pinManager.pinBlock(cid.toProto(), PinTypeProto.PIN_TYPE_RECURSIVE);
  }

  Future<void> pinDirect(CID cid) async {
    await pinManager.pinBlock(cid.toProto(), PinTypeProto.PIN_TYPE_DIRECT);
  }

  /// Replicates the reprovider's DHT routing key: SHA-256 of the multihash.
  PeerId routingKey(CID cid) {
    return PeerId(
      value: Uint8List.fromList(sha256.convert(cid.multihash.toBytes()).bytes),
    );
  }

  /// Replicates the reprovider's big-endian XOR distance.
  BigInt xorDistance(PeerId a, PeerId b) {
    return const XorDistanceMetric().calculateDistance(a, b);
  }

  group('Reprovider strategies', () {
    test('pinned strategy reprovides recursive pins', () async {
      final cid1 = await addBlock(Uint8List.fromList([1, 2, 3]));
      final cid2 = await addBlock(Uint8List.fromList([4, 5, 6]));
      await pinRecursive(cid1);
      await pinRecursive(cid2);

      reprovider = createReprovider();
      final result = await reprovider.trigger(wait: true);

      expect(result.strategy, equals('pinned'));
      expect(result.attempted, equals(2));
      expect(result.succeeded, equals(2));
      expect(result.failed, equals(0));
      expect(dhtHandler.getCallCount('provideAll'), equals(1));
    });

    test('roots strategy reprovides only top-level recursive pins', () async {
      // Simulate a root pin by pinning one block directly.
      final root = await addBlock(Uint8List.fromList([7, 8, 9]));
      await pinRecursive(root);

      reprovider = createReprovider(
        dhtConfig: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'roots',
          reproviderBatchSize: 100,
          reproviderConcurrency: 10,
          reproviderSweepOptimization: false,
        ),
      );
      final result = await reprovider.trigger(wait: true);

      expect(result.attempted, greaterThanOrEqualTo(1));
      expect(result.succeeded, equals(result.attempted));
      expect(dhtHandler.getCallCount('provideAll'), equals(1));
    });

    test('all strategy reprovides every block in the blockstore', () async {
      await addBlock(Uint8List.fromList([10, 11, 12]));
      await addBlock(Uint8List.fromList([13, 14, 15]));
      // The second block is not pinned, but should still be announced by the
      // all strategy.

      reprovider = createReprovider(
        dhtConfig: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'all',
          reproviderBatchSize: 100,
          reproviderConcurrency: 10,
          reproviderSweepOptimization: false,
        ),
      );
      final result = await reprovider.trigger(wait: true);

      // The blockstore contains the two added blocks plus the MFS root created
      // during setUp.
      expect(result.attempted, equals(3));
      expect(result.succeeded, equals(3));
      expect(dhtHandler.getCallCount('provideAll'), equals(1));
    });

    test('pinned+mfs strategy includes MFS root', () async {
      final cid = await addBlock(Uint8List.fromList([16, 17, 18]));
      await pinRecursive(cid);

      reprovider = createReprovider(
        dhtConfig: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'pinned+mfs',
          reproviderBatchSize: 100,
          reproviderConcurrency: 10,
          reproviderSweepOptimization: false,
        ),
      );
      final result = await reprovider.trigger(wait: true);

      expect(result.attempted, equals(2));
      expect(result.succeeded, equals(2));
      expect(dhtHandler.getCallCount('provideAll'), equals(1));
    });

    test('pinned strategy includes direct pins alongside recursive', () async {
      final recursiveCid = await addBlock(Uint8List.fromList([50, 51, 52]));
      final directCid = await addBlock(Uint8List.fromList([53, 54, 55]));
      await pinRecursive(recursiveCid);
      await pinDirect(directCid);

      reprovider = createReprovider();
      final result = await reprovider.trigger(wait: true);

      // Both the recursive and the direct pin are announced.
      expect(result.attempted, equals(2));
      expect(result.succeeded, equals(2));
    });

    test('entities strategy includes root pins and MFS root', () async {
      final root = await addBlock(Uint8List.fromList([19, 20, 21]));
      await pinRecursive(root);

      reprovider = createReprovider(
        dhtConfig: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'entities',
          reproviderBatchSize: 100,
          reproviderConcurrency: 10,
          reproviderSweepOptimization: false,
        ),
      );
      final result = await reprovider.trigger(wait: true);

      expect(result.attempted, equals(2));
      expect(result.succeeded, equals(2));
      expect(dhtHandler.getCallCount('provideAll'), equals(1));
    });
  });

  group('Reprovider sweep optimization', () {
    test(
      'groups CIDs by closest routing-table peers with a concrete DHTHandler',
      () async {
        // The sweep path requires the concrete DHTHandler so it can consult
        // the real Kademlia routing table.
        final router = FakeRouter();
        final nodeConfig = IPFSConfig(
          dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
        );
        final networkHandler = NetworkHandler(nodeConfig, router: router);
        final concreteDht = DHTHandler(
          nodeConfig,
          router,
          networkHandler,
          storage: datastore,
        );
        await concreteDht.dhtClient.initialize();
        addTearDown(() async {
          await concreteDht.stop();
        });

        // Seed the routing table so the grouping maps CIDs to a live peer.
        final closestPeer = PeerId(
          value: Uint8List.fromList(List.generate(32, (i) => i)),
        );
        await concreteDht.dhtClient.kademliaRoutingTable.addPeer(
          closestPeer,
          closestPeer,
        );

        final cid = await addBlock(Uint8List.fromList([31, 32, 33]));
        await pinRecursive(cid);

        reprovider = Reprovider(
          config: const DHTConfig(
            reproviderEnabled: false,
            reproviderStrategy: 'pinned',
            reproviderBatchSize: 100,
            reproviderConcurrency: 10,
            reproviderSweepOptimization: true,
          ),
          dhtHandler: concreteDht,
          pinManager: pinManager,
          mfsManager: mfsManager,
          metrics: metrics,
        );

        final result = await reprovider.trigger(wait: true);

        expect(result.groupedCids, isNotNull);
        expect(
          result.groupedCids!.keys.map((peer) => peer.toBase58()),
          contains(closestPeer.toBase58()),
        );
        expect(result.groupedCids![closestPeer], contains(cid));
        expect(result.succeeded, equals(result.attempted));
      },
    );

    test(
      'sweep provides CIDs in XOR-distance order from the local peer',
      () async {
        final router = FakeRouter();
        final nodeConfig = IPFSConfig(
          dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
        );
        final networkHandler = NetworkHandler(nodeConfig, router: router);
        final recordingHandler = _RecordingDHTHandler(
          nodeConfig,
          router,
          networkHandler,
          storage: datastore,
        );
        await recordingHandler.dhtClient.initialize();
        addTearDown(() async {
          await recordingHandler.stop();
        });

        final cids = <CID>[];
        for (var i = 0; i < 8; i++) {
          final cid = await addBlock(Uint8List.fromList([60, i, 61]));
          await pinRecursive(cid);
          cids.add(cid);
        }

        reprovider = Reprovider(
          config: const DHTConfig(
            reproviderEnabled: false,
            reproviderStrategy: 'pinned',
            reproviderBatchSize: 100,
            reproviderConcurrency: 10,
            reproviderSweepOptimization: true,
          ),
          dhtHandler: recordingHandler,
          pinManager: pinManager,
          mfsManager: mfsManager,
          metrics: metrics,
        );

        final result = await reprovider.trigger(wait: true);
        expect(result.succeeded, equals(result.attempted));

        // The provided order must match ascending XOR distance between each
        // CID's routing key and the local peer ID.
        final localPeerId = recordingHandler.dhtClient.peerId;
        final expected = [...cids]
          ..sort(
            (a, b) => xorDistance(
              routingKey(a),
              localPeerId,
            ).compareTo(xorDistance(routingKey(b), localPeerId)),
          );
        expect(
          recordingHandler.providedOrder.map((c) => c.toString()).toList(),
          expected.map((c) => c.toString()).toList(),
        );
      },
    );

    test(
      'falls back gracefully when the concrete DHT is not initialized',
      () async {
        final router = FakeRouter();
        final nodeConfig = IPFSConfig(
          dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
        );
        final networkHandler = NetworkHandler(nodeConfig, router: router);
        final uninitializedDht = DHTHandler(
          nodeConfig,
          router,
          networkHandler,
          storage: datastore,
        );
        // Deliberately do not initialize the DHT client — peerId and the
        // routing table are late fields that throw when read too early.
        addTearDown(() async {
          await uninitializedDht.stop();
        });

        final cid = await addBlock(Uint8List.fromList([37, 38, 39]));
        await pinRecursive(cid);

        reprovider = Reprovider(
          config: const DHTConfig(
            reproviderEnabled: false,
            reproviderStrategy: 'pinned',
            reproviderSweepOptimization: true,
          ),
          dhtHandler: uninitializedDht,
          pinManager: pinManager,
          mfsManager: mfsManager,
          metrics: metrics,
        );

        final result = await reprovider.trigger(wait: true);

        // XOR ordering and peer grouping both degrade gracefully; the
        // provide itself then fails on the uninitialized client, which the
        // batch loop reports rather than propagating.
        expect(result.groupedCids, isEmpty);
        expect(result.attempted, equals(1));
        expect(result.failed, equals(1));
        expect(result.errors, isNotEmpty);
      },
    );

    test('falls back to empty grouping with a non-concrete handler', () async {
      final cid = await addBlock(Uint8List.fromList([34, 35, 36]));
      await pinRecursive(cid);

      // MockDHTHandler implements IDHTHandler but is not a DHTHandler, so
      // the sweep optimization cannot consult a routing table.
      reprovider = Reprovider(
        config: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'pinned',
          reproviderSweepOptimization: true,
        ),
        dhtHandler: dhtHandler,
        pinManager: pinManager,
        mfsManager: mfsManager,
        metrics: metrics,
      );

      final result = await reprovider.trigger(wait: true);

      expect(result.groupedCids, isNotNull);
      expect(result.groupedCids, isEmpty);
      expect(result.succeeded, equals(1));
    });
  });

  group('Reprovider deduplication and status', () {
    test('deduplicates repeated CIDs before providing', () async {
      final cid = await addBlock(Uint8List.fromList([22, 23, 24]));
      await pinRecursive(cid);
      // unique strategy is identical to pinned but must still deduplicate.
      reprovider = createReprovider(
        dhtConfig: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'unique',
          reproviderBatchSize: 100,
          reproviderConcurrency: 10,
          reproviderSweepOptimization: false,
        ),
      );
      final result = await reprovider.trigger(wait: true);

      expect(result.attempted, equals(1));
      expect(result.succeeded, equals(1));
    });

    test('getStatus reports running and last result', () async {
      final cid = await addBlock(Uint8List.fromList([25, 26, 27]));
      await pinRecursive(cid);
      reprovider = createReprovider();

      final statusBefore = reprovider.getStatus();
      expect(statusBefore.running, isFalse);
      expect(statusBefore.lastResult, isNull);

      final run = reprovider.trigger(wait: true);
      final statusDuring = reprovider.getStatus();
      expect(statusDuring.running, isTrue);

      final result = await run;
      final statusAfter = reprovider.getStatus();
      expect(statusAfter.running, isFalse);
      expect(statusAfter.lastResult, isNotNull);
      expect(statusAfter.lastResult!.attempted, equals(result.attempted));
    });
  });

  group('Reprovider strategy validation', () {
    test('setStrategy accepts supported strategies', () {
      reprovider = createReprovider();
      reprovider.setStrategy('roots');
      expect(reprovider.getStatus().strategy, equals('roots'));
    });

    test('setStrategy rejects unsupported strategies', () {
      reprovider = createReprovider();
      expect(() => reprovider.setStrategy('unknown'), throwsArgumentError);
    });
  });

  group('Reprovider lifecycle', () {
    test('start schedules periodic timer and stop cancels it', () async {
      final cid = await addBlock(Uint8List.fromList([28, 29, 30]));
      await pinRecursive(cid);
      reprovider = Reprovider(
        config: const DHTConfig(
          reproviderEnabled: true,
          reproviderInterval: Duration(milliseconds: 50),
          reproviderStrategy: 'pinned',
          reproviderBatchSize: 100,
          reproviderConcurrency: 10,
          reproviderSweepOptimization: false,
        ),
        dhtHandler: dhtHandler,
        pinManager: pinManager,
        mfsManager: mfsManager,
        metrics: metrics,
      );

      await reprovider.start();
      expect(reprovider.getStatus().nextRun, isNotNull);

      // Wait for at least one periodic run to fire.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(reprovider.getStatus().lastRun, isNotNull);

      await reprovider.stop();
      expect(reprovider.getStatus().nextRun, isNull);
    });

    test('disabled reprovider does not schedule timer', () async {
      reprovider = Reprovider(
        config: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'pinned',
        ),
        dhtHandler: dhtHandler,
        pinManager: pinManager,
        mfsManager: mfsManager,
        metrics: metrics,
      );

      await reprovider.start();
      expect(reprovider.getStatus().nextRun, isNull);
    });

    test('pause stops timer and resume restarts it', () async {
      reprovider = createReprovider(
        dhtConfig: const DHTConfig(
          reproviderEnabled: true,
          reproviderInterval: Duration(milliseconds: 500),
          reproviderStrategy: 'pinned',
        ),
      );

      await reprovider.start();
      expect(reprovider.isPaused, isFalse);
      expect(reprovider.getStatus().nextRun, isNotNull);

      reprovider.pause();
      expect(reprovider.isPaused, isTrue);
      expect(reprovider.getStatus().nextRun, isNull);

      reprovider.resume();
      expect(reprovider.isPaused, isFalse);
      expect(reprovider.getStatus().nextRun, isNotNull);
    });
  });

  group('Reprovider denylist filtering', () {
    test('skips denylisted CIDs before announcing', () async {
      final allowed = await addBlock(Uint8List.fromList([70, 71, 72]));
      final blocked = await addBlock(Uint8List.fromList([73, 74, 75]));
      await pinRecursive(allowed);
      await pinRecursive(blocked);

      final denylist = DenylistService(
        const SecurityConfig(
          enableDenylist: true,
          denylistDefaultAction: 'block',
        ),
        metrics,
      );
      denylist.loadCompactBytes(utf8.encode(blocked.encode()));

      final router = FakeRouter();
      final nodeConfig = IPFSConfig(
        dht: const DHTConfig(requestTimeout: Duration(milliseconds: 100)),
      );
      final networkHandler = NetworkHandler(nodeConfig, router: router);
      final recordingHandler = _RecordingDHTHandler(
        nodeConfig,
        router,
        networkHandler,
        storage: datastore,
        denylistService: denylist,
      );
      await recordingHandler.dhtClient.initialize();
      addTearDown(() async {
        await recordingHandler.stop();
      });

      reprovider = Reprovider(
        config: const DHTConfig(
          reproviderEnabled: false,
          reproviderStrategy: 'pinned',
          reproviderSweepOptimization: false,
        ),
        dhtHandler: recordingHandler,
        pinManager: pinManager,
        mfsManager: mfsManager,
        metrics: metrics,
      );

      final result = await reprovider.trigger(wait: true);

      expect(result.attempted, equals(1));
      expect(result.succeeded, equals(1));
      final provided = recordingHandler.providedOrder
          .map((c) => c.toString())
          .toList();
      expect(provided, contains(allowed.toString()));
      expect(provided, isNot(contains(blocked.toString())));
    });
  });

  group('Reprovider concurrency', () {
    test('trigger without wait returns a busy result during a run', () async {
      final cid = await addBlock(Uint8List.fromList([80, 81, 82]));
      await pinRecursive(cid);
      // Slow the mock handler so the first run is still in flight.
      dhtHandler.setSimulatedDelay(const Duration(milliseconds: 200));

      reprovider = createReprovider();
      final run = reprovider.trigger(wait: true);
      // Give the first run a moment to enter the critical section.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final busy = await reprovider.trigger();
      expect(busy.errors, contains(contains('already running')));
      expect(busy.attempted, equals(0));

      await run;
    });
  });
}
