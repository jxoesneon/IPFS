// lib/src/protocols/ping/ping_handler.dart
//
// libp2p Ping protocol handler.
//
// Protocol ID: /ipfs/ping/1.0.0
//
// The ping protocol is a simple liveness check. The dialing peer sends a
// 32-byte random payload; the listening peer echoes it back. The dialing
// peer measures the round-trip time.
//
// Spec: https://github.com/libp2p/specs/blob/master/ping/ping.md

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../transport/router_interface.dart';
import '../../utils/logger.dart';

/// The protocol ID for the ping protocol.
const String pingProtocolId = '/ipfs/ping/1.0.0';

/// The size of a ping payload in bytes (per spec: 32 bytes).
const int pingPayloadSize = 32;

/// The default ping timeout.
const Duration defaultPingTimeout = Duration(seconds: 10);

/// Result of a ping operation.
class PingResult {
  /// Creates a ping result.
  PingResult({
    required this.peerId,
    required this.rtt,
    required this.success,
    this.error,
  });

  /// The peer that was pinged.
  final String peerId;

  /// The round-trip time (null if failed).
  final Duration? rtt;

  /// Whether the ping succeeded.
  final bool success;

  /// Error message if the ping failed.
  final String? error;

  @override
  String toString() => success
      ? 'PingResult(peerId: $peerId, rtt: ${rtt?.inMilliseconds}ms)'
      : 'PingResult(peerId: $peerId, failed: $error)';
}

/// Handler for the libp2p Ping protocol (/ipfs/ping/1.0.0).
///
/// On the server side, it echoes back 32-byte payloads. On the client side,
/// it sends 32 random bytes and measures the RTT.
class PingHandler {
  /// Creates a ping handler.
  ///
  /// [router] provides the underlying P2P transport.
  PingHandler({required RouterInterface router, Logger? logger})
    : _router = router,
      _logger = logger ?? Logger('PingHandler');

  final RouterInterface _router;
  final Logger _logger;
  final Random _random = Random.secure();
  bool _started = false;

  /// Whether the handler has been started.
  bool get isStarted => _started;

  /// Starts the handler by registering the protocol with the router.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _router.registerProtocolHandler(pingProtocolId, _onPingReceived);
    _logger.info('Ping handler started on $pingProtocolId');
  }

  /// Stops the handler.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _router.removeMessageHandler(pingProtocolId);
    _logger.info('Ping handler stopped');
  }

  /// Handles an incoming ping: echoes the 32-byte payload back.
  void _onPingReceived(NetworkPacket packet) {
    _logger.verbose('Ping received from ${packet.srcPeerId}');

    if (packet.datagram.length != pingPayloadSize) {
      _logger.warning(
        'Invalid ping payload size from ${packet.srcPeerId}: '
        '${packet.datagram.length} (expected $pingPayloadSize)',
      );
      // Echo back what we received even if wrong size, to be lenient.
    }

    // Echo the payload back.
    packet.responder?.call(packet.datagram);

    _logger.verbose('Echoed ping to ${packet.srcPeerId}');
  }

  /// Pings a remote peer and returns the round-trip time.
  ///
  /// Sends 32 random bytes and waits for the echo. Returns a [PingResult]
  /// with the RTT on success, or an error on timeout/failure.
  Future<PingResult> ping(
    String peerId, {
    Duration timeout = defaultPingTimeout,
  }) async {
    if (!_started) {
      _logger.warning('Ping handler not started');
      return PingResult(
        peerId: peerId,
        rtt: null,
        success: false,
        error: 'Ping handler not started',
      );
    }

    // Generate 32 random bytes.
    final payload = Uint8List(pingPayloadSize);
    for (var i = 0; i < pingPayloadSize; i++) {
      payload[i] = _random.nextInt(256);
    }

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _router
          .sendRequest(peerId, pingProtocolId, payload)
          .timeout(timeout);

      stopwatch.stop();

      if (response == null) {
        return PingResult(
          peerId: peerId,
          rtt: null,
          success: false,
          error: 'No response from peer',
        );
      }

      if (response.length != pingPayloadSize) {
        return PingResult(
          peerId: peerId,
          rtt: null,
          success: false,
          error: 'Invalid response size: ${response.length}',
        );
      }

      // Verify the echoed payload matches.
      if (!_bytesEqual(response, payload)) {
        return PingResult(
          peerId: peerId,
          rtt: null,
          success: false,
          error: 'Echoed payload does not match',
        );
      }

      final rtt = stopwatch.elapsed;
      _logger.debug('Ping to $peerId succeeded: ${rtt.inMilliseconds}ms');

      return PingResult(peerId: peerId, rtt: rtt, success: true);
    } on TimeoutException {
      stopwatch.stop();
      _logger.warning('Ping to $peerId timed out after ${timeout.inSeconds}s');
      return PingResult(
        peerId: peerId,
        rtt: null,
        success: false,
        error: 'Ping timed out after ${timeout.inSeconds}s',
      );
    } catch (e) {
      stopwatch.stop();
      _logger.error('Ping to $peerId failed', e);
      return PingResult(
        peerId: peerId,
        rtt: null,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Pings a remote peer repeatedly and returns all results.
  ///
  /// Sends [count] pings with the given [interval] between each.
  Future<List<PingResult>> pingMultiple(
    String peerId, {
    int count = 3,
    Duration interval = const Duration(seconds: 1),
    Duration timeout = defaultPingTimeout,
  }) async {
    final results = <PingResult>[];
    for (var i = 0; i < count; i++) {
      results.add(await ping(peerId, timeout: timeout));
      if (i < count - 1) {
        await Future<void>.delayed(interval);
      }
    }
    return results;
  }

  /// Generates a random 32-byte ping payload (exposed for testing).
  Uint8List generatePayload() {
    final payload = Uint8List(pingPayloadSize);
    for (var i = 0; i < pingPayloadSize; i++) {
      payload[i] = _random.nextInt(256);
    }
    return payload;
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
