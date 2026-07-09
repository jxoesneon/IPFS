import 'dart:async';

import 'package:ipfs_libp2p/dart_libp2p.dart' as libp2p;
import 'package:ipfs_libp2p/p2p/transport/listener.dart' as libp2p_listener;
import 'package:ipfs_libp2p/p2p/transport/transport.dart' as libp2p_trans;
import 'package:ipfs_libp2p/p2p/transport/transport_config.dart'
    as libp2p_config;

import 'webtransport_dialer.dart';
import 'webtransport_listener.dart';
import 'webtransport_session.dart';

/// WebTransport transport implementation for libp2p.
///
/// Wraps the HTTP/3-based WebTransport protocol with a session registry that
/// enforces a maximum number of concurrent sessions ([maxSessions]) and
/// exposes HTTP/3 SETTINGS negotiation helpers ([buildServerSettings],
/// [buildClientSettings], [validatePeerSettings]).
class WebTransportTransport implements libp2p_trans.Transport {
  /// Creates a new [WebTransportTransport].
  ///
  /// [maxSessions] bounds the number of concurrently-registered sessions.
  /// [maxDatagramSize] configures the default datagram size limit advertised
  /// to peers.
  WebTransportTransport({int maxSessions = 100, int maxDatagramSize = 1024})
    : _sessionManager = WebTransportSessionManager(maxSessions: maxSessions),
      _defaultSessionConfig = WebTransportSessionConfig(
        maxSessions: maxSessions,
        maxDatagramSize: maxDatagramSize,
      );

  final WebTransportSessionManager _sessionManager;
  final WebTransportSessionConfig _defaultSessionConfig;
  bool _disposed = false;

  /// Maximum number of concurrently-registered sessions.
  int get maxSessions => _sessionManager.maxSessions;

  /// Number of currently active (registered) sessions.
  int get activeSessionCount => _sessionManager.sessionCount;

  /// Whether the maximum session limit has been reached.
  bool get isSessionLimitReached => _sessionManager.isFull;

  /// The underlying session manager.
  WebTransportSessionManager get sessionManager => _sessionManager;

  /// Default session configuration advertised to peers.
  WebTransportSessionConfig get defaultSessionConfig => _defaultSessionConfig;

  /// Registers an active session with the transport.
  ///
  /// Throws [StateError] if the session limit has been reached or a session
  /// with the same id is already registered.
  void registerSession(WebTransportSession session) {
    _sessionManager.registerSession(session);
  }

  /// Retrieves a registered session by id, or `null` if not found.
  WebTransportSession? getSession(int sessionId) =>
      _sessionManager.getSession(sessionId);

  /// Removes a session from the registry.
  void removeSession(int sessionId) {
    _sessionManager.removeSession(sessionId);
  }

  /// Builds the HTTP/3 SETTINGS map advertised by the server.
  Map<int, int> buildServerSettings() {
    return WebTransportSettings.buildServerSettings(
      maxSessions: maxSessions,
      initialMaxData: _defaultSessionConfig.initialMaxData,
      initialMaxStreamsBidi: _defaultSessionConfig.initialMaxStreamsBidi,
      initialMaxStreamsUni: _defaultSessionConfig.initialMaxStreamsUni,
    );
  }

  /// Builds the HTTP/3 SETTINGS map sent by the client.
  Map<int, int> buildClientSettings() {
    return WebTransportSettings.buildClientSettings();
  }

  /// Validates and parses peer-supplied HTTP/3 SETTINGS.
  ///
  /// Throws [StateError] if the peer does not advertise WebTransport support
  /// (Extended CONNECT + WT enabled).
  WebTransportSettingsParsed validatePeerSettings(Map<int, int> settings) {
    final parsed = WebTransportSettings.parse(settings);
    if (!parsed.wtEnabled) {
      throw StateError(
        'Peer does not advertise WebTransport support (SETTINGS_WEBTRANSPORT_ENABLED missing)',
      );
    }
    if (!parsed.connectProtocolEnabled) {
      throw StateError(
        'Peer does not support Extended CONNECT (SETTINGS_ENABLE_CONNECT_PROTOCOL missing)',
      );
    }
    if (!parsed.isWebTransportSupported) {
      throw StateError(
        'Peer settings do not indicate full WebTransport support',
      );
    }
    return parsed;
  }

  @override
  libp2p_config.TransportConfig get config =>
      const libp2p_config.TransportConfig();

  @override
  bool canDial(libp2p.MultiAddr addr) {
    return addr.toString().contains('/webtransport');
  }

  @override
  bool canListen(libp2p.MultiAddr addr) {
    return canDial(addr);
  }

  @override
  Future<libp2p.Conn> dial(libp2p.MultiAddr addr, {Duration? timeout}) async {
    final dialer = createWebTransportDialer();
    final dialTimeout = timeout ?? const Duration(seconds: 30);
    return dialer.dial(addr).timeout(dialTimeout);
  }

  @override
  Future<libp2p_listener.Listener> listen(libp2p.MultiAddr addr) async {
    return WebTransportListener(addr);
  }

  @override
  List<String> get protocols => const ['/webtransport'];

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sessionManager.closeAll();
  }
}
