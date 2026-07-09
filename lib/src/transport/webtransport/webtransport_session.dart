/// WebTransport session management (RFC 9220 / draft-ietf-webtrans-http3).
///
/// This module provides a platform-agnostic [WebTransportSession] abstraction
/// that represents an established WebTransport session over HTTP/3. Sessions
/// are created via Extended CONNECT (RFC 9220 Section 4) and support:
///
/// - Opening bidirectional and unidirectional streams within the session.
/// - Sending and receiving unreliable datagrams.
/// - Graceful close with error codes and reason phrases.
/// - Drain signalling per RFC 9220 Section 4.3.
/// - Flow-control enforcement at session and stream granularity.
///
/// The class is backend-agnostic: platform-specific implementations (browser
/// WebTransport API or quic_lib HTTP/3 layer) provide callback functions for
/// stream creation, datagram I/O, and capsule exchange.
library;

import 'dart:async';
import 'dart:typed_data';

/// Configuration for a [WebTransportSession].
class WebTransportSessionConfig {
  /// Creates a new [WebTransportSessionConfig].
  const WebTransportSessionConfig({
    this.maxSessions = 100,
    this.maxDatagramSize = 1024,
    this.initialMaxData = 256 * 1024 * 1024,
    this.initialMaxStreamsBidi = 100,
    this.initialMaxStreamsUni = 100,
    this.sessionTimeout = const Duration(seconds: 30),
  });

  /// Maximum number of concurrent WebTransport sessions per connection.
  ///
  /// Corresponds to the implicit limit imposed by the number of available
  /// bidirectional streams. The server advertises this via HTTP/3 SETTINGS
  /// and the client must respect it.
  final int maxSessions;

  /// Maximum datagram size in bytes negotiated for this session.
  final int maxDatagramSize;

  /// Initial session-level flow-control credit (bytes).
  final int initialMaxData;

  /// Initial maximum number of bidirectional streams.
  final int initialMaxStreamsBidi;

  /// Initial maximum number of unidirectional streams.
  final int initialMaxStreamsUni;

  /// Timeout for session establishment.
  final Duration sessionTimeout;

  /// Default configuration.
  static const WebTransportSessionConfig defaultConfig =
      WebTransportSessionConfig();
}

/// Statistics for a [WebTransportSession].
class WebTransportSessionStats {
  /// Creates a new [WebTransportSessionStats].
  WebTransportSessionStats({
    this.openedAt,
    this.closedAt,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.datagramsSent = 0,
    this.datagramsReceived = 0,
    this.bidiStreamsOpened = 0,
    this.uniStreamsOpened = 0,
  });

  /// When the session was opened.
  final DateTime? openedAt;

  /// When the session was closed, or null if still open.
  DateTime? closedAt;

  /// Total bytes sent over all streams and datagrams.
  int bytesSent;

  /// Total bytes received over all streams and datagrams.
  int bytesReceived;

  /// Number of datagrams sent.
  int datagramsSent;

  /// Number of datagrams received.
  int datagramsReceived;

  /// Number of bidirectional streams opened.
  int bidiStreamsOpened;

  /// Number of unidirectional streams opened.
  int uniStreamsOpened;

  /// Duration the session has been (or was) open.
  Duration get duration =>
      (closedAt ?? DateTime.now()).difference(openedAt ?? DateTime.now());
}

/// Represents a bidirectional WebTransport stream.
///
/// A bidirectional stream allows both endpoints to send and receive data
/// reliably. Data written via [write] is delivered in order to the peer's
/// [read] side.
class WebTransportBidiStream {
  /// Creates a new [WebTransportBidiStream].
  ///
  /// [writeFn] sends data to the peer.
  /// [readFn] reads data from the peer (returns null on stream end).
  /// [closeFn] closes the stream gracefully.
  /// [resetFn] resets the stream abruptly.
  WebTransportBidiStream({
    required this.id,
    required Future<void> Function(Uint8List data) writeFn,
    required Future<Uint8List?> Function([int? len]) readFn,
    required Future<void> Function() closeFn,
    required Future<void> Function() resetFn,
  }) : _writeFn = writeFn,
       _readFn = readFn,
       _closeFn = closeFn,
       _resetFn = resetFn;

  /// The stream identifier (QUIC stream ID within the session).
  final int id;

  final Future<void> Function(Uint8List data) _writeFn;
  final Future<Uint8List?> Function([int? len]) _readFn;
  final Future<void> Function() _closeFn;
  final Future<void> Function() _resetFn;

  bool _isClosed = false;

  /// Whether this stream has been closed.
  bool get isClosed => _isClosed;

  /// Writes [data] to the stream.
  Future<void> write(Uint8List data) async {
    if (_isClosed) throw StateError('Stream $id is closed');
    await _writeFn(data);
  }

  /// Reads data from the stream.
  ///
  /// Returns null when the peer has closed the stream.
  Future<Uint8List?> read([int? len]) async {
    if (_isClosed) return null;
    return _readFn(len);
  }

  /// Closes the stream gracefully (sends FIN).
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _closeFn();
  }

  /// Resets the stream abruptly (sends RST_STREAM).
  Future<void> reset() async {
    if (_isClosed) return;
    _isClosed = true;
    await _resetFn();
  }
}

/// Represents a unidirectional WebTransport stream.
///
/// A unidirectional stream allows the initiator to send data reliably to the
/// peer. The peer can only read.
class WebTransportUniStream {
  /// Creates a new [WebTransportUniStream].
  ///
  /// [writeFn] sends data to the peer.
  /// [closeFn] closes the stream gracefully.
  /// [resetFn] resets the stream abruptly.
  WebTransportUniStream({
    required this.id,
    required Future<void> Function(Uint8List data) writeFn,
    required Future<void> Function() closeFn,
    required Future<void> Function() resetFn,
  }) : _writeFn = writeFn,
       _closeFn = closeFn,
       _resetFn = resetFn;

  /// The stream identifier (QUIC stream ID within the session).
  final int id;

  final Future<void> Function(Uint8List data) _writeFn;
  final Future<void> Function() _closeFn;
  final Future<void> Function() _resetFn;

  bool _isClosed = false;

  /// Whether this stream has been closed.
  bool get isClosed => _isClosed;

  /// Writes [data] to the stream.
  Future<void> write(Uint8List data) async {
    if (_isClosed) throw StateError('Stream $id is closed');
    await _writeFn(data);
  }

  /// Closes the stream gracefully (sends FIN).
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _closeFn();
  }

  /// Resets the stream abruptly (sends RESET_STREAM).
  Future<void> reset() async {
    if (_isClosed) return;
    _isClosed = true;
    await _resetFn();
  }
}

/// Callbacks that a platform-specific backend must provide to create a
/// [WebTransportSession].
abstract class WebTransportSessionBackend {
  /// Opens a bidirectional stream within the session.
  Future<WebTransportBidiStream> openBidirectionalStream();

  /// Opens a unidirectional stream within the session.
  Future<WebTransportUniStream> openUnidirectionalStream();

  /// Sends an unreliable datagram.
  Future<void> sendDatagram(Uint8List data);

  /// Closes the session with [errorCode] and optional [reasonPhrase].
  Future<void> closeSession({int errorCode, String? reasonPhrase});

  /// Sends a DRAIN capsule to the peer.
  Future<void> sendDrain();

  /// Stream of incoming bidirectional streams from the peer.
  Stream<WebTransportBidiStream>? get incomingBidiStreams;

  /// Stream of incoming unidirectional streams from the peer.
  Stream<WebTransportUniStream>? get incomingUniStreams;

  /// Stream of incoming datagrams from the peer.
  Stream<Uint8List>? get incomingDatagrams;
}

/// Represents an established WebTransport session over HTTP/3 (RFC 9220).
///
/// A [WebTransportSession] is created after a successful Extended CONNECT
/// exchange. It provides:
///
/// - [openBidirectionalStream] / [openUnidirectionalStream] for creating
///   reliable streams within the session.
/// - [sendDatagram] for sending unreliable datagrams.
/// - [close] for graceful session termination with an error code.
/// - [initiateDrain] for signalling that no new streams should be opened.
///
/// The session tracks all opened streams and enforces the configured maximum
/// session limits. Session state transitions (active → draining → closed)
/// follow RFC 9220 Section 4.
class WebTransportSession {
  /// Creates a new [WebTransportSession] backed by [backend].
  ///
  /// [sessionId] is the QUIC stream ID of the bidirectional control stream
  /// used for Extended CONNECT. [config] provides session-level limits.
  WebTransportSession({
    required this.sessionId,
    required WebTransportSessionBackend backend,
    WebTransportSessionConfig config = WebTransportSessionConfig.defaultConfig,
  }) : _backend = backend,
       _config = config {
    _stats = WebTransportSessionStats(openedAt: DateTime.now());
    _setupIncomingListeners();
  }

  /// The session identifier (QUIC stream ID of the Extended CONNECT stream).
  final int sessionId;

  final WebTransportSessionBackend _backend;
  final WebTransportSessionConfig _config;

  late final WebTransportSessionStats _stats;

  bool _isClosed = false;
  bool _isDraining = false;
  bool _receivedGoaway = false;

  final Map<int, WebTransportBidiStream> _bidiStreams = {};
  final Map<int, WebTransportUniStream> _uniStreams = {};

  final StreamController<WebTransportBidiStream> _incomingBidiController =
      StreamController<WebTransportBidiStream>.broadcast();
  final StreamController<WebTransportUniStream> _incomingUniController =
      StreamController<WebTransportUniStream>.broadcast();
  final StreamController<Uint8List> _incomingDatagramController =
      StreamController<Uint8List>.broadcast();

  /// Statistics for this session.
  WebTransportSessionStats get stats => _stats;

  /// The session configuration.
  WebTransportSessionConfig get config => _config;

  /// Whether the session has been closed (locally or by the peer).
  bool get isClosed => _isClosed;

  /// Whether the peer has initiated a drain.
  ///
  /// A draining session should finish existing streams but not open new ones.
  bool get isDraining => _isDraining;

  /// Whether the session is still active (not draining and not closed).
  bool get isActive => !_isClosed && !_isDraining;

  /// Whether a GOAWAY capsule has been received from the peer.
  bool get receivedGoaway => _receivedGoaway;

  /// Number of currently open bidirectional streams.
  int get openBidiStreamCount => _bidiStreams.length;

  /// Number of currently open unidirectional streams.
  int get openUniStreamCount => _uniStreams.length;

  /// Stream of incoming bidirectional streams opened by the peer.
  Stream<WebTransportBidiStream> get incomingBidiStreams =>
      _incomingBidiController.stream;

  /// Stream of incoming unidirectional streams opened by the peer.
  Stream<WebTransportUniStream> get incomingUniStreams =>
      _incomingUniController.stream;

  /// Stream of incoming datagrams from the peer.
  Stream<Uint8List> get incomingDatagrams => _incomingDatagramController.stream;

  /// All currently open bidirectional streams.
  List<WebTransportBidiStream> get bidiStreams =>
      List.unmodifiable(_bidiStreams.values);

  /// All currently open unidirectional streams.
  List<WebTransportUniStream> get uniStreams =>
      List.unmodifiable(_uniStreams.values);

  void _setupIncomingListeners() {
    _backend.incomingBidiStreams?.listen((stream) {
      if (!_isClosed) {
        _bidiStreams[stream.id] = stream;
        _incomingBidiController.add(stream);
      }
    });
    _backend.incomingUniStreams?.listen((stream) {
      if (!_isClosed) {
        _uniStreams[stream.id] = stream;
        _incomingUniController.add(stream);
      }
    });
    _backend.incomingDatagrams?.listen((data) {
      if (!_isClosed) {
        _stats.datagramsReceived++;
        _stats.bytesReceived += data.length;
        _incomingDatagramController.add(data);
      }
    });
  }

  /// Opens a bidirectional stream within this session.
  ///
  /// Throws [StateError] if the session is closed or draining.
  /// Throws [StateError] if the maximum bidirectional stream limit has been
  /// reached.
  Future<WebTransportBidiStream> openBidirectionalStream() async {
    _checkActive();

    if (_bidiStreams.length >= _config.initialMaxStreamsBidi) {
      throw StateError(
        'Maximum bidirectional stream limit '
        '(${_config.initialMaxStreamsBidi}) reached for session $sessionId',
      );
    }

    final stream = await _backend.openBidirectionalStream();
    _bidiStreams[stream.id] = stream;
    _stats.bidiStreamsOpened++;
    return stream;
  }

  /// Opens a unidirectional stream within this session.
  ///
  /// Throws [StateError] if the session is closed or draining.
  /// Throws [StateError] if the maximum unidirectional stream limit has been
  /// reached.
  Future<WebTransportUniStream> openUnidirectionalStream() async {
    _checkActive();

    if (_uniStreams.length >= _config.initialMaxStreamsUni) {
      throw StateError(
        'Maximum unidirectional stream limit '
        '(${_config.initialMaxStreamsUni}) reached for session $sessionId',
      );
    }

    final stream = await _backend.openUnidirectionalStream();
    _uniStreams[stream.id] = stream;
    _stats.uniStreamsOpened++;
    return stream;
  }

  /// Sends an unreliable datagram via this session.
  ///
  /// Datagrams are unordered and may be lost in transit. The maximum datagram
  /// size is limited by [WebTransportSessionConfig.maxDatagramSize].
  ///
  /// Throws [StateError] if the session is closed.
  /// Throws [ArgumentError] if the data exceeds the maximum datagram size.
  Future<void> sendDatagram(Uint8List data) async {
    if (_isClosed) {
      throw StateError('Session $sessionId is closed');
    }

    if (data.length > _config.maxDatagramSize) {
      throw ArgumentError(
        'Datagram size ${data.length} exceeds maximum '
        '${_config.maxDatagramSize} bytes',
      );
    }

    await _backend.sendDatagram(data);
    _stats.datagramsSent++;
    _stats.bytesSent += data.length;
  }

  /// Initiates a graceful close of this session.
  ///
  /// Sends a CLOSE_WEBTRANSPORT_SESSION capsule with [errorCode] and optional
  /// [reasonPhrase] per RFC 9220 Section 4.2. After calling this method, no
  /// new streams or datagrams may be sent.
  ///
  /// If the session is already closed, this is a no-op.
  Future<void> close({int errorCode = 0, String? reasonPhrase}) async {
    if (_isClosed) return;

    _isClosed = true;
    _stats.closedAt = DateTime.now();

    // Close all open streams.
    for (final stream in _bidiStreams.values) {
      try {
        await stream.close();
      } catch (_) {
        // Ignore errors when closing streams during session close.
      }
    }
    for (final stream in _uniStreams.values) {
      try {
        await stream.close();
      } catch (_) {
        // Ignore errors when closing streams during session close.
      }
    }

    _bidiStreams.clear();
    _uniStreams.clear();

    // Notify the backend to send the close capsule.
    try {
      await _backend.closeSession(
        errorCode: errorCode,
        reasonPhrase: reasonPhrase,
      );
    } catch (_) {
      // Backend may already be closed; ignore.
    }

    await _closeControllers();
  }

  /// Initiates a drain of this session.
  ///
  /// Sends a DRAIN_WEBTRANSPORT_SESSION capsule per RFC 9220 Section 4.3.
  /// A draining session should finish existing streams but not open new ones.
  ///
  /// Throws [StateError] if the session is closed.
  Future<void> initiateDrain() async {
    if (_isClosed) {
      throw StateError('Session $sessionId is closed');
    }

    _isDraining = true;
    await _backend.sendDrain();
  }

  /// Marks the session as closed after receiving a CLOSE capsule from the peer.
  ///
  /// This is called internally when the peer initiates the close. Unlike
  /// [close], this does not send a close capsule back to the peer.
  void onPeerClose({int errorCode = 0, String? reasonPhrase}) {
    if (_isClosed) return;

    _isClosed = true;
    _stats.closedAt = DateTime.now();
    _closeControllers();
  }

  /// Marks the session as draining after receiving a DRAIN capsule from the
  /// peer.
  void onPeerDrain() {
    _isDraining = true;
  }

  /// Marks that a GOAWAY capsule has been received from the peer.
  ///
  /// A GOAWAY signals that the server will no longer accept new sessions.
  /// Existing sessions and streams may continue until they complete.
  void onGoawayReceived() {
    _receivedGoaway = true;
  }

  /// Removes a closed stream from the session's tracking.
  void removeStream(int streamId) {
    _bidiStreams.remove(streamId);
    _uniStreams.remove(streamId);
  }

  void _checkActive() {
    if (_isClosed) {
      throw StateError('Session $sessionId is closed');
    }
    if (_isDraining) {
      throw StateError(
        'Session $sessionId is draining; no new streams allowed',
      );
    }
  }

  Future<void> _closeControllers() async {
    await _incomingBidiController.close();
    await _incomingUniController.close();
    await _incomingDatagramController.close();
  }
}

/// Manages multiple WebTransport sessions over a single connection.
///
/// Enforces the maximum concurrent session limit (SETTINGS_WT_MAX_SESSIONS).
/// The server advertises the max sessions via HTTP/3 SETTINGS and the client
/// must respect it by not exceeding the limit when creating new sessions.
class WebTransportSessionManager {
  /// Creates a new [WebTransportSessionManager].
  ///
  /// [maxSessions] is the maximum number of concurrent sessions allowed.
  /// Defaults to 100 per [WebTransportSessionConfig.defaultConfig].
  WebTransportSessionManager({int maxSessions = 100})
    : _maxSessions = maxSessions;

  final int _maxSessions;
  final Map<int, WebTransportSession> _sessions = {};

  /// Maximum number of concurrent sessions allowed.
  int get maxSessions => _maxSessions;

  /// Number of currently active sessions.
  int get sessionCount => _sessions.length;

  /// All currently active sessions.
  List<WebTransportSession> get sessions => List.unmodifiable(_sessions.values);

  /// Whether the maximum session limit has been reached.
  bool get isFull => _sessions.length >= _maxSessions;

  /// Registers a new session with the manager.
  ///
  /// Throws [StateError] if the maximum session limit has been reached.
  void registerSession(WebTransportSession session) {
    if (_sessions.length >= _maxSessions) {
      throw StateError(
        'Maximum WebTransport session limit ($_maxSessions) reached; '
        'cannot register session ${session.sessionId}',
      );
    }
    if (_sessions.containsKey(session.sessionId)) {
      throw StateError('Session ${session.sessionId} already registered');
    }
    _sessions[session.sessionId] = session;
  }

  /// Retrieves a session by its session ID, or null if not found.
  WebTransportSession? getSession(int sessionId) => _sessions[sessionId];

  /// Removes a session from the manager.
  void removeSession(int sessionId) {
    _sessions.remove(sessionId);
  }

  /// Closes all active sessions and clears the registry.
  Future<void> closeAll() async {
    final futures = <Future<void>>[];
    for (final session in _sessions.values) {
      if (session.isActive) {
        futures.add(session.close());
      }
    }
    await Future.wait(futures);
    _sessions.clear();
  }

  /// Removes all closed or draining sessions from the registry.
  ///
  /// Returns the number of sessions removed.
  int cleanupInactive() {
    var removed = 0;
    _sessions.removeWhere((_, session) {
      if (session.isClosed || session.isDraining) {
        removed++;
        return true;
      }
      return false;
    });
    return removed;
  }
}

/// HTTP/3 SETTINGS identifiers for WebTransport (draft-ietf-webtrans-http3).
///
/// These extend the standard HTTP/3 SETTINGS frame with WebTransport-specific
/// parameters. The server advertises these in its SETTINGS frame and the
/// client uses them to configure session limits.
class WebTransportSettings {
  /// SETTINGS_ENABLE_CONNECT_PROTOCOL (0x08) per RFC 9220.
  ///
  /// Must be set to 1 for Extended CONNECT to be allowed.
  static const int enableConnectProtocol = 0x08;

  /// SETTINGS_H3_DATAGRAM (0x33) per RFC 9297.
  ///
  /// Must be set to 1 for HTTP/3 datagrams (used by WebTransport datagrams)
  /// to be enabled.
  static const int h3Datagram = 0x33;

  /// SETTINGS_WEBTRANSPORT_ENABLED (0x2c7cf000) per
  /// draft-ietf-webtrans-http3 Section 3.1.
  ///
  /// Set to 1 to advertise WebTransport support.
  static const int wtEnabled = 0x2c7cf000;

  /// SETTINGS_WEBTRANSPORT_INITIAL_MAX_DATA (0x2b61) per
  /// draft-ietf-webtrans-http3 Section 5.5.3.
  ///
  /// Initial session-level flow-control limit in bytes.
  static const int wtInitialMaxData = 0x2b61;

  /// SETTINGS_WEBTRANSPORT_INITIAL_MAX_STREAMS_UNI (0x2b64) per
  /// draft-ietf-webtrans-http3 Section 5.5.1.
  ///
  /// Initial maximum number of unidirectional streams per session.
  static const int wtInitialMaxStreamsUni = 0x2b64;

  /// SETTINGS_WEBTRANSPORT_INITIAL_MAX_STREAMS_BIDI (0x2b65) per
  /// draft-ietf-webtrans-http3 Section 5.5.2.
  ///
  /// Initial maximum number of bidirectional streams per session.
  static const int wtInitialMaxStreamsBidi = 0x2b65;

  /// SETTINGS_WT_MAX_SESSIONS — maximum concurrent WebTransport sessions.
  ///
  /// This is a dart_ipfs extension that advertises the maximum number of
  /// concurrent WebTransport sessions the server will accept. The client
  /// must not exceed this limit when creating new sessions.
  ///
  /// Uses setting ID 0x2b66, which is the next available value after
  /// SETTINGS_WEBTRANSPORT_INITIAL_MAX_STREAMS_BIDI (0x2b65) in the
  /// WebTransport HTTP/3 settings space.
  static const int wtMaxSessions = 0x2b66;

  /// Parses WebTransport-related settings from a raw settings map.
  ///
  /// [settings] maps raw setting identifier values to their values, as
  /// received in an HTTP/3 SETTINGS frame.
  static WebTransportSettingsParsed parse(Map<int, int> settings) {
    return WebTransportSettingsParsed(
      connectProtocolEnabled: (settings[enableConnectProtocol] ?? 0) != 0,
      h3DatagramEnabled: (settings[h3Datagram] ?? 0) != 0,
      wtEnabled: (settings[wtEnabled] ?? 0) != 0,
      wtInitialMaxData: settings[wtInitialMaxData] ?? 0,
      wtInitialMaxStreamsUni: settings[wtInitialMaxStreamsUni] ?? 0,
      wtInitialMaxStreamsBidi: settings[wtInitialMaxStreamsBidi] ?? 0,
      wtMaxSessions:
          settings[wtMaxSessions] ?? settings[wtInitialMaxStreamsBidi] ?? 100,
    );
  }

  /// Builds a settings map suitable for inclusion in an HTTP/3 SETTINGS frame.
  ///
  /// [maxSessions] is the maximum concurrent sessions to advertise.
  /// [enableDatagrams] controls whether HTTP/3 datagrams are enabled.
  static Map<int, int> buildServerSettings({
    int maxSessions = 100,
    bool enableDatagrams = true,
    int initialMaxData = 256 * 1024 * 1024,
    int initialMaxStreamsBidi = 100,
    int initialMaxStreamsUni = 100,
  }) {
    return {
      enableConnectProtocol: 1,
      if (enableDatagrams) h3Datagram: 1,
      wtEnabled: 1,
      wtInitialMaxData: initialMaxData,
      wtInitialMaxStreamsBidi: initialMaxStreamsBidi,
      wtInitialMaxStreamsUni: initialMaxStreamsUni,
      wtMaxSessions: maxSessions,
    };
  }

  /// Builds a settings map for a client connecting to a WebTransport server.
  static Map<int, int> buildClientSettings({bool enableDatagrams = true}) {
    return {
      enableConnectProtocol: 1,
      if (enableDatagrams) h3Datagram: 1,
      wtEnabled: 1,
    };
  }
}

/// Parsed WebTransport settings from an HTTP/3 SETTINGS frame.
class WebTransportSettingsParsed {
  /// Creates a new [WebTransportSettingsParsed].
  const WebTransportSettingsParsed({
    required this.connectProtocolEnabled,
    required this.h3DatagramEnabled,
    required this.wtEnabled,
    required this.wtInitialMaxData,
    required this.wtInitialMaxStreamsUni,
    required this.wtInitialMaxStreamsBidi,
    required this.wtMaxSessions,
  });

  /// Whether Extended CONNECT (RFC 9220) is enabled by the peer.
  final bool connectProtocolEnabled;

  /// Whether HTTP/3 datagrams (RFC 9297) are enabled by the peer.
  final bool h3DatagramEnabled;

  /// Whether WebTransport is enabled by the peer.
  final bool wtEnabled;

  /// Initial session-level flow-control limit in bytes.
  final int wtInitialMaxData;

  /// Initial maximum number of unidirectional streams per session.
  final int wtInitialMaxStreamsUni;

  /// Initial maximum number of bidirectional streams per session.
  final int wtInitialMaxStreamsBidi;

  /// Maximum concurrent WebTransport sessions.
  final int wtMaxSessions;

  /// Whether WebTransport is fully supported (Extended CONNECT + WT enabled).
  bool get isWebTransportSupported => connectProtocolEnabled && wtEnabled;

  /// Whether datagrams are supported (WT enabled + H3 datagram enabled).
  bool get areDatagramsSupported => wtEnabled && h3DatagramEnabled;
}
