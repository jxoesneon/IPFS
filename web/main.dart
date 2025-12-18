import 'package:dart_ipfs/dart_ipfs.dart';

/// Web entry point for IPFS node.
void main() async {
  final config = IPFSConfig(offline: true);
  final node = await IPFSNode.create(config);
  await node.start();
}
