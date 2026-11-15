# ADR 001: Adoption of Result<T, E> Monad and UseCase Pattern

## Status
Accepted

## Context
Exceptions in Dart are untyped and uncaught at compile time. In a production enterprise system managing food logistics, inventory, and financial balances, unhandled exceptions can crash the app or corrupt local state. Furthermore, business logic was previously scattered inside Flutter UI controllers and services with mixed side-effects.

## Decision
1. Introduce `Result<T, E>` monad encapsulating either `Success<T>` or `Failure<E>`.
2. Encapsulate business logic within reusable, testable `UseCase<Input, Output>` classes.
3. Errors must be returned as typed failures rather than thrown exceptions across domain boundaries.

## Consequences
- **Positive**: Compile-time enforcement of error handling, predictable control flow, decoupling of domain operations from UI controllers.
- **Negative**: Requires explicit pattern matching or fold/when calls rather than relying on global try/catch.
