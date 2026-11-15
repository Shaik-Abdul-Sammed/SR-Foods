# ADR 003: Transactional Outbox Pattern for Guaranteed Event Delivery

## Status
Accepted

## Context
When writing business records to SQLite (e.g. creating an order or logging milk collection), syncing with external endpoints or cloud backends can fail due to network disconnection or application crashes. Direct HTTP dispatch during DB transactions risks the dual-write problem.

## Decision
1. Persist integration events in an `outbox_events` table inside the same SQLite atomic transaction as the domain entity update.
2. Provide an `OutboxDispatcher` that polls pending events, transmits them with exponential backoff and retry limits, and updates status to dispatched or dead-letter.

## Consequences
- **Positive**: Guaranteed at-least-once delivery, immunity to intermittent network drops, consistent local-first operations.
- **Negative**: Consuming services must handle duplicate events (requiring idempotency).
