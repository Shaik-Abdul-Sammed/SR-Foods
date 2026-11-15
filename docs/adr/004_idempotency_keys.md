# ADR 004: Idempotency Keys Pattern for Exactly-Once Execution

## Status
Accepted

## Context
Mobile devices frequently experience intermittent connectivity drops causing retried HTTP requests, repeated form submissions, or duplicated offline sync batches. Without deduplication, duplicate invoices, double payment deductions, or duplicate inventory bookings can occur.

## Decision
1. Introduce `idempotency_keys` table tracking client-generated request tokens, execution status, cached payload responses, and expiration TTLs.
2. Provide `IdempotentUseCase` wrapper decorator that intercepts duplicate invocations, serves cached responses, and avoids duplicate state changes.

## Consequences
- **Positive**: Complete defense against duplicate transactions across offline sync and user retries.
- **Negative**: Storage overhead for expired keys requiring periodic purging.
