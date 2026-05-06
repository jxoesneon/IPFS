import 'dart:async';
import 'package:dart_ipfs/src/protocols/dht/rate_limiter.dart';
import 'package:dart_ipfs/src/proto/generated/config.pb.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimiter', () {
    test('Basic acquisition and release', () async {
      final limiter = RateLimiter(
        maxOperations: 2,
        interval: const Duration(seconds: 1),
      );

      await limiter.acquire();
      await limiter.acquire();

      // Third one should block
      bool thirdAcquired = false;
      unawaited(limiter.acquire().then((_) => thirdAcquired = true));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(thirdAcquired, isFalse);

      limiter.release();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(thirdAcquired, isTrue);
    });

    test('Window reset', () async {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(milliseconds: 200),
      );

      await limiter.acquire();

      // Should block
      bool secondAcquired = false;
      unawaited(limiter.acquire().then((_) => secondAcquired = true));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(secondAcquired, isFalse);

      // Wait for window to reset
      await Future.delayed(const Duration(milliseconds: 150));

      // Try to acquire again - this should trigger window reset in acquire()
      // We don't await this because it will block (maxOperations is 1 and one is active)
      unawaited(limiter.acquire());

      await Future.delayed(const Duration(milliseconds: 50));
      expect(secondAcquired, isTrue);
    });

    test('Multiple releases with queue', () async {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 1),
      );

      await limiter.acquire();

      final completers = List.generate(3, (_) => limiter.acquire());

      await Future.delayed(const Duration(milliseconds: 50));

      limiter.release();
      await Future.delayed(const Duration(milliseconds: 50));
      // One should be released

      limiter.release();
      await Future.delayed(const Duration(milliseconds: 50));
      // Two should be released

      limiter.release();
      await Future.delayed(const Duration(milliseconds: 50));
      // All three should be released (though only 3 were queued)

      await Future.wait(completers);
    });

    test('Release when no operations active', () {
      final limiter = RateLimiter(
        maxOperations: 1,
        interval: const Duration(seconds: 1),
      );

      // Should not throw
      limiter.release();
    });

    test('fromConfig', () {
      final config = RateLimitConfig()
        ..maxRequestsPerWindow = 10
        ..windowSeconds = 60;

      final limiter = RateLimiter.fromConfig(config);
      expect(limiter.maxOperations, 10);
      expect(limiter.interval.inSeconds, 60);
    });

    test('Burst handling (all at once)', () async {
      final limiter = RateLimiter(
        maxOperations: 5,
        interval: const Duration(seconds: 1),
      );

      final futures = List.generate(5, (_) => limiter.acquire());
      await Future.wait(futures); // Should all complete immediately

      bool sixthAcquired = false;
      unawaited(limiter.acquire().then((_) => sixthAcquired = true));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(sixthAcquired, isFalse);
    });
  });
}
