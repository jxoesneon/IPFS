// example/plugins/metrics_emitter/main.dart
//
// Phase 1 example plugin: emits a custom counter to the host metrics collector.

import 'package:dart_ipfs/src/core/ipfs_node/ipfs_node.dart';
import 'package:dart_ipfs/src/core/plugins/ipfs_plugin.dart';

/// Metrics emitter example plugin.
class MetricsEmitterPlugin implements IPFSPlugin {
  @override
  String get id => 'org.dart-ipfs.examples.metrics-emitter';

  @override
  Future<void> onInit(IPFSNode node) async {
    // Plugin initialization is handled by the host manifest loader.
  }

  @override
  Future<void> onStart(IPFSNode node) async {
    // The host would inject a CapabilityMetricsEmitter in a full integration.
  }

  @override
  Future<void> onStop(IPFSNode node) async {}
}
