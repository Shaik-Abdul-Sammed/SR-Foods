# ADR 002: In-Process Domain Events and Synchronous EventBus

## Status
Accepted

## Context
When business actions happen (such as milk procurement, order placement, or cold chain temperature breaches), multiple disparate services need to react (e.g., inventory deduction, invoice generation, alert notifications, analytics). Direct synchronous coupling between all services creates spaghetti dependencies and circular imports.

## Decision
1. Introduce strongly-typed `DomainEvent` classes with event timestamps and contextual payloads.
2. Implement a synchronous in-memory `EventBus` supporting subscriptions, filtering, and broadcast publish.
3. Decouple domain side-effects into separate event handlers listening to the bus.

## Consequences
- **Positive**: Clean separation of concerns, high modularity, extensible event listeners without modifying publisher code.
- **Negative**: Traceability requires structured logging/tracing to correlate event cascades.
