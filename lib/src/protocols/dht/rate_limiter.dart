import 'dart:async';
import 'package:dart_ipfs/src/proto/generated/config.pb.dart';

/// Exception thrown when a rate-limited operation is evicted because the
/// wait queue is full.
class RateLimitExceededError implements Exception {
  /// Creates a rate limit exceeded error with a descriptive [message].
  RateLimitExceededError([this.message = 'Rate limit queue is full']);

  /// Description of why the operation was dropped.
  final String message;

  @override
  String toString() => 'RateLimitExceededError: $message';
}

/// Token bucket rate limiter for controlling request throughput.
///
/// Limits operations to [maxOperations] per [interval]. Queues
/// excess requests and processes them when capacity is available.
class RateLimiter {
  /// Creates a rate limiter with given limits.
  RateLimiter({
    required this.maxOperations,
    required this.interval,
    this.maxQueueSize = 1000,
  });

  /// Maximum operations allowed per time window.
  final int maxOperations;

  /// Duration of the time window.
  final Duration interval;

  /// Maximum number of waiters allowed in the queue before FIFO eviction.
  final int maxQueueSize;

  int _currentOperations = 0;
  DateTime _windowStart = DateTime.now();
  final _queue = <Completer<void>>[];

  /// Returns the current number of queued waiters.
  int get queueLength => _queue.length;

  /// Acquires a permit, blocking if the rate limit is exceeded.
  ///
  /// This method returns a [Future] that completes when a permit is available.
  /// If the queue is already full, the oldest waiter is evicted with a
  /// [RateLimitExceededError] and the new waiter is enqueued.
  Future<void> acquire() async {
    if (maxOperations <= 0) {
      throw RateLimitExceededError('rate limit is disabled (maxOperations <= 0)');
    }

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

    // If no queue space is available, reject immediately.
    if (maxQueueSize <= 0) {
      throw RateLimitExceededError('rate limit queue size is zero');
    }

    // Evict the oldest waiter if the queue is at capacity.
    if (_queue.length >= maxQueueSize) {
      _queue.removeAt(0).completeError(
        RateLimitExceededError('queue is full; oldest waiter evicted'),
      );
    }

    // Queue the operation
    final completer = Completer<void>();
    _queue.add(completer);
    return completer.future;
  }

  /// Releases a permit, allowing queued operations to proceed.
  ///
  /// If there are queued operations, the next one in line will be completed.
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

  /// Creates a [RateLimiter] from a [RateLimitConfig].
  ///
  /// Honors [RateLimitConfig.maxQueueSize] when present; otherwise the default
  /// queue size is used.
  static RateLimiter fromConfig(RateLimitConfig config) {
    return RateLimiter(
      maxOperations: config.maxRequestsPerWindow,
      interval: Duration(seconds: config.windowSeconds),
      maxQueueSize: config.hasMaxQueueSize() ? config.maxQueueSize : 1000,
    );
  }
}
