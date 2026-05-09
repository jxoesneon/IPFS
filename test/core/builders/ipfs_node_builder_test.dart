import 'package:test/test.dart';
import 'package:dart_ipfs/src/core/builders/ipfs_node_builder.dart';
import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:path/path.dart' as p;

void main() {
  const repoPath = 'test_repo';

  group('IPFSNodeBuilder', () {
    test('build offline node', () async {
      final config = IPFSConfig(
        offline: true,
        datastorePath: p.join(repoPath, 'datastore'),
        blockStorePath: p.join(repoPath, 'blocks'),
      );

      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();
      expect(node, isA<IPFSNode>());
    });

    test('build node with minimal config', () async {
      final config = IPFSConfig(
        datastorePath: p.join(repoPath, 'datastore'),
        blockStorePath: p.join(repoPath, 'blocks'),
      );

      final builder = IPFSNodeBuilder(config);
      final node = await builder.build();
      expect(node, isA<IPFSNode>());
    });
  });
}
