
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/ipfs.dart';
import 'package:test/test.dart';

void main() {
  group('IPFS Facade', () {
    late IPFS ipfs;

    setUp(() async {
      final config = IPFSConfig(
        datastorePath: './test_tmp/ipfs_facade_${DateTime.now().millisecondsSinceEpoch}',
        blockStorePath: './test_tmp/ipfs_facade_blocks_${DateTime.now().millisecondsSinceEpoch}',
        offline: true, // Run offline to make tests faster/isolated
      );
      ipfs = await IPFS.create(config: config);
    });

    tearDown(() async {
      await ipfs.stop();
    });

    test('should start and stop successfully', () async {
      await ipfs.start();
      // No exception means success
      expect(ipfs.peerID, isNotEmpty);
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
        'subdir': {
          'file2.txt': file2,
        }
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
    
    // Note: Networking methods (findProviders, requestBlock, PubSub, IPNS)
    // are harder to test in isolation with just the facade in offline mode,
    // but they just delegate to IPFSNode which is tested elsewhere.
    // Calling them might fail or do nothing in offline mode.
  });
}
