// example/plugins/logging_observer/main.dart
//
// Phase 1 example plugin: observes Bitswap wantlist/have messages and logs them.

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/plugins/ipfs_plugin.dart';

/// Bitswap logging observer example plugin.
class BitswapLoggerPlugin implements IPFSPlugin {
  @override
  String get id => 'org.dart-ipfs.examples.bitswap-logger';

  @override
  Future<void> onInit(IPFSNode node) async {
    // Plugin initialization is handled by the host manifest loader.
  }

  @override
  Future<void> onStart(IPFSNode node) async {
    // The host would wire Bitswap events in a full integration.
  }

  @override
  Future<void> onStop(IPFSNode node) async {}
}
