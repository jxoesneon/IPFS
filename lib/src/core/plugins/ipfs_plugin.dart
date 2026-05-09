import 'package:dart_ipfs/dart_ipfs.dart';

/// Base class for all IPFS plugins.
/// 
/// Plugins can extend the functionality of the IPFS node by:
/// - Registering new protocol handlers.
/// - Adding custom configuration.
/// - Hooking into the node lifecycle.
abstract class IPFSPlugin {
  /// The unique identifier of the plugin.
  String get id;

  /// Called when the plugin is being initialized.
  Future<void> onInit(IPFSNode node);

  /// Called when the node is starting.
  Future<void> onStart(IPFSNode node);

  /// Called when the node is stopping.
  Future<void> onStop(IPFSNode node);
}

/// Manages the lifecycle of plugins within an IPFS node.
class PluginManager {
  /// Creates a [PluginManager] for the given [node].
  PluginManager(this._node);
  final IPFSNode _node;
  final List<IPFSPlugin> _plugins = [];

  /// Registers a new [plugin].
  void register(IPFSPlugin plugin) {
    _plugins.add(plugin);
  }

  /// Initializes all registered plugins.
  Future<void> initAll() async {
    for (final plugin in _plugins) {
      await plugin.onInit(_node);
    }
  }

  /// Starts all registered plugins.
  Future<void> startAll() async {
    for (final plugin in _plugins) {
      await plugin.onStart(_node);
    }
  }

  /// Stops all registered plugins.
  Future<void> stopAll() async {
    for (final plugin in _plugins) {
      await plugin.onStop(_node);
    }
  }
}
