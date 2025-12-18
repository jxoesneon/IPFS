// src/core/ipfs_node/bootstrap_handler.dart
import 'dart:async';

import 'package:dart_ipfs/src/core/config/ipfs_config.dart';
import 'package:dart_ipfs/src/core/data_structures/peer.dart';
import 'package:dart_ipfs/src/core/ipfs_node/network_handler.dart';
import 'package:dart_ipfs/src/utils/logger.dart';

/// Handles bootstrap peer connections for an IPFS node.
class BootstrapHandler {

  BootstrapHandler(this._config, this._networkHandler) {
    _logger = Logger(
      'BootstrapHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _logger.debug('Creating new BootstrapHandler instance');
  }
  final IPFSConfig _config;
  final NetworkHandler _networkHandler;
  late final Logger _logger;
  final Set<Peer> _connectedBootstrapPeers = {};
  Timer? _reconnectionTimer;
  bool _isRunning = false;

  // Default reconnection interval
  static const Duration _reconnectionInterval = Duration(minutes: 5);

  /// Starts the bootstrap handler
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('BootstrapHandler already running');
      return;
    }

    try {
      _logger.debug('Starting BootstrapHandler...');
      _isRunning = true;

      // Initial connection to bootstrap peers
      await _connectToBootstrapPeers();

      // Set up periodic reconnection
      _setupReconnectionTimer();

      _logger.info('BootstrapHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start BootstrapHandler', e, stackTrace);
      _isRunning = false;
      rethrow;
    }
  }

  /// Stops the bootstrap handler
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('BootstrapHandler already stopped');
      return;
    }

    try {
      _logger.debug('Stopping BootstrapHandler...');

      // Cancel reconnection timer
      _reconnectionTimer?.cancel();
      _reconnectionTimer = null;

      // Clear connected peers set
      _connectedBootstrapPeers.clear();

      _isRunning = false;
      _logger.info('BootstrapHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop BootstrapHandler', e, stackTrace);
      rethrow;
    }
  }

  void _setupReconnectionTimer() {
    _logger.verbose('Setting up bootstrap peer reconnection timer');
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer.periodic(_reconnectionInterval, (_) {
      _connectToBootstrapPeers();
    });
  }

  Future<void> _connectToBootstrapPeers() async {
    _logger.debug('Connecting to bootstrap peers...');

    for (final peerAddress in _config.network.bootstrapPeers) {
      try {
        _logger.verbose(
          'Attempting to connect to bootstrap peer: $peerAddress',
        );

        // Create peer instance from multiaddr
        final peer = await Peer.fromMultiaddr(peerAddress);

        if (_connectedBootstrapPeers.contains(peer)) {
          _logger.verbose('Already connected to bootstrap peer: $peerAddress');
          continue;
        }

        // Connection logic handled by NetworkHandler
        await _networkHandler.connectToPeer(peerAddress);

        // We just track the successful connections here
        _connectedBootstrapPeers.add(peer);
        _logger.debug('Successfully connected to bootstrap peer: $peerAddress');
      } catch (e, stackTrace) {
        _logger.error(
          'Failed to connect to bootstrap peer: $peerAddress',
          e,
          stackTrace,
        );
      }
    }
  }

  /// Gets the current status of the bootstrap handler
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'connected_peers': _connectedBootstrapPeers.length,
      'total_bootstrap_peers': _config.network.bootstrapPeers.length,
      'reconnection_interval': _reconnectionInterval.inMinutes,
    };
  }
}
