import 'dart:async';

import 'package:dart_ipfs/src/protocols/dht/rate_limiter.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimiter queue overflow', () {
    test('queue is bounded by maxQueueSize', () async {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 10),
        maxQueueSize: 5,
      );

      // Consume the single available permit.
      await limiter.acquire();

      // Track completion state of each waiter. We attach listeners immediately
      // so that errors are not treated as unhandled.
      final results = <int, dynamic>{}; // index -> result or error
      final waiters = <Future<void>>[];
      for (var i = 0; i < 5; i++) {
        final f = limiter.acquire();
        waiters.add(f);
        // Attach a listener immediately to capture the result.
        unawaited(
          f
              .then((_) {
                results[i] = 'completed';
              })
              .catchError((e) {
                results[i] = e;
              }),
        );
      }

      await Future.delayed(const Duration(milliseconds: 50));
      expect(limiter.queueLength, equals(5));

      // Enqueue one more — this should evict the oldest waiter (index 0).
      final extra = limiter.acquire();
      bool extraCompleted = false;
      unawaited(extra.then((_) => extraCompleted = true));

      await Future.delayed(const Duration(milliseconds: 50));
      // Queue should still be at maxQueueSize, not maxQueueSize + 1.
      expect(limiter.queueLength, equals(5));

      // The oldest waiter (index 0) should have been completed with an error.
      expect(results[0], isA<RateLimitExceededError>());

      // The extra waiter should still be pending (not completed).
      expect(extraCompleted, isFalse);

      // Remaining original waiters (1..4) should still be pending.
      for (var i = 1; i < 5; i++) {
        expect(
          results.containsKey(i),
          isFalse,
          reason: 'waiters[$i] should still be pending',
        );
      }
    });

    test('oldest entry is dropped first (FIFO eviction)', () async {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 10),
        maxQueueSize: 3,
      );

      await limiter.acquire();

      final results = <int, dynamic>{};
      final waiters = <Future<void>>[];
      for (var i = 0; i < 3; i++) {
        final f = limiter.acquire();
        waiters.add(f);
        unawaited(
          f
              .then((_) {
                results[i] = 'completed';
              })
              .catchError((e) {
                results[i] = e;
              }),
        );
      }
      await Future.delayed(const Duration(milliseconds: 50));
      expect(limiter.queueLength, equals(3));

      // Overflow — evicts waiters[0].
      limiter.acquire();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(results[0], isA<RateLimitExceededError>());

      // Overflow again — evicts waiters[1].
      limiter.acquire();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(results[1], isA<RateLimitExceededError>());

      // waiters[2] should still be pending.
      expect(results.containsKey(2), isFalse);
    });

    test('default maxQueueSize is 1000', () {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 1),
      );
      expect(limiter.maxQueueSize, equals(1000));
    });

    test('evicted waiter error is catchable and descriptive', () async {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 10),
        maxQueueSize: 1,
      );

      await limiter.acquire();

      // Attach listener immediately.
      String? message;
      final first = limiter.acquire();
      unawaited(
        first.catchError((e) {
          message = (e as RateLimitExceededError).message;
        }),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Overflow — evicts first.
      limiter.acquire();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(message, isNotNull);
      expect(message, contains('queue is full'));
    });

    test('queueLength getter reflects current queue size', () async {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 10),
        maxQueueSize: 10,
      );

      expect(limiter.queueLength, equals(0));
      await limiter.acquire();

      // Attach listeners to prevent unhandled errors.
      unawaited(limiter.acquire().catchError((_) {}));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(limiter.queueLength, equals(1));

      unawaited(limiter.acquire().catchError((_) {}));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(limiter.queueLength, equals(2));

      // Releasing should dequeue one.
      limiter.release();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(limiter.queueLength, equals(1));
    });

    test('release still works after overflow eviction', () async {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 10),
        maxQueueSize: 2,
      );

      await limiter.acquire();

      final results = <int, dynamic>{};
      final w1 = limiter.acquire();
      unawaited(
        w1
            .then((_) {
              results[1] = 'completed';
            })
            .catchError((e) {
              results[1] = e;
            }),
      );
      final w2 = limiter.acquire();
      unawaited(
        w2
            .then((_) {
              results[2] = 'completed';
            })
            .catchError((e) {
              results[2] = e;
            }),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Overflow — evicts w1.
      final w3 = limiter.acquire();
      unawaited(
        w3
            .then((_) {
              results[3] = 'completed';
            })
            .catchError((e) {
              results[3] = e;
            }),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(results[1], isA<RateLimitExceededError>());

      // Now release — w2 should complete.
      limiter.release();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(results[2], equals('completed'));

      // w3 should still be pending.
      expect(results.containsKey(3), isFalse);
    });
  });
}
