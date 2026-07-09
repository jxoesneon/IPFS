// lib/src/protocols/connection_manager/cuttlefish_connection_manager.dart
import 'dart:async';

import '../../utils/logger.dart';

/// A tagged connection with priority and metadata for the Cuttlefish
/// connection manager.
class TaggedConnection {
  /// Creates a tagged connection.
  TaggedConnection({
    required this.peerId,
    Set<String>? tags,
    this.priority = 0,
    DateTime? connectedAt,
  }) : tags = tags != null ? Set<String>.from(tags) : <String>{},
       connectedAt = connectedAt ?? DateTime.now();

  /// The peer ID of this connection.
  final String peerId;

  /// Tags applied to this connection (e.g., 'dht', 'relay', 'peer').
  final Set<String> tags;

  /// Priority value (higher = more important, less likely to be pruned).
  int priority;

  /// When the connection was established.
  final DateTime connectedAt;

  /// Whether this connection is protected from pruning.
  bool _protected = false;

  /// Whether this connection is protected from pruning.
  bool get isProtected => _protected;

  /// Marks this connection as protected from pruning.
  void protect() => _protected = true;

  /// Removes protection from this connection.
  void unprotect() => _protected = false;

  /// Adds a tag to this connection.
  void addTag(String tag) => tags.add(tag);

  /// Removes a tag from this connection.
  void removeTag(String tag) => tags.remove(tag);

  /// Returns whether this connection has the given tag.
  bool hasTag(String tag) => tags.contains(tag);

  @override
  String toString() =>
      'TaggedConnection(peer=$peerId, priority=$priority, tags=$tags, '
      'protected=$isProtected)';
}

/// Configuration for the Cuttlefish v2 connection manager.
class CuttlefishConfig {
  /// Creates a configuration for the connection manager.
  const CuttlefishConfig({
    this.highWater = 128,
    this.lowWater = 64,
    this.gracePeriod = const Duration(seconds: 10),
    this.defaultPriority = 0,
    this.pruneInterval = const Duration(seconds: 30),
  });

  /// Maximum number of connections before pruning begins.
  final int highWater;

  /// Target number of connections after pruning.
  final int lowWater;

  /// Grace period before a newly connected peer can be pruned.
  final Duration gracePeriod;

  /// Default priority for new connections.
  final int defaultPriority;

  /// Interval between automatic pruning checks.
  final Duration pruneInterval;
}

/// Cuttlefish v2 connection manager for libp2p-style connection management.
///
/// Implements the standard libp2p connection manager pattern:
/// - Limits total connections to [CuttlefishConfig.highWater] (default 128).
/// - When the high water mark is reached, prunes connections down to
///   [CuttlefishConfig.lowWater] (default 64).
/// - Connections are prioritized by tags and explicit priority values.
/// - Low-priority connections are pruned first.
/// - Protected connections are never pruned.
/// - A grace period protects newly established connections from immediate
///   pruning.
///
/// This follows the go-libp2p ConnManager pattern. The "Cuttlefish v2" name
/// refers to the enhanced connection management strategy with tag-based
/// prioritization.
class CuttlefishConnectionManager {
  /// Creates a connection manager with the given [config].
  CuttlefishConnectionManager({CuttlefishConfig? config, Logger? logger})
    : _config = config ?? const CuttlefishConfig(),
      _logger = logger ?? Logger('CuttlefishConnectionManager');

  final CuttlefishConfig _config;
  final Logger _logger;

  /// Map of peer ID to tagged connection.
  final Map<String, TaggedConnection> _connections = {};

  /// Timer for periodic pruning.
  Timer? _pruneTimer;

  /// Whether the manager is running.
  bool _running = false;

  /// Stream controller for connection events.
  final StreamController<String> _prunedConnections =
      StreamController<String>.broadcast();

  /// Stream of peer IDs that have been pruned.
  Stream<String> get prunedConnections => _prunedConnections.stream;

  /// Starts the connection manager.
  void start() {
    if (_running) return;
    _running = true;
    _pruneTimer = Timer.periodic(
      _config.pruneInterval,
      (_) => _pruneIfNeeded(),
    );
    _logger.info(
      'CuttlefishConnectionManager started '
      '(high=${_config.highWater}, low=${_config.lowWater})',
    );
  }

  /// Stops the connection manager.
  void stop() {
    if (!_running) return;
    _running = false;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _connections.clear();
    _logger.info('CuttlefishConnectionManager stopped');
  }

  /// Whether the manager is running.
  bool get isRunning => _running;

  /// Returns the current number of connections.
  int get connectionCount => _connections.length;

  /// Returns the high water mark.
  int get highWater => _config.highWater;

  /// Returns the low water mark.
  int get lowWater => _config.lowWater;

  /// Registers a new connection for [peerId].
  ///
  /// If the connection count exceeds the high water mark after adding, a
  /// pruning pass is triggered.
  void addConnection(String peerId, {Set<String>? tags, int? priority}) {
    final conn = TaggedConnection(
      peerId: peerId,
      tags: tags ?? {},
      priority: priority ?? _config.defaultPriority,
    );
    _connections[peerId] = conn;
    _logger.verbose(
      'Added connection: $peerId (total: ${_connections.length})',
    );

    if (_connections.length > _config.highWater) {
      _pruneIfNeeded();
    }
  }

  /// Removes a connection for [peerId].
  void removeConnection(String peerId) {
    _connections.remove(peerId);
    _logger.verbose('Removed connection: $peerId');
  }

  /// Returns whether a connection exists for [peerId].
  bool hasConnection(String peerId) => _connections.containsKey(peerId);

  /// Returns the [TaggedConnection] for [peerId], or null if not found.
  TaggedConnection? getConnection(String peerId) => _connections[peerId];

  /// Tags a connection with [tag] and optionally adjusts its priority.
  void tag(String peerId, String tag, {int? priority}) {
    final conn = _connections[peerId];
    if (conn == null) {
      _logger.warning('Cannot tag unknown connection: $peerId');
      return;
    }
    conn.addTag(tag);
    if (priority != null) {
      conn.priority += priority;
    }
    _logger.verbose('Tagged $peerId with "$tag" (priority: ${conn.priority})');
  }

  /// Removes a tag from a connection and optionally adjusts priority.
  void untag(String peerId, String tag, {int? priority}) {
    final conn = _connections[peerId];
    if (conn == null) return;
    conn.removeTag(tag);
    if (priority != null) {
      conn.priority -= priority;
    }
  }

  /// Protects a connection from pruning.
  void protect(String peerId) {
    _connections[peerId]?.protect();
  }

  /// Removes protection from a connection.
  void unprotect(String peerId) {
    _connections[peerId]?.unprotect();
  }

  /// Returns all connections that have the given tag.
  List<TaggedConnection> connectionsByTag(String tag) {
    return _connections.values.where((c) => c.hasTag(tag)).toList();
  }

  /// Returns all current connections.
  List<TaggedConnection> get connections => _connections.values.toList();

  /// Prunes connections if the count exceeds the high water mark.
  ///
  /// Pruning removes connections down to the low water mark, prioritizing
  /// removal of:
  /// 1. Unprotected connections with the lowest priority.
  /// 2. Connections that are past the grace period.
  ///
  /// Protected connections and connections within the grace period are never
  /// pruned.
  void _pruneIfNeeded() {
    if (_connections.length <= _config.highWater) return;

    final now = DateTime.now();
    final prunable = _connections.values.where((conn) {
      if (conn.isProtected) return false;
      // Don't prune connections within the grace period.
      if (now.difference(conn.connectedAt) < _config.gracePeriod) return false;
      return true;
    }).toList();

    if (prunable.isEmpty) {
      _logger.verbose('Pruning needed but no prunable connections available');
      return;
    }

    // Sort by priority (lowest first), then by connection age (newest first).
    prunable.sort((a, b) {
      final priorityCmp = a.priority.compareTo(b.priority);
      if (priorityCmp != 0) return priorityCmp;
      // Newer connections are pruned before older ones at the same priority.
      return b.connectedAt.compareTo(a.connectedAt);
    });

    final toPrune = _connections.length - _config.lowWater;
    var pruned = 0;

    for (final conn in prunable) {
      if (pruned >= toPrune) break;
      _connections.remove(conn.peerId);
      _prunedConnections.add(conn.peerId);
      _logger.debug(
        'Pruned connection: ${conn.peerId} '
        '(priority: ${conn.priority}, tags: ${conn.tags})',
      );
      pruned++;
    }

    if (pruned > 0) {
      _logger.info(
        'Pruned $pruned connections '
        '(remaining: ${_connections.length})',
      );
    }
  }

  /// Forces an immediate pruning check. Returns the number of connections
  /// pruned.
  int pruneNow() {
    final before = _connections.length;
    _pruneIfNeeded();
    return before - _connections.length;
  }

  /// Returns a summary of the current connection state.
  Map<String, dynamic> getStats() {
    final tagCounts = <String, int>{};
    for (final conn in _connections.values) {
      for (final tag in conn.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    return {
      'total_connections': _connections.length,
      'high_water': _config.highWater,
      'low_water': _config.lowWater,
      'protected': _connections.values.where((c) => c.isProtected).length,
      'tag_counts': tagCounts,
    };
  }
}
