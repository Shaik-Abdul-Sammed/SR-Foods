import 'result.dart';

/// Abstract contract for clean architecture UseCases encapsulated with explicit inputs and outputs
abstract interface class UseCase<In, Out> {
  Future<Result<Out, Object>> call(In params);
}

/// Abstract contract for synchronous UseCases
abstract interface class SyncUseCase<In, Out> {
  Result<Out, Object> call(In params);
}

/// No-parameter sentinel type for UseCases that require no arguments
final class NoParams {
  const NoParams();
}
