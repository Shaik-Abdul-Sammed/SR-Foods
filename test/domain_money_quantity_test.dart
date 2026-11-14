import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/domain/quantity.dart';

void main() {
  group('Money Value Object Tests', () {
    test('Exact integer paise arithmetic prevents floating point error', () {
      final a = Money.fromRupees(0.1);
      final b = Money.fromRupees(0.2);
      final sum = a + b;

      expect(sum.paise, 30);
      expect(sum.inRupees, 0.30);
      expect(sum.format(includeSymbol: false), '0.30');
    });

    test('Money operators +, -, *, / behave correctly', () {
      final m1 = Money.fromRupees(150.0);
      final m2 = Money.fromRupees(50.0);

      expect((m1 + m2).inRupees, 200.0);
      expect((m1 - m2).inRupees, 100.0);
      expect((m1 * 3).inRupees, 450.0);
      expect((m1 / 2).inRupees, 75.0);
      expect(m1 > m2, isTrue);
      expect(m2 < m1, isTrue);
      expect(Money.zero.isZero, isTrue);
    });

    test('Indian currency formatting works as expected', () {
      final money = Money.fromRupees(125000.50);
      expect(money.format().contains('1,25,000.50'), isTrue);
    });
  });

  group('Quantity Value Object Tests', () {
    test('Quantity conversions within category work accurately', () {
      const qKg = Quantity(1.5, ProductUnit.kg);
      final qGrams = qKg.convertTo(ProductUnit.g);

      expect(qGrams.amount, 1500.0);
      expect(qGrams.unit, ProductUnit.g);

      const qLiters = Quantity(2.0, ProductUnit.liter);
      final qMl = qLiters.convertTo(ProductUnit.ml);
      expect(qMl.amount, 2000.0);
    });

    test('Quantity addition with unit normalization', () {
      const q1 = Quantity(500, ProductUnit.g);
      const q2 = Quantity(1.0, ProductUnit.kg);
      final sum = q1 + q2;

      expect(sum.amount, 1500.0);
      expect(sum.unit, ProductUnit.g);
    });

    test('Incompatible unit addition throws ArgumentError', () {
      const mass = Quantity(1.0, ProductUnit.kg);
      const volume = Quantity(1.0, ProductUnit.liter);

      expect(() => mass + volume, throwsArgumentError);
    });
  });

  group('ActivityLogs & SyncQueue Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Activity log append and fetch last entries works correctly', () async {
      await db.logActivity(
        action: 'ORDER_PLACED',
        entityType: 'order',
        entityId: 101,
        details: 'Order of ₹2,500 placed for Shop A',
        userId: 'owner',
      );

      final logs = await db.getRecentActivityLogs(limit: 10);
      expect(logs.length, 1);
      expect(logs.first.action, 'ORDER_PLACED');
      expect(logs.first.details?.contains('Shop A'), isTrue);
    });

    test('SyncQueue enqueues resilient offline mutation payloads', () async {
      final id = await db.enqueueSync(
        action: 'insert',
        entityType: 'order',
        payload: '{"orderNumber": "ORD-001", "total": 2000}',
      );

      expect(id, greaterThan(0));

      final queued = await db.select(db.syncQueue).get();
      expect(queued.length, 1);
      expect(queued.first.status, 'pending');
      expect(queued.first.payload.contains('ORD-001'), isTrue);
    });
  });
}
