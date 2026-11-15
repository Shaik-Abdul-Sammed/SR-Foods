import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/patterns/result.dart';
import 'package:sr_foods/core/usecases/calculate_milk_price_use_case.dart';
import 'package:sr_foods/core/usecases/schedule_bakery_batch_use_case.dart';
import 'package:sr_foods/core/usecases/issue_container_use_case.dart';

void main() {
  group('Result Monad Unit Tests', () {
    test('1. Result.ok holds value, supports isOk, unwrap, unwrapOr, and fold', () {
      const result = Result<int, String>.ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.okOrNull, equals(42));
      expect(result.errOrNull, isNull);
      expect(result.unwrap(), equals(42));
      expect(result.unwrapOr(100), equals(42));

      final folded = result.fold(
        onOk: (v) => 'Success: $v',
        onErr: (e) => 'Failed: $e',
      );
      expect(folded, equals('Success: 42'));
    });

    test('2. Result.err holds error, unwrap throws StateError, unwrapOr returns default, fold executes onErr', () {
      const result = Result<int, String>.err('Network timeout');

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.okOrNull, isNull);
      expect(result.errOrNull, equals('Network timeout'));
      expect(() => result.unwrap(), throwsA(isA<StateError>()));
      expect(result.unwrapOr(99), equals(99));

      final folded = result.fold(
        onOk: (v) => 'Success: $v',
        onErr: (e) => 'Error: $e',
      );
      expect(folded, equals('Error: Network timeout'));
    });

    test('3. map and mapError transform payloads conditionally', () {
      const okResult = Result<int, String>.ok(10);
      final mappedOk = okResult.map((v) => v * 2);
      expect(mappedOk.unwrap(), equals(20));

      const errResult = Result<int, String>.err('invalid');
      final mappedErr = errResult.mapError((e) => e.toUpperCase());
      expect(mappedErr.errOrNull, equals('INVALID'));
    });

    test('4. flatMap chains dependent Result computations and propagates failure early', () {
      Result<double, String> divide(int a, int b) {
        if (b == 0) return const Result.err('division by zero');
        return Result.ok(a / b);
      }

      final successChain = Result<int, String>.ok(10).flatMap((val) => divide(val, 2));
      expect(successChain.unwrap(), equals(5.0));

      final failureChain = Result<int, String>.ok(10).flatMap((val) => divide(val, 0));
      expect(failureChain.isErr, isTrue);
      expect(failureChain.errOrNull, equals('division by zero'));
    });
  });

  group('Migrated UseCase Pattern Integration Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('5. CalculateMilkPriceUseCase returns Result.ok for compliant inputs', () {
      const useCase = CalculateMilkPriceUseCase();
      final result = useCase(
        const MilkPricingParams(
          fatPercent: 4.0,
          snfPercent: 8.5,
          quantityLiters: 100.0,
        ),
      );

      expect(result.isOk, isTrue);
      final money = result.unwrap();
      expect(money.amountMinor, greaterThan(0));
    });

    test('6. CalculateMilkPriceUseCase validates input bounds and returns Result.err', () {
      const useCase = CalculateMilkPriceUseCase();

      // Negative quantity
      final r1 = useCase(
        const MilkPricingParams(
          fatPercent: 4.0,
          snfPercent: 8.5,
          quantityLiters: -10.0,
        ),
      );
      expect(r1.isErr, isTrue);
      expect(r1.errOrNull, isA<ArgumentError>());

      // Excessive fat percent (> 15%)
      final r2 = useCase(
        const MilkPricingParams(
          fatPercent: 25.0,
          snfPercent: 8.5,
          quantityLiters: 100.0,
        ),
      );
      expect(r2.isErr, isTrue);
      expect(r2.errOrNull, isA<ArgumentError>());
    });

    test('7. ScheduleBakeryBatchUseCase returns Result.ok and catches overbooking as Result.err', () async {
      const useCase = ScheduleBakeryBatchUseCase();
      final delivery = DateTime(2026, 11, 20, 10, 0);

      // Successful first booking
      final r1 = await useCase(
        ScheduleBakeryBatchParams(
          db: db,
          productId: 141,
          quantity: 40,
          deliveryDate: delivery,
          ovenId: 'OVEN-UC-01',
          bakingMinutes: 30,
          coolingMinutes: 30,
        ),
      );

      expect(r1.isOk, isTrue);
      expect(r1.unwrap().quantity, equals(40));

      // Overlapping second booking returns Result.err
      final r2 = await useCase(
        ScheduleBakeryBatchParams(
          db: db,
          productId: 142,
          quantity: 30,
          deliveryDate: delivery,
          ovenId: 'OVEN-UC-01',
          bakingMinutes: 30,
          coolingMinutes: 30,
        ),
      );

      expect(r2.isErr, isTrue);

      // Non-positive quantity returns Result.err
      final r3 = await useCase(
        ScheduleBakeryBatchParams(
          db: db,
          productId: 141,
          quantity: 0,
          deliveryDate: delivery,
        ),
      );
      expect(r3.isErr, isTrue);
      expect(r3.errOrNull, isA<ArgumentError>());
    });

    test('8. IssueContainerUseCase validates inputs and returns Result.ok / Result.err', () async {
      const useCase = IssueContainerUseCase();

      final custId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-UC-01',
          shopName: 'Pattern Cafe',
          ownerName: 'Dev Lead',
          phone: '9123456780',
        ),
      );

      // Successful issue
      final r1 = await useCase(
        IssueContainerParams(
          db: db,
          containerCode: 'CR-UC-01',
          customerId: custId,
          depositAmountMinor: 15000,
        ),
      );
      expect(r1.isOk, isTrue);
      expect(r1.unwrap(), isTrue);

      // Empty container code returns Result.err
      final r2 = await useCase(
        IssueContainerParams(
          db: db,
          containerCode: '',
          customerId: custId,
          depositAmountMinor: 15000,
        ),
      );
      expect(r2.isErr, isTrue);
      expect(r2.errOrNull, isA<ArgumentError>());

      // Negative deposit returns Result.err
      final r3 = await useCase(
        IssueContainerParams(
          db: db,
          containerCode: 'CR-UC-02',
          customerId: custId,
          depositAmountMinor: -500,
        ),
      );
      expect(r3.isErr, isTrue);
      expect(r3.errOrNull, isA<ArgumentError>());
    });
  });
}
