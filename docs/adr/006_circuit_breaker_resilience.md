# ADR 006: Circuit Breaker and Token Bucket Rate Limiting for Service Resilience

## Status
Accepted

## Context
When external telemetry services, cloud databases, or third-party mapping APIs degrade or fail, unbound retries cause thread starvation, resource leaks, and cascading UI freezes.

## Decision
1. Implement a finite state machine `CircuitBreaker` (Closed -> Open -> Half-Open) with configurable error thresholds and reset timeouts to fail-fast.
2. Implement a `TokenBucketRateLimiter` to regulate throughput bursts and prevent exhaustion of downstream services and SQLite write locks.

## Consequences
- **Positive**: Rapid failure detection, automatic recovery probing, isolation of failing subsystems.
- **Negative**: Requires fallback user experiences or graceful degradations when the circuit is open.
