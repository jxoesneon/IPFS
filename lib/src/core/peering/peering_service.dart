// lib/src/core/peering/peering_service.dart
//
// Peering service for dart_ipfs.
//
// Implements the libp2p peering protocol which maintains persistent
// connections to a configured set of peers.  When a peered peer disconnects,
// the service automatically attempts to reconnect after a configurable delay.
//
// Spec: https://github.com/libp2p/specs/blob/master/peering/peering.md
//
// Key behaviours:
// - Peered peers are identified by their multiaddress (must include /p2p/<peerId>)
// - The service periodically checks connectivity to peered peers
// - Reconnection uses exponential backoff up to a maximum interval
// - The service integrates with the IPFS node lifecycle via [ILifecycle]

import 'dart:async';

import '../../utils/logger.dart';
import '../config/ipfs_config.dart';
import '../interfaces/i_lifecycle.dart';
import '../ipfs_node/network_handler.dart';

/// Configuration for the peering service.
class PeeringConfig {
  /// Creates a [PeeringConfig].
  const PeeringConfig({
    this.enabled = true,
    this.peers = const <String>[],
    this.checkInterval = const Duration(seconds: 30),
    this.initialReconnectDelay = const Duration(seconds: 5),
    this.maxReconnectDelay = const Duration(minutes: 10),
    this.maxReconnectAttempts = 0,
  });

  /// Creates a [PeeringConfig] from a JSON map.
  factory PeeringConfig.fromJson(Map<String, dynamic> json) {
    return PeeringConfig(
      enabled: json['enabled'] as bool? ?? true,
      peers: (json['peers'] as List?)?.cast<String>() ?? const [],
      checkInterval: json['checkIntervalSeconds'] != null
          ? Duration(seconds: json['checkIntervalSeconds'] as int)
          : const Duration(seconds: 30),
      initialReconnectDelay: json['initialReconnectDelaySeconds'] != null
          ? Duration(seconds: json['initialReconnectDelaySeconds'] as int)
          : const Duration(seconds: 5),
      maxReconnectDelay: json['maxReconnectDelaySeconds'] != null
          ? Duration(seconds: json['maxReconnectDelaySeconds'] as int)
          : const Duration(minutes: 10),
      maxReconnectAttempts: json['maxReconnectAttempts'] as int? ?? 0,
    );
  }

  /// Whether the peering service is enabled.
  final bool enabled;

  /// List of peer multiaddresses to maintain persistent connections with.
  ///
  /// Each entry should be a full multiaddress including the peer ID, e.g.:
  /// `/ip4/1.2.3.4/tcp/4001/p2p/Qm...`
  final List<String> peers;

  /// Interval between connectivity checks.
  final Duration checkInterval;

  /// Initial delay before the first reconnection attempt after a disconnect.
  final Duration initialReconnectDelay;

  /// Maximum delay between reconnection attempts (for exponential backoff).
  final Duration maxReconnectDelay;

  /// Maximum number of reconnection attempts before giving up.
  ///
  /// `0` means unlimited retries.
  final int maxReconnectAttempts;

  /// Converts this configuration to a JSON map.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'peers': peers,
    'checkIntervalSeconds': checkInterval.inSeconds,
    'initialReconnectDelaySeconds': initialReconnectDelay.inSeconds,
    'maxReconnectDelaySeconds': maxReconnectDelay.inSeconds,
    'maxReconnectAttempts': maxReconnectAttempts,
  };
}

/// Maintains persistent connections to a configured set of peers.
///
/// The peering service periodically checks whether each configured peer is
/// connected.  If a peer is not connected, the service attempts to reconnect
/// using exponential backoff.  This is useful for maintaining connections to
/// critical infrastructure peers (e.g. relay servers, bootstrap nodes,
/// pubsub peers) that should always be reachable.
class PeeringService implements ILifecycle {
  /// Creates a [PeeringService] with the given config and network handler.
  PeeringService(
    this._config,
    this._networkHandler, {
    PeeringConfig? peeringConfig,
  }) : _peeringConfig = peeringConfig ?? const PeeringConfig() {
    _logger = Logger(
      'PeeringService',
      debug: _config.debug,
      verbose: _config.verboseLogging,
    );
  }

  final IPFSConfig _config;
  final NetworkHandler _networkHandler;
  final PeeringConfig _peeringConfig;
  late final Logger _logger;

  bool _isRunning = false;
  Timer? _checkTimer;

  /// Tracks reconnection state for each peered peer.
  final Map<String, _PeerState> _peerStates = {};

  /// Stream controller for peering events.
  final StreamController<PeeringEvent> _eventsController =
      StreamController<PeeringEvent>.broadcast();

  /// Stream of peering events (peer connected, disconnected, reconnected).
  Stream<PeeringEvent> get events => _eventsController.stream;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> start() async {
    if (_isRunning) {
      _logger.warning('PeeringService already running');
      return;
    }

    if (!_peeringConfig.enabled) {
      _logger.info('PeeringService is disabled by configuration');
      _isRunning = true;
      return;
    }

    try {
      _logger.debug('Starting PeeringService...');

      // Initialize peer states for all configured peers.
      for (final peerAddr in _peeringConfig.peers) {
        final peerId = _extractPeerId(peerAddr);
        if (peerId != null) {
          _peerStates[peerId] = _PeerState(
            peerId: peerId,
            multiaddr: peerAddr,
            connected: false,
            reconnectAttempts: 0,
            nextReconnectAt: DateTime.now(),
          );
        } else {
          _logger.warning('Could not extract peer ID from: $peerAddr');
        }
      }

      _logger.info('PeeringService monitoring ${_peerStates.length} peers');

      // Perform an initial connectivity check.
      await _checkAllPeers();

      // Start periodic checks.
      _checkTimer = Timer.periodic(_peeringConfig.checkInterval, (_) {
        _checkAllPeers();
      });

      _isRunning = true;
      _logger.info('PeeringService started successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to start PeeringService', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warning('PeeringService already stopped');
      return;
    }

    try {
      _logger.debug('Stopping PeeringService...');

      _checkTimer?.cancel();
      _checkTimer = null;
      _peerStates.clear();

      await _eventsController.close();
      _isRunning = false;
      _logger.info('PeeringService stopped successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to stop PeeringService', e, stackTrace);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Peering operations
  // ---------------------------------------------------------------------------

  /// Adds a peer to the peering set.
  ///
  /// [multiaddr] - The full multiaddress of the peer, including `/p2p/<peerId>`.
  void addPeer(String multiaddr) {
    final peerId = _extractPeerId(multiaddr);
    if (peerId == null) {
      _logger.warning('Could not extract peer ID from: $multiaddr');
      return;
    }

    if (_peerStates.containsKey(peerId)) {
      _logger.debug('Peer $peerId is already in the peering set');
      return;
    }

    _peerStates[peerId] = _PeerState(
      peerId: peerId,
      multiaddr: multiaddr,
      connected: false,
      reconnectAttempts: 0,
      nextReconnectAt: DateTime.now(),
    );

    _logger.info('Added peer $peerId to peering set');

    // Immediately attempt to connect.
    _connectPeer(_peerStates[peerId]!);
  }

  /// Removes a peer from the peering set.
  ///
  /// [peerId] - The peer ID to remove.
  void removePeer(String peerId) {
    if (_peerStates.remove(peerId) != null) {
      _logger.info('Removed peer $peerId from peering set');
    } else {
      _logger.debug('Peer $peerId was not in the peering set');
    }
  }

  /// Returns the list of peered peer IDs.
  List<String> get peeredPeerIds => _peerStates.keys.toList();

  /// Returns the connection status of a peered peer.
  bool isPeerConnected(String peerId) {
    return _peerStates[peerId]?.connected ?? false;
  }

  // ---------------------------------------------------------------------------
  // Internal logic
  // ---------------------------------------------------------------------------

  /// Checks the connectivity of all peered peers and attempts reconnection
  /// for any that are disconnected.
  Future<void> _checkAllPeers() async {
    if (_peerStates.isEmpty) return;

    _logger.verbose('Checking connectivity for ${_peerStates.length} peers');

    for (final state in _peerStates.values.toList()) {
      final isConnected = _networkHandler.router.isConnectedPeer(state.peerId);

      if (isConnected && !state.connected) {
        // Peer just became connected.
        state.connected = true;
        state.reconnectAttempts = 0;
        _eventsController.add(
          PeeringEvent(peerId: state.peerId, type: PeeringEventType.connected),
        );
        _logger.info('Peered peer ${state.peerId} is now connected');
      } else if (!isConnected && state.connected) {
        // Peer just disconnected.
        state.connected = false;
        state.reconnectAttempts = 0;
        state.nextReconnectAt = DateTime.now().add(
          _peeringConfig.initialReconnectDelay,
        );
        _eventsController.add(
          PeeringEvent(
            peerId: state.peerId,
            type: PeeringEventType.disconnected,
          ),
        );
        _logger.info('Peered peer ${state.peerId} disconnected');
      }

      // Attempt reconnection if needed.
      if (!state.connected && DateTime.now().isAfter(state.nextReconnectAt)) {
        _connectPeer(state);
      }
    }
  }

  /// Attempts to connect to a peered peer.
  void _connectPeer(_PeerState state) {
    // Check max reconnection attempts.
    if (_peeringConfig.maxReconnectAttempts > 0 &&
        state.reconnectAttempts >= _peeringConfig.maxReconnectAttempts) {
      _logger.warning(
        'Giving up on peer ${state.peerId} after '
        '${state.reconnectAttempts} reconnection attempts',
      );
      _eventsController.add(
        PeeringEvent(peerId: state.peerId, type: PeeringEventType.giveUp),
      );
      _peerStates.remove(state.peerId);
      return;
    }

    state.reconnectAttempts++;
    _logger.debug(
      'Attempting to connect to peered peer ${state.peerId} '
      '(attempt ${state.reconnectAttempts})',
    );

    _networkHandler.router
        .connect(state.multiaddr)
        .then((_) {
          // Connection succeeded — state will be updated on next check.
          _logger.info('Connected to peered peer ${state.peerId}');
        })
        .catchError((Object e) {
          _logger.error('Failed to connect to peered peer ${state.peerId}', e);

          // Schedule next reconnection with exponential backoff.
          final backoff = _calculateBackoff(state.reconnectAttempts);
          state.nextReconnectAt = DateTime.now().add(backoff);
          _logger.debug(
            'Next reconnection attempt for ${state.peerId} in '
            '${backoff.inSeconds}s',
          );
        });
  }

  /// Calculates the exponential backoff delay for reconnection attempt [attempt].
  Duration _calculateBackoff(int attempt) {
    final baseSeconds = _peeringConfig.initialReconnectDelay.inSeconds;
    final backoffSeconds = baseSeconds * (1 << (attempt - 1));
    final backoff = Duration(seconds: backoffSeconds);
    // Cap at maxReconnectDelay.
    return backoff > _peeringConfig.maxReconnectDelay
        ? _peeringConfig.maxReconnectDelay
        : backoff;
  }

  /// Extracts the peer ID from a multiaddress.
  String? _extractPeerId(String multiaddr) {
    final parts = multiaddr.split('/');
    final p2pIndex = parts.lastIndexOf('p2p');
    if (p2pIndex != -1 && p2pIndex + 1 < parts.length) {
      return parts[p2pIndex + 1];
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Gets the current status of the peering service.
  Future<Map<String, dynamic>> getStatus() async {
    final connected = _peerStates.values.where((s) => s.connected).length;
    final disconnected = _peerStates.values.where((s) => !s.connected).length;
    return {
      'running': _isRunning,
      'enabled': _peeringConfig.enabled,
      'total_peers': _peerStates.length,
      'connected': connected,
      'disconnected': disconnected,
      'peers': _peerStates.values
          .map(
            (s) => {
              'peer_id': s.peerId,
              'connected': s.connected,
              'reconnect_attempts': s.reconnectAttempts,
            },
          )
          .toList(),
    };
  }
}

/// Internal state tracking for a peered peer.
class _PeerState {
  _PeerState({
    required this.peerId,
    required this.multiaddr,
    required this.connected,
    required this.reconnectAttempts,
    required this.nextReconnectAt,
  });

  final String peerId;
  final String multiaddr;
  bool connected;
  int reconnectAttempts;
  DateTime nextReconnectAt;
}

/// Type of peering event.
enum PeeringEventType {
  /// A peered peer became connected.
  connected,

  /// A peered peer disconnected.
  disconnected,

  /// The service gave up trying to reconnect to a peer.
  giveUp,
}

/// Event emitted by the peering service.
class PeeringEvent {
  /// Creates a [PeeringEvent].
  PeeringEvent({required this.peerId, required this.type});

  /// The peer ID this event relates to.
  final String peerId;

  /// The type of event.
  final PeeringEventType type;

  @override
  String toString() => 'PeeringEvent(peerId: $peerId, type: $type)';
}
