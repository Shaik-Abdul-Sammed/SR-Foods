import 'dart:async';

/// Token-bucket rate limiter for protecting endpoints and worker pools from traffic spikes.
class TokenBucketRateLimiter {
  final double capacity;
  final double refillRatePerSecond;

  double _tokens;
  DateTime _lastRefill;

  TokenBucketRateLimiter({
    required this.capacity,
    required this.refillRatePerSecond,
  })  : _tokens = capacity,
        _lastRefill = DateTime.now();

  double get availableTokens {
    _refill();
    return _tokens;
  }

  void _refill() {
    final now = DateTime.now();
    final elapsedSec = now.difference(_lastRefill).inMicroseconds / 1000000.0;
    _tokens = (_tokens + elapsedSec * refillRatePerSecond).clamp(0.0, capacity);
    _lastRefill = now;
  }

  /// Attempts to acquire [tokens] without blocking. Returns true if acquired.
  bool tryAcquire([double tokens = 1.0]) {
    _refill();
    if (_tokens >= tokens) {
      _tokens -= tokens;
      return true;
    }
    return false;
  }

  /// Blocks asynchronously until [tokens] can be acquired or throws TimeoutException.
  Future<void> acquire([
    double tokens = 1.0,
    Duration timeout = const Duration(seconds: 5),
  ]) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      if (tryAcquire(tokens)) {
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Timed out waiting for $tokens rate limit tokens');
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  /// For testing: manually adjusts token balance.
  void setTokensForTesting(double tokens) {
    _tokens = tokens.clamp(0.0, capacity);
    _lastRefill = DateTime.now();
  }
}
