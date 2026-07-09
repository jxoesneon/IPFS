// lib/src/protocols/dcutr/dcutr_handler.dart
//
// DCUtR (Direct Connection Upgrade through Relay) handler for dart_ipfs.
//
// Wraps the libp2p HolePunchService from the ipfs_libp2p package to provide
// direct connection establishment for peers behind NATs/firewalls.
//
// The DCUtR protocol (https://github.com/libp2p/specs/blob/master/relay/DCUtR.md)
// allows two peers that are connected through a relay to upgrade their
// relayed connection to a direct connection by coordinating a simultaneous
// dial (hole punch).
//
// This handler:
// - Obtains the HolePunchService from the libp2p host when available
// - Exposes a [directConnect] method that attempts to establish a direct
//   connection with a remote peer
// - Integrates with the IPFS node lifecycle via [ILifecycle]
// - Falls back gracefully when no libp2p host is available (offline mode)

import 'dart:async';

import 'package:ipfs_libp2p/core/host/host.dart' as host_iface;
import 'package:ipfs_libp2p/core/peer/peer_id.dart' as peer_id_lib;
import 'package:ipfs_libp2p/p2p/protocol/holepunch/holepunch_service.dart'
    as holepunch;

import '../../core/config/ipfs_config.dart';
import '../../core/interfaces/i_lifecycle.dart';
import '../../core/ipfs_node/network_handler.dart';
import '../../utils/logger.dart';

/// Handles DCUtR (Direct Connection Upgrade through Relay) for an IPFS node.
///
/// When a libp2p [Host] is available, this handler delegates to the host's
/// [HolePunchService] to coordinate hole punching with remote peers.  When
/// no host is available (offline mode), the handler is a no-op.
class DCUtRHandler implements ILifecycle {
  /// Creates a DCUtRHandler with the given config and network handler.
  DCUtRHandler(this._config, this._networkHandler) {
    _logger = Logger(
      'DCUtRHandler',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
    _logger.debug('DCUtRHandler instance created');
  }

  final IPFSConfig _config;
  final NetworkHandler _networkHandler;
  late final Logger _logger;
  bool _isRunning = false;

  // The libp2p HolePunchService, obtained from the host on start.
  holepunch.HolePunchService? _holePunchService;
  host_iface.Host? _host;

  // Track hole punch attempts and results.
  final Map<String, DateTime> _lastHolePunchAttempts = {};
  final Map<String, bool> _holePunchResults = {};

  /// Whether the DCUtR handler has a usable HolePunchService.
  bool get isAvailable => _holePunchService != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('DCUtRHandler already running');
      return;
    }

    try {
      _logger.debug('Starting DCUtRHandler...');

      _host = _tryGetLibp2pHost();

      if (_host != null) {
        _holePunchService = _host!.holePunchService;
        if (_holePunchService != null) {
          _logger.info('DCUtR handler started with libp2p HolePunchService');
        } else {
          _logger.info(
            'libp2p host available but HolePunchService is not enabled; '
            'DCUtR will be inactive',
          );
        }
      } else {
        _logger.info(
          'No libp2p host available — DCUtR handler is inactive (offline mode)',
        );
      }

      _isRunning = true;
      _logger.info('DCUtRHandler started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start DCUtRHandler', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('DCUtRHandler already stopped');
      return;
    }

    try {
      _logger.debug('Stopping DCUtRHandler...');

      // The HolePunchService lifecycle is managed by the libp2p host.
      // We just release our reference.
      _holePunchService = null;
      _host = null;
      _lastHolePunchAttempts.clear();
      _holePunchResults.clear();

      _isRunning = false;
      _logger.info('DCUtRHandler stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop DCUtRHandler', e, stackTrace);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // DCUtR operations
  // ---------------------------------------------------------------------------

  /// Attempts to establish a direct connection with [peerId] by coordinating
  /// a hole punch through the existing relayed connection.
  ///
  /// This is a no-op (returns `false`) if no HolePunchService is available.
  ///
  /// [peerId] - The base58-encoded peer ID of the remote peer.
  ///
  /// Returns `true` if a direct connection was successfully established.
  Future<bool> directConnect(String peerId) async {
    if (!_isRunning) {
      _logger.warning('DCUtRHandler is not running');
      return false;
    }

    if (_holePunchService == null) {
      _logger.debug('No HolePunchService available; skipping direct connect');
      return false;
    }

    _logger.debug('Attempting DCUtR direct connect to $peerId');
    _lastHolePunchAttempts[peerId] = DateTime.now();

    try {
      final pid = _parsePeerId(peerId);
      if (pid == null) {
        _logger.warning('Invalid peer ID: $peerId');
        _holePunchResults[peerId] = false;
        return false;
      }

      await _holePunchService!.directConnect(pid);
      _holePunchResults[peerId] = true;
      _logger.info('DCUtR direct connect succeeded for $peerId');
      return true;
    } catch (e, stackTrace) {
      _holePunchResults[peerId] = false;
      _logger.error('DCUtR direct connect failed for $peerId', e, stackTrace);
      return false;
    }
  }

  /// Returns the timestamp of the last hole punch attempt for [peerId],
  /// or `null` if no attempt has been made.
  DateTime? lastHolePunchAttempt(String peerId) =>
      _lastHolePunchAttempts[peerId];

  /// Returns `true` if the last hole punch attempt for [peerId] succeeded.
  bool? holePunchResult(String peerId) => _holePunchResults[peerId];

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Gets the current status of the DCUtR handler.
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'running': _isRunning,
      'available': isAvailable,
      'active_attempts': _lastHolePunchAttempts.length,
      'successful': _holePunchResults.values.where((r) => r).length,
      'failed': _holePunchResults.values.where((r) => !r).length,
    };
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Attempts to retrieve the libp2p [Host] from the network handler's router.
  host_iface.Host? _tryGetLibp2pHost() {
    try {
      final router = _networkHandler.router;
      final dynamic dynRouter = router;
      if (dynRouter != null && dynRouter.host is host_iface.Host) {
        return dynRouter.host as host_iface.Host;
      }
    } catch (_) {
      // Router doesn't expose a host — DCUtR is inactive.
    }
    return null;
  }

  /// Parses a base58-encoded peer ID string into a libp2p [PeerId].
  peer_id_lib.PeerId? _parsePeerId(String peerIdStr) {
    try {
      return peer_id_lib.PeerId.fromString(peerIdStr);
    } catch (_) {
      return null;
    }
  }
}
