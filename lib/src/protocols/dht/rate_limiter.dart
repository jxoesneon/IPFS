import 'dart:async';
import 'package:dart_ipfs/src/proto/generated/config.pb.dart';

/// Token bucket rate limiter for controlling request throughput.
///
/// Limits operations to [maxOperations] per [interval]. Queues
/// excess requests and processes them when capacity is available.
class RateLimiter {

  /// Creates a rate limiter with given limits.
  RateLimiter({required this.maxOperations, required this.interval});
  /// Maximum operations allowed per time window.
  final int maxOperations;

  /// Duration of the time window.
  final Duration interval;

  int _currentOperations = 0;
  DateTime _windowStart = DateTime.now();
  final _queue = <Completer<void>>[];

  Future<void> acquire() async {
    final now = DateTime.now();
    if (now.difference(_windowStart) >= interval) {
      // Reset window
      _windowStart = now;
      _currentOperations = 0;
      // Process queued operations
      while (_queue.isNotEmpty && _currentOperations < maxOperations) {
        _currentOperations++;
        _queue.removeAt(0).complete();
      }
    }

    if (_currentOperations < maxOperations) {
      _currentOperations++;
      return;
    }

    // Queue the operation
    final completer = Completer<void>();
    _queue.add(completer);
    return completer.future;
  }

  void release() {
    if (_currentOperations > 0) {
      _currentOperations--;
    }

    // Process next queued operation if any
    if (_queue.isNotEmpty && _currentOperations < maxOperations) {
      _currentOperations++;
      _queue.removeAt(0).complete();
    }
  }

  static RateLimiter fromConfig(RateLimitConfig config) {
    return RateLimiter(
      maxOperations: config.maxRequestsPerWindow,
      interval: Duration(seconds: config.windowSeconds),
    );
  }
}
