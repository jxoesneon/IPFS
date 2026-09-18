// test/protocols/dht/reprovider_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/cid.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/block.dart';
import 'package:dart_ipfs/src/core/data_structures/blockstore.dart';
import 'package:dart_ipfs/src/core/data_structures/pin_manager.dart';
import 'package:dart_ipfs/src/core/metrics/metrics_collector.dart';
import 'package:dart_ipfs/src/core/mfs/mfs_manager.dart';
import 'package:dart_ipfs/src/core/storage/memory_datastore.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/core/types/peer_id.dart';
import 'package:dart_ipfs/src/proto/generated/core/pin.pb.dart';
import 'package:dart_ipfs/src/protocols/dht/dht_handler.dart';
import 'package:dart_ipfs/src/protocols/dht/reprovider.dart';

import '../../fakes/fake_router.dart';
import '../../mocks/mock_dht_handler.dart';

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
}
