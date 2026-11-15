import 'dart:async';

enum CircuitState { closed, open, halfOpen }

class CircuitBreakerOpenException implements Exception {
  final String message;
  final Duration remainingTimeout;

  CircuitBreakerOpenException(this.message, this.remainingTimeout);

  @override
  String toString() => 'CircuitBreakerOpenException: $message (retry in ${remainingTimeout.inMilliseconds}ms)';
}

/// Protects services from cascading failures by failing fast when errors exceed threshold.
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration resetTimeout;
  final int halfOpenMaxTrials;

  CircuitState _state = CircuitState.closed;
  int _consecutiveFailures = 0;
  DateTime? _lastOpenedAt;
  int _halfOpenSuccesses = 0;

  CircuitBreaker({
    this.name = 'default',
    this.failureThreshold = 3,
    this.resetTimeout = const Duration(seconds: 5),
    this.halfOpenMaxTrials = 1,
  });

  CircuitState get state {
    _evaluateState();
    return _state;
  }

  int get consecutiveFailures => _consecutiveFailures;
  DateTime? get lastOpenedAt => _lastOpenedAt;

  void _evaluateState() {
    if (_state == CircuitState.open && _lastOpenedAt != null) {
      final elapsed = DateTime.now().difference(_lastOpenedAt!);
      if (elapsed >= resetTimeout) {
        _state = CircuitState.halfOpen;
        _halfOpenSuccesses = 0;
      }
    }
  }

  Future<T> run<T>(Future<T> Function() action) async {
    _evaluateState();

    if (_state == CircuitState.open) {
      final remaining = resetTimeout - DateTime.now().difference(_lastOpenedAt!);
      throw CircuitBreakerOpenException(
        'Circuit breaker $name is OPEN',
        remaining.isNegative ? Duration.zero : remaining,
      );
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    if (_state == CircuitState.halfOpen) {
      _halfOpenSuccesses++;
      if (_halfOpenSuccesses >= halfOpenMaxTrials) {
        _state = CircuitState.closed;
        _consecutiveFailures = 0;
        _lastOpenedAt = null;
      }
    } else {
      _consecutiveFailures = 0;
    }
  }

  void _onFailure() {
    _consecutiveFailures++;
    if (_state == CircuitState.halfOpen || _consecutiveFailures >= failureThreshold) {
      _state = CircuitState.open;
      _lastOpenedAt = DateTime.now();
    }
  }

  void trip() {
    _state = CircuitState.open;
    _lastOpenedAt = DateTime.now();
  }

  void reset() {
    _state = CircuitState.closed;
    _consecutiveFailures = 0;
    _lastOpenedAt = null;
    _halfOpenSuccesses = 0;
  }
}
