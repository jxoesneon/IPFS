// Auto-generated proto coverage tests. Do not hand-edit.

import 'package:test/test.dart';
import 'package:dart_ipfs/src/proto/generated/config.pb.dart';

void main() {
  group('ProtocolConfig', () {
    test('round-trips and accessors work', () {
      final original = ProtocolConfig(
        protocolId: 'a',
        messageTimeoutSeconds: 1,
        maxRetries: 1,
        maxMessageSize: 1,
        rateLimit: RateLimitConfig.create(),
        circuitBreaker: CircuitBreakerConfig.create(),
      );
      expect(original.protocolId, 'a');
      expect(original.messageTimeoutSeconds, 1);
      expect(original.maxRetries, 1);
      expect(original.maxMessageSize, 1);
      expect(original.rateLimit, isNotNull);
      expect(original.circuitBreaker, isNotNull);
      original.hasProtocolId();
      original.clearProtocolId();
      original.hasMessageTimeoutSeconds();
      original.clearMessageTimeoutSeconds();
      original.hasMaxRetries();
      original.clearMaxRetries();
      original.hasMaxMessageSize();
      original.clearMaxMessageSize();
      original.hasRateLimit();
      original.clearRateLimit();
      original.hasCircuitBreaker();
      original.clearCircuitBreaker();
      original.ensureRateLimit();
      original.ensureCircuitBreaker();
      expect(ProtocolConfig.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = ProtocolConfig.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(ProtocolConfig.fromJson(json), isNotNull);
    });
  });

  group('RateLimitConfig', () {
    test('round-trips and accessors work', () {
      final original = RateLimitConfig(
        maxRequestsPerWindow: 1,
        windowSeconds: 1,
        maxQueueSize: 1,
      );
      expect(original.maxRequestsPerWindow, 1);
      expect(original.windowSeconds, 1);
      expect(original.maxQueueSize, 1);
      original.hasMaxRequestsPerWindow();
      original.clearMaxRequestsPerWindow();
      original.hasWindowSeconds();
      original.clearWindowSeconds();
      original.hasMaxQueueSize();
      original.clearMaxQueueSize();
      expect(RateLimitConfig.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = RateLimitConfig.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(RateLimitConfig.fromJson(json), isNotNull);
    });
  });

  group('CircuitBreakerConfig', () {
    test('round-trips and accessors work', () {
      final original = CircuitBreakerConfig(
        resetTimeoutSeconds: 1,
        failureThreshold: 1,
        halfOpenTimeoutSeconds: 1,
      );
      expect(original.resetTimeoutSeconds, 1);
      expect(original.failureThreshold, 1);
      expect(original.halfOpenTimeoutSeconds, 1);
      original.hasResetTimeoutSeconds();
      original.clearResetTimeoutSeconds();
      original.hasFailureThreshold();
      original.clearFailureThreshold();
      original.hasHalfOpenTimeoutSeconds();
      original.clearHalfOpenTimeoutSeconds();
      expect(CircuitBreakerConfig.getDefault(), isNotNull);
      expect(original.createEmptyInstance(), isNotNull);
      final buffer = original.writeToBuffer();
      final restored = CircuitBreakerConfig.fromBuffer(buffer);
      expect(restored, isNotNull);
      expect(original.clone(), isNotNull);
      original.copyWith((m) {});
      expect(original.toString(), isA<String>());
      final json = original.writeToJson();
      expect(CircuitBreakerConfig.fromJson(json), isNotNull);
    });
  });
}
