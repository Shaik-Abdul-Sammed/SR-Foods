import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/patterns/result.dart';
import 'package:sr_foods/core/sagas/saga.dart';
import 'package:sr_foods/core/sagas/place_order_saga.dart';
import 'package:sr_foods/core/sagas/batch_produce_saga.dart';

class TestContext extends SagaContext {
  final List<String> trail = [];
}

class TestStep extends SagaStep<TestContext> {
  @override
  final String name;
  final bool failOnExecute;
  final bool failOnCompensate;

  TestStep({
    required this.name,
    this.failOnExecute = false,
    this.failOnCompensate = false,
  });

  @override
  Future<Result<void, Object>> execute(TestContext context) async {
    if (failOnExecute) {
      return Result.err(Exception('$name execute failed'));
    }
    context.trail.add('$name:exec');
    return const Result.ok(null);
  }

  @override
  Future<Result<void, Object>> compensate(TestContext context) async {
    if (failOnCompensate) {
      return Result.err(Exception('$name compensate failed'));
    }
    context.trail.add('$name:comp');
    return const Result.ok(null);
  }
}

void main() {
  group('SagaRunner & Distributed Transactions Tests', () {
    test('1. All steps succeed - completes without compensation', () async {
      final runner = SagaRunner<TestContext>([
        TestStep(name: 'Step1'),
        TestStep(name: 'Step2'),
        TestStep(name: 'Step3'),
      ]);

      final ctx = TestContext();
      final result = await runner.run(ctx);

      expect(result.isSuccess, isTrue);
      expect(result.executedSteps, ['Step1', 'Step2', 'Step3']);
      expect(result.compensatedSteps, isEmpty);
      expect(result.failedStep, isNull);
      expect(ctx.trail, ['Step1:exec', 'Step2:exec', 'Step3:exec']);
    });

    test('2. Step 2 fails - rolls back Step 1', () async {
      final runner = SagaRunner<TestContext>([
        TestStep(name: 'Step1'),
        TestStep(name: 'Step2', failOnExecute: true),
        TestStep(name: 'Step3'),
      ]);

      final ctx = TestContext();
      final result = await runner.run(ctx);

      expect(result.isSuccess, isFalse);
      expect(result.failedStep, 'Step2');
      expect(result.executedSteps, ['Step1']);
      expect(result.compensatedSteps, ['Step1']);
      expect(ctx.trail, ['Step1:exec', 'Step1:comp']);
    });

    test('3. Step 3 fails - rolls back in exact reverse order (Step 2 then Step 1)', () async {
      final runner = SagaRunner<TestContext>([
        TestStep(name: 'Step1'),
        TestStep(name: 'Step2'),
        TestStep(name: 'Step3', failOnExecute: true),
      ]);

      final ctx = TestContext();
      final result = await runner.run(ctx);

      expect(result.isSuccess, isFalse);
      expect(result.failedStep, 'Step3');
      expect(result.executedSteps, ['Step1', 'Step2']);
      expect(result.compensatedSteps, ['Step2', 'Step1']);
      expect(ctx.trail, ['Step1:exec', 'Step2:exec', 'Step2:comp', 'Step1:comp']);
    });

    test('4. Step 1 fails - no steps executed, no compensation run', () async {
      final runner = SagaRunner<TestContext>([
        TestStep(name: 'Step1', failOnExecute: true),
        TestStep(name: 'Step2'),
      ]);

      final ctx = TestContext();
      final result = await runner.run(ctx);

      expect(result.isSuccess, isFalse);
      expect(result.failedStep, 'Step1');
      expect(result.executedSteps, isEmpty);
      expect(result.compensatedSteps, isEmpty);
      expect(ctx.trail, isEmpty);
    });

    test('5. Compensation error is recorded and does not crash remaining rollback', () async {
      final runner = SagaRunner<TestContext>([
        TestStep(name: 'Step1'),
        TestStep(name: 'Step2', failOnCompensate: true),
        TestStep(name: 'Step3', failOnExecute: true),
      ]);

      final ctx = TestContext();
      final result = await runner.run(ctx);

      expect(result.isSuccess, isFalse);
      expect(result.hasCompensationErrors, isTrue);
      expect(result.compensationErrors.length, 1);
      expect(result.compensatedSteps, ['Step2 (partial/failed)', 'Step1']);
      expect(ctx.trail, ['Step1:exec', 'Step2:exec', 'Step1:comp']);
    });

    test('6. PlaceOrderSaga succeeds end-to-end', () async {
      final saga = SagaRunner<OrderPlacementContext>([
        ReserveInventoryStep(),
        AuthorizePaymentStep(),
        DispatchOrderStep(),
      ]);

      final ctx = OrderPlacementContext(
        orderId: 'ORD-101',
        customerId: 'CUST-001',
        amount: 2500.0,
      );

      final result = await saga.run(ctx);
      expect(result.isSuccess, isTrue);
      expect(ctx.inventoryReserved, isTrue);
      expect(ctx.paymentAuthorized, isTrue);
      expect(ctx.notificationDispatched, isTrue);
    });

    test('7. PlaceOrderSaga fails at payment - rolls back inventory', () async {
      final saga = SagaRunner<OrderPlacementContext>([
        ReserveInventoryStep(),
        AuthorizePaymentStep(shouldFail: true),
        DispatchOrderStep(),
      ]);

      final ctx = OrderPlacementContext(
        orderId: 'ORD-102',
        customerId: 'CUST-BAD',
        amount: 9999.0,
      );

      final result = await saga.run(ctx);
      expect(result.isSuccess, isFalse);
      expect(result.failedStep, 'AuthorizePaymentStep');
      expect(ctx.inventoryReserved, isFalse); // Compensated!
      expect(ctx.paymentAuthorized, isFalse);
      expect(ctx.notificationDispatched, isFalse);
    });

    test('8. BatchProduceSaga fails at packaging - rolls back oven and materials', () async {
      final saga = SagaRunner<BatchProduceContext>([
        LockRawMaterialsStep(),
        ReserveOvenSlotStep(),
        AllocatePackagingStep(shouldFail: true),
      ]);

      final ctx = BatchProduceContext(
        batchCode: 'BATCH-2026-X',
        productCode: 'SRF-BAK-001',
        targetQuantity: 500,
      );

      final result = await saga.run(ctx);
      expect(result.isSuccess, isFalse);
      expect(result.failedStep, 'AllocatePackagingStep');
      expect(ctx.rawMaterialsLocked, isFalse); // Rolled back
      expect(ctx.ovenSlotReserved, isFalse); // Rolled back
      expect(ctx.packagingAllocated, isFalse);
      expect(result.compensatedSteps, ['ReserveOvenSlotStep', 'LockRawMaterialsStep']);
    });
  });
}
