import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/resilience/circuit_breaker.dart';
import 'package:sr_foods/core/resilience/rate_limiter.dart';

void main() {
  group('CircuitBreaker Tests', () {
    test('1. Initial state is closed and runs actions successfully', () async {
      final cb = CircuitBreaker(failureThreshold: 2);
      expect(cb.state, CircuitState.closed);

      final result = await cb.run(() async => 'success');
      expect(result, 'success');
      expect(cb.consecutiveFailures, 0);
    });

    test('2. Consecutive failures trip circuit open at threshold', () async {
      final cb = CircuitBreaker(failureThreshold: 2);

      // 1st failure
      try {
        await cb.run(() async => throw Exception('error 1'));
      } catch (_) {}
      expect(cb.consecutiveFailures, 1);
      expect(cb.state, CircuitState.closed);

      // 2nd failure
      try {
        await cb.run(() async => throw Exception('error 2'));
      } catch (_) {}
      expect(cb.consecutiveFailures, 2);
      expect(cb.state, CircuitState.open);
      expect(cb.lastOpenedAt, isNotNull);
    });

    test('3. Open circuit fails fast with CircuitBreakerOpenException', () async {
      final cb = CircuitBreaker(failureThreshold: 1);
      try {
        await cb.run(() async => throw Exception('fail'));
      } catch (_) {}
      expect(cb.state, CircuitState.open);

      bool executed = false;
      expect(
        () => cb.run(() async {
          executed = true;
          return 'ok';
        }),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
      expect(executed, isFalse);
    });

    test('4. Transitions to half-open after reset timeout and closes on trial success', () async {
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(milliseconds: 50),
      );
      try {
        await cb.run(() async => throw Exception('fail'));
      } catch (_) {}
      expect(cb.state, CircuitState.open);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(cb.state, CircuitState.halfOpen);

      final res = await cb.run(() async => 'recovered');
      expect(res, 'recovered');
      expect(cb.state, CircuitState.closed);
      expect(cb.consecutiveFailures, 0);
    });

    test('5. Trial failure in half-open re-trips open immediately', () async {
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTimeout: const Duration(milliseconds: 50),
      );
      try {
        await cb.run(() async => throw Exception('fail'));
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(cb.state, CircuitState.halfOpen);

      try {
        await cb.run(() async => throw Exception('half-open fail'));
      } catch (_) {}
      expect(cb.state, CircuitState.open);
    });

    test('6. Manual trip and reset work', () {
      final cb = CircuitBreaker();
      cb.trip();
      expect(cb.state, CircuitState.open);

      cb.reset();
      expect(cb.state, CircuitState.closed);
      expect(cb.consecutiveFailures, 0);
    });
  });

  group('TokenBucketRateLimiter Tests', () {
    test('7. Allows requests up to capacity and rejects when exhausted', () {
      final limiter = TokenBucketRateLimiter(
        capacity: 3,
        refillRatePerSecond: 10,
      );

      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isFalse); // Empty
    });

    test('8. Replenishes tokens over time', () async {
      final limiter = TokenBucketRateLimiter(
        capacity: 2,
        refillRatePerSecond: 20, // 1 token every 50ms
      );

      expect(limiter.tryAcquire(2), isTrue);
      expect(limiter.tryAcquire(), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(limiter.tryAcquire(), isTrue);
    });

    test('9. Async acquire waits for token availability', () async {
      final limiter = TokenBucketRateLimiter(
        capacity: 1,
        refillRatePerSecond: 50,
      );

      expect(limiter.tryAcquire(), isTrue);
      final sw = Stopwatch()..start();
      await limiter.acquire(1);
      sw.stop();
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(10));
    });
  });
}
