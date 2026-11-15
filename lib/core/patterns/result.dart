/// Functional Result monad pattern for explicit error handling without throwing unchecked exceptions
sealed class Result<T, E> {
  const Result();

  /// Creates a successful Result containing [value]
  const factory Result.ok(T value) = Ok<T, E>;

  /// Creates a failed Result containing [error]
  const factory Result.err(E error) = Err<T, E>;

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  T? get okOrNull => switch (this) {
        Ok(value: final v) => v,
        Err() => null,
      };

  E? get errOrNull => switch (this) {
        Ok() => null,
        Err(error: final e) => e,
      };

  /// Unwraps the value or throws a [StateError] if this is an [Err]
  T unwrap() => switch (this) {
        Ok(value: final v) => v,
        Err(error: final e) => throw StateError('Called unwrap on Err: $e'),
      };

  /// Returns the contained value or [defaultValue] if this is an [Err]
  T unwrapOr(T defaultValue) => switch (this) {
        Ok(value: final v) => v,
        Err() => defaultValue,
      };

  /// Transforms the contained value if this is [Ok]
  Result<U, E> map<U>(U Function(T value) fn) => switch (this) {
        Ok(value: final v) => Result.ok(fn(v)),
        Err(error: final e) => Result.err(e),
      };

  /// Transforms the contained error if this is [Err]
  Result<T, F> mapError<F>(F Function(E error) fn) => switch (this) {
        Ok(value: final v) => Result.ok(v),
        Err(error: final e) => Result.err(fn(e)),
      };

  /// Monadic bind: chains another Result-producing function
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) fn) => switch (this) {
        Ok(value: final v) => fn(v),
        Err(error: final e) => Result.err(e),
      };

  /// Pattern matching fold over Ok and Err
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(E error) onErr,
  }) =>
      switch (this) {
        Ok(value: final v) => onOk(v),
        Err(error: final e) => onErr(e),
      };
}

final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);

  @override
  String toString() => 'Result.ok($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T, E> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);

  @override
  String toString() => 'Result.err($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T, E> && other.error == error);

  @override
  int get hashCode => error.hashCode;
}
