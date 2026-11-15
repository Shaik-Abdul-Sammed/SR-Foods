import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/patterns/idempotent_use_case.dart';
import 'package:sr_foods/core/patterns/result.dart';
import 'package:sr_foods/core/patterns/use_case.dart';

class OrderOutput {
  final int orderId;
  final String status;

  const OrderOutput(this.orderId, this.status);
}

class MockPlaceOrderUseCase implements UseCase<String, OrderOutput> {
  int invocationCount = 0;
  bool shouldFail = false;

  @override
  Future<Result<OrderOutput, Object>> call(String params) async {
    invocationCount++;
    if (shouldFail) {
      return Result.err(Exception('Simulated database write failure'));
    }
    return Result.ok(OrderOutput(invocationCount * 100, 'confirmed'));
  }
}

void main() {
  late AppDatabase db;
  late MockPlaceOrderUseCase innerUseCase;
  late IdempotentUseCase<String, OrderOutput> idempotentUseCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    innerUseCase = MockPlaceOrderUseCase();
    idempotentUseCase = IdempotentUseCase<String, OrderOutput>(
      db: db,
      innerUseCase: innerUseCase,
      serializer: (out) => jsonEncode({'orderId': out.orderId, 'status': out.status}),
      deserializer: (json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return OrderOutput(map['orderId'] as int, map['status'] as String);
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('IdempotentUseCase Pattern Tests', () {
    test('1. First execution executes inner use case and stores key in DB', () async {
      const request = IdempotentRequest<String>(
        idempotencyKey: 'IDEM-KEY-001',
        requestPath: '/orders/place',
        params: 'customer_10',
      );

      final result = await idempotentUseCase(request);

      expect(result.isOk, isTrue);
      expect(result.unwrap().orderId, equals(100));
      expect(innerUseCase.invocationCount, equals(1));

      final row = await (db.select(db.idempotencyKeys)
            ..where((t) => t.key.equals('IDEM-KEY-001')))
          .getSingle();
      expect(row.requestPath, equals('/orders/place'));
      expect(row.responsePayload, contains('"orderId":100'));
    });

    test('2. Duplicate execution returns cached output without re-invoking inner usecase', () async {
      const request = IdempotentRequest<String>(
        idempotencyKey: 'IDEM-KEY-DUP',
        requestPath: '/orders/place',
        params: 'customer_20',
      );

      // Call 1
      final r1 = await idempotentUseCase(request);
      expect(r1.isOk, isTrue);
      expect(r1.unwrap().orderId, equals(100));
      expect(innerUseCase.invocationCount, equals(1));

      // Call 2 (Duplicate)
      final r2 = await idempotentUseCase(request);
      expect(r2.isOk, isTrue);
      expect(r2.unwrap().orderId, equals(100)); // Same cached order ID!
      expect(innerUseCase.invocationCount, equals(1)); // Inner use case was NOT called again!
    });

    test('3. Failed inner use case does not record idempotency key allowing retry', () async {
      innerUseCase.shouldFail = true;

      const request = IdempotentRequest<String>(
        idempotencyKey: 'IDEM-KEY-FAIL',
        requestPath: '/orders/place',
        params: 'customer_30',
      );

      final r1 = await idempotentUseCase(request);
      expect(r1.isErr, isTrue);
      expect(innerUseCase.invocationCount, equals(1));

      // Verify no key was persisted
      final count = await (db.select(db.idempotencyKeys)..where((t) => t.key.equals('IDEM-KEY-FAIL'))).get();
      expect(count.isEmpty, isTrue);

      // Retry after failure succeeds
      innerUseCase.shouldFail = false;
      final r2 = await idempotentUseCase(request);
      expect(r2.isOk, isTrue);
      expect(innerUseCase.invocationCount, equals(2));
    });

    test('4. Distinct idempotency keys execute independently', () async {
      final r1 = await idempotentUseCase(const IdempotentRequest(
        idempotencyKey: 'KEY-A',
        requestPath: '/orders',
        params: 'p1',
      ));
      final r2 = await idempotentUseCase(const IdempotentRequest(
        idempotencyKey: 'KEY-B',
        requestPath: '/orders',
        params: 'p2',
      ));

      expect(r1.unwrap().orderId, equals(100));
      expect(r2.unwrap().orderId, equals(200));
      expect(innerUseCase.invocationCount, equals(2));
    });

    test('5. Expired idempotency keys are bypassed and re-executed', () async {
      // Seed key with negative TTL (already expired)
      final request = IdempotentRequest<String>(
        idempotencyKey: 'KEY-EXPIRED',
        requestPath: '/orders',
        params: 'p3',
        ttl: const Duration(seconds: -10),
      );

      // First call saves key with past expiry
      await idempotentUseCase(request);
      expect(innerUseCase.invocationCount, equals(1));

      // Second call finds key is expired, re-executes inner usecase
      await idempotentUseCase(request);
      expect(innerUseCase.invocationCount, equals(2));
    });

    test('6. purgeExpired cleans up past keys and retains active keys', () async {
      // Key 1: expired
      await idempotentUseCase(const IdempotentRequest(
        idempotencyKey: 'KEY-OLD',
        requestPath: '/orders',
        params: 'p',
        ttl: Duration(seconds: -50),
      ));

      // Key 2: valid for 24h
      await idempotentUseCase(const IdempotentRequest(
        idempotencyKey: 'KEY-ACTIVE',
        requestPath: '/orders',
        params: 'p',
        ttl: Duration(hours: 24),
      ));

      final deleted = await idempotentUseCase.purgeExpired();
      expect(deleted, equals(1));

      final remaining = await db.select(db.idempotencyKeys).get();
      expect(remaining.length, equals(1));
      expect(remaining.first.key, equals('KEY-ACTIVE'));
    });
  });
}
