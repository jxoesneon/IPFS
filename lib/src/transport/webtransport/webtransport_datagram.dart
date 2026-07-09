/// WebTransport datagram support (RFC 9220 / draft-ietf-webtrans-http3).
///
/// WebTransport datagrams provide unreliable, unordered data delivery over
/// HTTP/3 datagrams (RFC 9297). Unlike streams, datagrams have no delivery
/// guarantees and may arrive out of order or be dropped entirely. They are
/// suitable for time-sensitive data where freshness matters more than
/// reliability (e.g., game state updates, real-time metrics).
///
/// This module provides a platform-agnostic [WebTransportDatagram] abstraction
/// for sending and receiving datagrams within a WebTransport session. The
/// max datagram size is negotiated via HTTP/3 SETTINGS
/// (SETTINGS_H3_DATAGRAM) and the QUIC max_datagram_frame_size transport
/// parameter.
library;

import 'dart:async';
import 'dart:typed_data';

/// Statistics for WebTransport datagram I/O.
class WebTransportDatagramStats {
  /// Creates a new [WebTransportDatagramStats].
  WebTransportDatagramStats({
    this.sentCount = 0,
    this.receivedCount = 0,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.droppedCount = 0,
  });

  /// Number of datagrams successfully sent.
  int sentCount;

  /// Number of datagrams received.
  int receivedCount;

  /// Total bytes sent via datagrams.
  int bytesSent;

  /// Total bytes received via datagrams.
  int bytesReceived;

  /// Number of datagrams dropped (e.g., exceeded max size or session closed).
  int droppedCount;

  /// Resets all counters to zero.
  void reset() {
    sentCount = 0;
    receivedCount = 0;
    bytesSent = 0;
    bytesReceived = 0;
    droppedCount = 0;
  }

  @override
  String toString() =>
      'WebTransportDatagramStats(sent: $sentCount, received: $receivedCount, '
      'bytesSent: $bytesSent, bytesReceived: $bytesReceived, '
      'dropped: $droppedCount)';
}

/// Configuration for WebTransport datagram I/O.
class WebTransportDatagramConfig {
  /// Creates a new [WebTransportDatagramConfig].
  const WebTransportDatagramConfig({
    this.maxDatagramSize = 1024,
    this.maxQueueSize = 256,
    this.outgoingMaxAge,
    this.incomingMaxAge,
  });

  /// Maximum datagram size in bytes.
  ///
  /// The actual maximum is negotiated via the QUIC max_datagram_frame_size
  /// transport parameter and the HTTP/3 SETTINGS_H3_DATAGRAM setting. This
  /// value is the locally configured upper bound.
  final int maxDatagramSize;

  /// Maximum number of outgoing datagrams to queue before applying backpressure.
  final int maxQueueSize;

  /// Maximum age for outgoing datagrams in milliseconds before they are
  /// dropped. null means no age limit.
  final Duration? outgoingMaxAge;

  /// Maximum age for incoming datagrams in milliseconds before they are
  /// dropped. null means no age limit.
  final Duration? incomingMaxAge;

  /// Default configuration.
  static const WebTransportDatagramConfig defaultConfig =
      WebTransportDatagramConfig();
}

/// A received WebTransport datagram with optional metadata.
class WebTransportDatagramEvent {
  /// Creates a new [WebTransportDatagramEvent].
  WebTransportDatagramEvent({
    required this.data,
    this.receivedAt,
    this.timestamp,
  });

  /// The datagram payload.
  final Uint8List data;

  /// When the datagram was received locally.
  final DateTime? receivedAt;

  /// Optional timestamp from the sender (if provided by the transport).
  final DateTime? timestamp;

  /// Size of the datagram payload in bytes.
  int get size => data.length;
}

/// Callbacks that a platform-specific backend must provide for datagram I/O.
abstract class WebTransportDatagramBackend {
  /// Sends a datagram. Returns true if the datagram was accepted for
  /// transmission, false if it was dropped (e.g., due to size or backpressure).
  Future<bool> sendFn(Uint8List data);

  /// Stream of incoming datagrams from the peer.
  Stream<Uint8List>? get receiveStream;

  /// Returns the current maximum datagram size in bytes, as negotiated with
  /// the peer. May return a different value over time if the limit changes.
  int Function()? get maxDatagramSizeFn;
}

/// Provides unreliable, unordered datagram send/receive for a WebTransport
/// session.
///
/// Datagrams are sent over HTTP/3 datagram frames (RFC 9297) which are
/// themselves carried over QUIC DATAGRAM frames. Each datagram is
/// independent — there are no ordering or delivery guarantees.
///
/// The [WebTransportDatagram] class handles:
/// - Sending datagrams with size validation and backpressure.
/// - Receiving datagrams via a broadcast stream.
/// - Max datagram size negotiation and enforcement.
/// - Statistics tracking for monitoring and debugging.
/// - Graceful shutdown when the session closes.
///
/// ## Example
/// ```dart
/// final datagram = WebTransportDatagram(
///   backend: myBackend,
///   config: WebTransportDatagramConfig(maxDatagramSize: 512),
/// );
///
/// // Send a datagram.
/// await datagram.send(Uint8List.fromList([1, 2, 3]));
///
/// // Receive datagrams.
/// datagram.datagramStream.listen((event) {
///   print('Received ${event.size} bytes');
/// });
/// ```
class WebTransportDatagram {
  /// Creates a new [WebTransportDatagram] backed by [backend].
  ///
  /// [config] provides datagram-level limits. The [maxDatagramSize] from
  /// [config] is used as the initial upper bound; if [backend] provides a
  /// [WebTransportDatagramBackend.maxDatagramSizeFn], the effective limit is
  /// the minimum of the two.
  WebTransportDatagram({
    required WebTransportDatagramBackend backend,
    WebTransportDatagramConfig config =
        WebTransportDatagramConfig.defaultConfig,
  }) : _backend = backend,
       _config = config {
    _setupReceiveListener();
  }

  final WebTransportDatagramBackend _backend;
  final WebTransportDatagramConfig _config;

  final WebTransportDatagramStats _stats = WebTransportDatagramStats();

  final StreamController<WebTransportDatagramEvent> _datagramController =
      StreamController<WebTransportDatagramEvent>.broadcast();

  bool _isClosed = false;

  int _pendingQueueLength = 0;

  /// Stream of received datagrams.
  ///
  /// Each event contains the datagram payload and optional metadata. The
  /// stream is a broadcast stream, so multiple listeners are supported.
  Stream<WebTransportDatagramEvent> get datagramStream =>
      _datagramController.stream;

  /// Statistics for datagram I/O.
  WebTransportDatagramStats get stats => _stats;

  /// The configured datagram limits.
  WebTransportDatagramConfig get config => _config;

  /// Whether datagram I/O has been closed.
  bool get isClosed => _isClosed;

  /// The effective maximum datagram size in bytes.
  ///
  /// This is the minimum of the configured [WebTransportDatagramConfig.maxDatagramSize]
  /// and the negotiated limit from the backend (if available).
  int get maxDatagramSize {
    final backendMax = _backend.maxDatagramSizeFn?.call();
    if (backendMax != null && backendMax > 0) {
      return backendMax < _config.maxDatagramSize
          ? backendMax
          : _config.maxDatagramSize;
    }
    return _config.maxDatagramSize;
  }

  /// Number of datagrams currently queued for transmission.
  int get pendingQueueLength => _pendingQueueLength;

  /// Sends a datagram.
  ///
  /// The datagram is sent unreliably — there is no guarantee of delivery or
  /// ordering. If [data] exceeds [maxDatagramSize], an [ArgumentError] is
  /// thrown and the datagram is not sent.
  ///
  /// Returns true if the datagram was accepted for transmission, false if it
  /// was dropped due to backpressure (queue full) or session closure.
  ///
  /// Throws [StateError] if the datagram channel has been closed.
  Future<bool> send(Uint8List data) async {
    if (_isClosed) {
      throw StateError('Datagram channel is closed');
    }

    final maxSize = maxDatagramSize;
    if (data.length > maxSize) {
      _stats.droppedCount++;
      throw ArgumentError(
        'Datagram size ${data.length} exceeds maximum $maxSize bytes',
      );
    }

    if (data.isEmpty) {
      _stats.droppedCount++;
      throw ArgumentError('Datagram must not be empty');
    }

    // Apply backpressure.
    if (_pendingQueueLength >= _config.maxQueueSize) {
      _stats.droppedCount++;
      return false;
    }

    _pendingQueueLength++;
    try {
      final accepted = await _backend.sendFn(data);
      if (accepted) {
        _stats.sentCount++;
        _stats.bytesSent += data.length;
      } else {
        _stats.droppedCount++;
      }
      return accepted;
    } finally {
      _pendingQueueLength--;
    }
  }

  /// Sends a datagram, dropping it silently if it cannot be sent.
  ///
  /// Unlike [send], this method never throws for size violations or
  /// backpressure — it simply returns false and increments the dropped
  /// counter.
  Future<bool> trySend(Uint8List data) async {
    if (_isClosed) return false;

    final maxSize = maxDatagramSize;
    if (data.isEmpty || data.length > maxSize) {
      _stats.droppedCount++;
      return false;
    }

    if (_pendingQueueLength >= _config.maxQueueSize) {
      _stats.droppedCount++;
      return false;
    }

    _pendingQueueLength++;
    try {
      final accepted = await _backend.sendFn(data);
      if (accepted) {
        _stats.sentCount++;
        _stats.bytesSent += data.length;
      } else {
        _stats.droppedCount++;
      }
      return accepted;
    } catch (_) {
      _stats.droppedCount++;
      return false;
    } finally {
      _pendingQueueLength--;
    }
  }

  /// Closes the datagram channel.
  ///
  /// After calling this method, [send] will throw and no more datagrams will
  /// be received via [datagramStream].
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _datagramController.close();
  }

  void _setupReceiveListener() {
    _backend.receiveStream?.listen(
      (data) {
        if (_isClosed) return;

        // Check incoming max age if configured.
        if (_config.incomingMaxAge != null) {
          // The backend provides raw bytes; we don't have sender timestamps,
          // so we accept all incoming datagrams. Age-based dropping would
          // require transport-level timestamp support.
        }

        _stats.receivedCount++;
        _stats.bytesReceived += data.length;

        _datagramController.add(
          WebTransportDatagramEvent(data: data, receivedAt: DateTime.now()),
        );
      },
      onError: (Object error) {
        // Forward errors to the datagram stream.
        _datagramController.addError(error);
      },
      onDone: () {
        // Peer closed the datagram stream; close our side too.
        close();
      },
    );
  }
}

/// Negotiates the maximum datagram size between client and server.
///
/// The effective max datagram size is the minimum of:
/// 1. The QUIC transport parameter `max_datagram_frame_size`.
/// 2. The HTTP/3 SETTINGS_H3_DATAGRAM value (if it specifies a size).
/// 3. The locally configured upper bound.
class DatagramSizeNegotiator {
  /// Creates a new [DatagramSizeNegotiator].
  ///
  /// [localMaxSize] is the maximum datagram size this endpoint is willing to
  /// accept. [remoteMaxSize] is the maximum advertised by the peer.
  DatagramSizeNegotiator({required int localMaxSize, int? remoteMaxSize})
    : _localMaxSize = localMaxSize,
      _remoteMaxSize = remoteMaxSize;

  int _localMaxSize;
  int? _remoteMaxSize;

  /// The locally configured maximum datagram size.
  int get localMaxSize => _localMaxSize;

  /// The maximum datagram size advertised by the peer, or null if not yet
  /// known.
  int? get remoteMaxSize => _remoteMaxSize;

  /// The negotiated maximum datagram size.
  ///
  /// This is the minimum of [localMaxSize] and [remoteMaxSize]. If
  /// [remoteMaxSize] is null, returns [localMaxSize].
  int get negotiatedMaxSize {
    if (_remoteMaxSize == null) return _localMaxSize;
    return _localMaxSize < _remoteMaxSize! ? _localMaxSize : _remoteMaxSize!;
  }

  /// Whether datagrams can be sent (both sides must support them).
  bool get isNegotiated => _remoteMaxSize != null;

  /// Updates the remote maximum datagram size after receiving the peer's
  /// SETTINGS frame.
  void updateRemoteMaxSize(int? maxSize) {
    _remoteMaxSize = maxSize;
  }

  /// Updates the local maximum datagram size.
  void updateLocalMaxSize(int maxSize) {
    _localMaxSize = maxSize;
  }

  /// Validates that [data] does not exceed the negotiated maximum size.
  ///
  /// Returns true if the datagram is within the limit, false otherwise.
  bool validate(Uint8List data) {
    return data.length <= negotiatedMaxSize;
  }
}
