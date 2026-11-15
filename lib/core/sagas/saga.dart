import '../patterns/result.dart';

/// Context or payload passed through saga execution steps.
abstract class SagaContext {}

/// A single step in a distributed transaction or multi-stage workflow.
abstract class SagaStep<T extends SagaContext> {
  String get name;

  /// Executes forward step logic. Returns Result.ok or Result.err.
  Future<Result<void, Object>> execute(T context);

  /// Compensates (rolls back) the effects of [execute].
  /// Called in reverse order when a subsequent step in the saga fails.
  Future<Result<void, Object>> compensate(T context);
}

/// The outcome of executing a saga.
class SagaResult<T extends SagaContext> {
  final bool isSuccess;
  final T context;
  final List<String> executedSteps;
  final List<String> compensatedSteps;
  final String? failedStep;
  final Object? failureReason;
  final List<Object> compensationErrors;

  const SagaResult({
    required this.isSuccess,
    required this.context,
    required this.executedSteps,
    required this.compensatedSteps,
    this.failedStep,
    this.failureReason,
    this.compensationErrors = const [],
  });

  bool get hasCompensationErrors => compensationErrors.isNotEmpty;
}

/// Orchestrates sequential execution of saga steps with automatic reverse compensation on failure.
class SagaRunner<T extends SagaContext> {
  final List<SagaStep<T>> steps;

  SagaRunner(this.steps);

  Future<SagaResult<T>> run(T context) async {
    final executed = <SagaStep<T>>[];
    final executedNames = <String>[];
    final compensatedNames = <String>[];
    final compErrors = <Object>[];

    for (final step in steps) {
      Result<void, Object> result;
      try {
        result = await step.execute(context);
      } catch (e) {
        result = Result.err(e);
      }

      if (result.isOk) {
        executed.add(step);
        executedNames.add(step.name);
      } else {
        // Step failed: run backward compensation on all previously executed steps
        final failureReason = result.errOrNull;
        final failedStepName = step.name;

        for (final completedStep in executed.reversed) {
          try {
            final compResult = await completedStep.compensate(context);
            if (compResult.isOk) {
              compensatedNames.add(completedStep.name);
            } else {
              compErrors.add(compResult.errOrNull ?? 'Compensation error in ${completedStep.name}');
              compensatedNames.add('${completedStep.name} (partial/failed)');
            }
          } catch (compEx) {
            compErrors.add(compEx);
            compensatedNames.add('${completedStep.name} (failed)');
          }
        }

        return SagaResult<T>(
          isSuccess: false,
          context: context,
          executedSteps: executedNames,
          compensatedSteps: compensatedNames,
          failedStep: failedStepName,
          failureReason: failureReason,
          compensationErrors: compErrors,
        );
      }
    }

    return SagaResult<T>(
      isSuccess: true,
      context: context,
      executedSteps: executedNames,
      compensatedSteps: const [],
    );
  }
}
