// lib/src/protocols/bitswap/bitswap_session.dart
import '../../utils/logger.dart';

/// A Bitswap session that groups related block requests for optimized
/// peer discovery and block fetching.
///
/// Sessions are introduced in Bitswap 1.2+ and enhanced in 1.4 with:
/// - Peer discovery within a session (broadcast wants to session peers)
/// - Split latency-based peer discovery
/// - Have-all optimization (peer indicates it has all blocks for a session)
class BitswapSession {
  /// Creates a new session with a unique [id].
  BitswapSession({
    required this.id,
    this.priority = 1,
    this.broadcastThreshold = 3,
    Logger? logger,
  }) : _logger = logger ?? Logger('BitswapSession');

  /// Unique session identifier.
  final int id;

  /// Priority for wants in this session (higher = more urgent).
  final int priority;

  /// Number of peers to broadcast initial wants to before switching to
  /// targeted requests. This implements the split latency-based peer
  /// discovery: initially broadcast to a few peers, then target peers
  /// that respond with HAVE.
  final int broadcastThreshold;

  final Logger _logger;

  /// CIDs that this session is interested in.
  final Set<String> _interestedCids = {};

  /// Peers that have been discovered for this session.
  final Set<String> _sessionPeers = {};

  /// Peers that indicated they have all blocks for this session.
  final Set<String> _haveAllPeers = {};

  /// Map of CID to peers that have reported HAVE.
  final Map<String, Set<String>> _providers = {};

  /// Map of peer ID to average latency in milliseconds.
  final Map<String, int> _peerLatency = {};

  /// Whether the session is still active.
  bool _active = true;

  /// Whether the session is active.
  bool get isActive => _active;

  /// Returns the set of CIDs this session is interested in.
  Set<String> get interestedCids => Set.unmodifiable(_interestedCids);

  /// Returns the set of peers discovered for this session.
  Set<String> get sessionPeers => Set.unmodifiable(_sessionPeers);

  /// Returns the set of peers that indicated they have all blocks.
  Set<String> get haveAllPeers => Set.unmodifiable(_haveAllPeers);

  /// Adds a CID to the session's interest set.
  void addInterest(String cid) {
    if (!_active) return;
    _interestedCids.add(cid);
  }

  /// Removes a CID from the session's interest set.
  void removeInterest(String cid) {
    _interestedCids.remove(cid);
    _providers.remove(cid);
  }

  /// Returns whether the session is interested in [cid].
  bool isInterestedIn(String cid) => _interestedCids.contains(cid);

  /// Adds a peer to the session.
  void addPeer(String peerId, {int? latencyMs}) {
    if (!_active) return;
    _sessionPeers.add(peerId);
    if (latencyMs != null) {
      _peerLatency[peerId] = latencyMs;
    }
    _logger.verbose('Session $id: added peer $peerId');
  }

  /// Removes a peer from the session.
  void removePeer(String peerId) {
    _sessionPeers.remove(peerId);
    _peerLatency.remove(peerId);
    _haveAllPeers.remove(peerId);
    for (final providers in _providers.values) {
      providers.remove(peerId);
    }
  }

  /// Records that a peer has a specific CID (HAVE response).
  void recordHave(String peerId, String cid) {
    if (!_active) return;
    _providers.putIfAbsent(cid, () => <String>{}).add(peerId);
    _sessionPeers.add(peerId);
    _logger.verbose('Session $id: peer $peerId HAVE $cid');
  }

  /// Records that a peer does not have a specific CID (DONT_HAVE response).
  void recordDontHave(String peerId, String cid) {
    _providers[cid]?.remove(peerId);
  }

  /// Marks a peer as having all blocks for this session (have-all
  /// optimization).
  ///
  /// When a peer indicates it has all blocks, future wants are sent
  /// exclusively to that peer until it fails to provide a block.
  void markPeerHasAll(String peerId) {
    if (!_active) return;
    _haveAllPeers.add(peerId);
    _logger.debug('Session $id: peer $peerId indicated have-all');
  }

  /// Removes a peer from the have-all set (e.g., when it fails to provide
  /// a requested block).
  void unmarkPeerHasAll(String peerId) {
    _haveAllPeers.remove(peerId);
  }

  /// Returns the peers that should be targeted for a want request for [cid].
  ///
  /// This implements the split latency-based peer discovery strategy:
  /// 1. If any have-all peers exist, target them first.
  /// 2. If known providers for [cid] exist, target them.
  /// 3. Otherwise, return all session peers for a broadcast.
  /// Returns an empty set if no peers are available.
  Set<String> targetPeersForWant(String cid) {
    if (!_active) return {};
    // Have-all peers get priority.
    if (_haveAllPeers.isNotEmpty) {
      return Set.from(_haveAllPeers);
    }
    // Known providers for this CID.
    final providers = _providers[cid];
    if (providers != null && providers.isNotEmpty) {
      return Set.from(providers);
    }
    // Fall back to all session peers.
    return Set.from(_sessionPeers);
  }

  /// Returns whether the session should broadcast a want for [cid] to all
  /// connected peers (as opposed to targeting specific session peers).
  ///
  /// A broadcast is needed when the session has fewer than
  /// [broadcastThreshold] peers, or when no provider is known for [cid].
  bool shouldBroadcast(String cid) {
    if (_sessionPeers.length < broadcastThreshold) return true;
    final providers = _providers[cid];
    return providers == null || providers.isEmpty;
  }

  /// Returns the average latency for a peer, or null if unknown.
  int? getPeerLatency(String peerId) => _peerLatency[peerId];

  /// Updates the latency for a peer.
  void updatePeerLatency(String peerId, int latencyMs) {
    _peerLatency[peerId] = latencyMs;
  }

  /// Returns the peers sorted by latency (lowest first).
  List<String> peersByLatency() {
    final peers = _sessionPeers.toList();
    peers.sort((a, b) {
      final la = _peerLatency[a] ?? 0x7fffffff;
      final lb = _peerLatency[b] ?? 0x7fffffff;
      return la.compareTo(lb);
    });
    return peers;
  }

  /// Closes the session, clearing all state.
  void close() {
    _active = false;
    _interestedCids.clear();
    _sessionPeers.clear();
    _haveAllPeers.clear();
    _providers.clear();
    _peerLatency.clear();
    _logger.debug('Session $id closed');
  }
}

/// Manages Bitswap sessions for optimized block fetching.
///
/// The session manager creates and tracks sessions, assigns unique IDs, and
/// provides lookup by session ID. It implements the Bitswap 1.4 session
/// management enhancements.
class BitswapSessionManager {
  /// Creates a new session manager.
  BitswapSessionManager({Logger? logger})
    : _logger = logger ?? Logger('BitswapSessionManager');

  final Logger _logger;

  /// Map of session ID to session.
  final Map<int, BitswapSession> _sessions = {};

  /// Counter for generating unique session IDs.
  int _nextId = 1;

  /// Whether the manager is running.
  bool _running = false;

  /// Creates a new session with an auto-assigned ID.
  ///
  /// Returns the new session.
  BitswapSession createSession({int priority = 1, int broadcastThreshold = 3}) {
    final id = _nextId++;
    final session = BitswapSession(
      id: id,
      priority: priority,
      broadcastThreshold: broadcastThreshold,
      logger: _logger,
    );
    _sessions[id] = session;
    _logger.debug('Created session $id');
    return session;
  }

  /// Returns the session with the given [id], or null if not found.
  BitswapSession? getSession(int id) => _sessions[id];

  /// Closes and removes a session by [id].
  void closeSession(int id) {
    final session = _sessions.remove(id);
    session?.close();
  }

  /// Returns all active sessions.
  List<BitswapSession> get activeSessions =>
      _sessions.values.where((s) => s.isActive).toList();

  /// Returns the number of active sessions.
  int get activeSessionCount =>
      _sessions.values.where((s) => s.isActive).length;

  /// Starts the session manager.
  void start() {
    _running = true;
    _logger.info('BitswapSessionManager started');
  }

  /// Stops the session manager and closes all sessions.
  void stop() {
    _running = false;
    for (final session in _sessions.values) {
      session.close();
    }
    _sessions.clear();
    _logger.info('BitswapSessionManager stopped');
  }

  /// Whether the manager is running.
  bool get isRunning => _running;

  /// Finds sessions interested in a given CID.
  ///
  /// This is used when a block is received to notify all interested sessions.
  List<BitswapSession> sessionsInterestedIn(String cid) {
    return _sessions.values
        .where((s) => s.isActive && s.isInterestedIn(cid))
        .toList();
  }

  /// Records a HAVE response from a peer for a CID across all interested
  /// sessions.
  void recordHave(String peerId, String cid) {
    for (final session in sessionsInterestedIn(cid)) {
      session.recordHave(peerId, cid);
    }
  }

  /// Records a DONT_HAVE response from a peer for a CID across all
  /// interested sessions.
  void recordDontHave(String peerId, String cid) {
    for (final session in sessionsInterestedIn(cid)) {
      session.recordDontHave(peerId, cid);
    }
  }

  /// Marks a peer as having all blocks for a session.
  void markPeerHasAll(int sessionId, String peerId) {
    _sessions[sessionId]?.markPeerHasAll(peerId);
  }
}
