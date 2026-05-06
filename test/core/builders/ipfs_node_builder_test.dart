import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String repoPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ipfs_builder_test');
    repoPath = tempDir.path;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('IPFSNodeBuilder', () {
    test('build offline node', () async {
      final config = IPFSConfig(
        offline: true,
        datastorePath: p.join(repoPath, 'datastore'),
        blockStorePath: p.join(repoPath, 'blocks'),
      );
      // Ensure paths are set correctly in config if needed

      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();
      expect(node, isA<IPFSNode>());
    });
  });
}
