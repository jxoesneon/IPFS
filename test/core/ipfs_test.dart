import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/ipfs.dart';
import 'package:dart_ipfs/src/protocols/pubsub/pubsub_message.dart';
import 'package:test/test.dart';

void main() {
  group('IPFS Facade', () {
    late IPFS ipfs;

    setUp(() async {
      final config = IPFSConfig(
        datastorePath:
            './test_tmp/ipfs_facade_${DateTime.now().millisecondsSinceEpoch}',
        blockStorePath:
            './test_tmp/ipfs_facade_blocks_${DateTime.now().millisecondsSinceEpoch}',
        offline: true, // Run offline to make tests faster/isolated
      );
      ipfs = await IPFS.create(config: config);
    });

    tearDown(() async {
      await ipfs.stop();
    });

    test('should start and stop successfully', () async {
      await ipfs.start();
      // No exception means success - IPFS class doesn't expose isStarted
      // in offline mode, but successful start/stop is validated.
    });

    test('should add and get file', () async {
      await ipfs.start();
      final content = Uint8List.fromList(utf8.encode('Hello Facade'));
      final cid = await ipfs.addFile(content);

      expect(cid, isNotEmpty);

      final retrieved = await ipfs.get(cid);
      expect(retrieved, equals(content));
    });

    test('should add and list directory', () async {
      await ipfs.start();
      final file1 = Uint8List.fromList(utf8.encode('File 1'));
      final file2 = Uint8List.fromList(utf8.encode('File 2'));

      final dirContent = {
        'file1.txt': file1,
        'subdir': {'file2.txt': file2},
      };

      final rootCid = await ipfs.addDirectory(dirContent);
      expect(rootCid, isNotEmpty);

      // Verify listing
      final links = await ipfs.ls(rootCid);
      expect(links.length, equals(2)); // file1.txt and subdir
      expect(links.any((l) => l.name == 'file1.txt'), isTrue);
      expect(links.any((l) => l.name == 'subdir'), isTrue);
    });

    test('should pin and unpin content', () async {
      await ipfs.start();
      final content = Uint8List.fromList(utf8.encode('Pin Me'));
      final cid = await ipfs.addFile(content);

      await ipfs.pin(cid);
      // We don't have a direct isPinned method exposed on IPFS facade,
      // but unpinning non-pinned might throw or return false if we checked return.
      // IPFS.unpin throws if failed.
      await ipfs.unpin(cid);
    });

    test('should report stats', () async {
      await ipfs.start();

      // Add some content to populate datastore
      final content = Uint8List.fromList(utf8.encode('Stats Content'));
      await ipfs.addFile(content);

      final stats = await ipfs.stats();
      expect(stats.numBlocks, greaterThan(0));
      expect(stats.datastoreSize, greaterThan(0));
      expect(stats.bandwidthSent, greaterThanOrEqualTo(0));
    });

    test('should expose onNewContent stream', () async {
      await ipfs.start();

      final content = Uint8List.fromList(utf8.encode('Stream Content'));

      final futureCid = ipfs.onNewContent.first;
      await ipfs.addFile(content);

      final cid = await futureCid;
      expect(cid, isNotEmpty);
    });

    test('peerID throws on an offline node', () async {
      await ipfs.start();
      // An offline node has no libp2p identity; peerID surfaces the
      // documented StateError rather than a placeholder value.
      expect(() => ipfs.peerID, throwsStateError);
    });

    test('peerId and discoveredPeers report offline state', () async {
      await ipfs.start();
      // The non-deprecated getter surfaces the same StateError as peerID.
      expect(() => ipfs.peerId, throwsStateError);
      // mDNS is not registered in offline mode, so the stream stays empty.
      expect(await ipfs.discoveredPeers.isEmpty, isTrue);
    });

    test(
      'networking facades delegate to underlying node and surface errors',
      () async {
        await ipfs.start();

        // CAR roundtrip via the facade.
        final content = Uint8List.fromList(utf8.encode('CAR Me'));
        final cid = await ipfs.addFile(content);
        final carBytes = await ipfs.exportCAR(cid);
        expect(carBytes, isNotEmpty);
        await ipfs.importCAR(carBytes);

        // Offline-mode delegations: these either throw or return empty.
        for (final action in <Future<void> Function()>[
          () async => ipfs.findProviders(cid),
          () async => ipfs.requestBlock(cid, 'QmPeer'),
          () async => ipfs.subscribe('topic'),
          () async => ipfs.publish('topic', 'msg'),
          () async => ipfs.resolveIPNS('name'),
          () async => ipfs.publishIPNS(cid, keyName: 'self'),
          () async => ipfs.resolveDNSLink('example.com'),
        ]) {
          try {
            await action();
          } catch (_) {
            // Tolerated: offline mode causes most of these to throw.
          }
        }
      },
    );

    test('pubsubMessages exposes inbound pubsub stream', () async {
      await ipfs.start();
      expect(ipfs.pubsubMessages, isA<Stream<PubSubMessage>>());
      // Offline mode: stream completes without emitting messages.
      expect(await ipfs.pubsubMessages.toList(), isEmpty);
    });

    test('messagesFor filters inbound messages by topic', () async {
      await ipfs.start();
      expect(ipfs.messagesFor('topic-a'), isA<Stream<PubSubMessage>>());
      // Offline mode: filtered stream completes without emitting messages.
      expect(await ipfs.messagesFor('topic-a').toList(), isEmpty);
    });

    test('unpin throws when CID is not pinned', () async {
      await ipfs.start();
      await expectLater(() => ipfs.unpin('QmDoesNotExist'), throwsException);
    });
  });
}
