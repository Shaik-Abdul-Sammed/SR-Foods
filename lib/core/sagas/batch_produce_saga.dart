import '../patterns/result.dart';
import 'saga.dart';

class BatchProduceContext extends SagaContext {
  final String batchCode;
  final String productCode;
  final double targetQuantity;
  bool rawMaterialsLocked = false;
  bool ovenSlotReserved = false;
  bool packagingAllocated = false;

  BatchProduceContext({
    required this.batchCode,
    required this.productCode,
    required this.targetQuantity,
  });
}

class LockRawMaterialsStep extends SagaStep<BatchProduceContext> {
  final bool shouldFail;
  LockRawMaterialsStep({this.shouldFail = false});

  @override
  String get name => 'LockRawMaterialsStep';

  @override
  Future<Result<void, Object>> execute(BatchProduceContext context) async {
    if (shouldFail) {
      return Result.err(Exception('Raw materials (flour/butter/milk) unavailable'));
    }
    context.rawMaterialsLocked = true;
    return const Result.ok(null);
  }

  @override
  Future<Result<void, Object>> compensate(BatchProduceContext context) async {
    context.rawMaterialsLocked = false;
    return const Result.ok(null);
  }
}

class ReserveOvenSlotStep extends SagaStep<BatchProduceContext> {
  final bool shouldFail;
  ReserveOvenSlotStep({this.shouldFail = false});

  @override
  String get name => 'ReserveOvenSlotStep';

  @override
  Future<Result<void, Object>> execute(BatchProduceContext context) async {
    if (shouldFail) {
      return Result.err(Exception('Oven 1 full capacity during requested slot'));
    }
    context.ovenSlotReserved = true;
    return const Result.ok(null);
  }

  @override
  Future<Result<void, Object>> compensate(BatchProduceContext context) async {
    context.ovenSlotReserved = false;
    return const Result.ok(null);
  }
}

class AllocatePackagingStep extends SagaStep<BatchProduceContext> {
  final bool shouldFail;
  AllocatePackagingStep({this.shouldFail = false});

  @override
  String get name => 'AllocatePackagingStep';

  @override
  Future<Result<void, Object>> execute(BatchProduceContext context) async {
    if (shouldFail) {
      return Result.err(Exception('Packaging film / cartons exhausted'));
    }
    context.packagingAllocated = true;
    return const Result.ok(null);
  }

  @override
  Future<Result<void, Object>> compensate(BatchProduceContext context) async {
    context.packagingAllocated = false;
    return const Result.ok(null);
  }
}
