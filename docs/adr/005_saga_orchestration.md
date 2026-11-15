# ADR 005: Saga Orchestrator for Multi-Step Business Transactions

## Status
Accepted

## Context
Multi-step business workflows—such as placing an order (inventory reservation -> credit check -> logistics dispatch) or scheduling a production batch (raw materials lock -> oven reservation -> packaging allocation)—span multiple subsystems where atomic two-phase commit is impractical.

## Decision
1. Implement a compensating Saga runner orchestrator (`SagaRunner<T>`).
2. Each step specifies forward `execute()` logic and compensating `compensate()` rollback logic.
3. If any step fails, prior steps are rolled back in reverse order, and compensation anomalies are tracked safely.

## Consequences
- **Positive**: Maintains eventual consistency without distributed locking; resilient recovery upon partial failures.
- **Negative**: Compensation logic must be idempotent and carefully tested for edge cases.
