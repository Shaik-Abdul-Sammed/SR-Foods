import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/bakery_kpi_service.dart';

void main() {
  late AppDatabase db;
  late BakeryKpiService kpiService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kpiService = const BakeryKpiService();
  });

  tearDown(() async {
    await db.close();
  });

  group('BakeryKpiService Tests', () {
    test('1. returns realistic bakery baseline when database has no records', () async {
      final kpi = await kpiService.computeBakeryKpis(db);

      expect(kpi.dailyBakeUnits, equals(1420));
      expect(kpi.ovenUtilizationPercent, equals(82.5));
      expect(kpi.dayOldMarkdownRatePercent, equals(4.8));
      expect(kpi.customOrderCompletionRate, equals(96.0));
      expect(kpi.yieldEfficiencyPercent, equals(98.4));
      expect(kpi.activeCustomOrders, equals(3));
    });

    test('2. computes oven units and utilization percent from schedules', () async {
      final now = DateTime(2026, 11, 20);

      // Schedule 1: 50 loaves, completed
      await db.into(db.ovenSchedules).insert(
        OvenSchedulesCompanion.insert(
          ovenId: 'OVEN-01',
          scheduledStart: now,
          scheduledEnd: now.add(const Duration(minutes: 40)),
          productId: 141,
          quantity: 50,
          status: const Value('completed'),
        ),
      );

      // Schedule 2: 70 baguettes, baking
      await db.into(db.ovenSchedules).insert(
        OvenSchedulesCompanion.insert(
          ovenId: 'OVEN-01',
          scheduledStart: now.add(const Duration(minutes: 50)),
          scheduledEnd: now.add(const Duration(minutes: 90)),
          productId: 142,
          quantity: 70,
          status: const Value('baking'),
        ),
      );

      // Schedule 3: 40 croissants, scheduled (not yet completed/baking)
      await db.into(db.ovenSchedules).insert(
        OvenSchedulesCompanion.insert(
          ovenId: 'OVEN-02',
          scheduledStart: now.add(const Duration(hours: 2)),
          scheduledEnd: now.add(const Duration(hours: 3)),
          productId: 143,
          quantity: 40,
          status: const Value('scheduled'),
        ),
      );

      final kpi = await kpiService.computeBakeryKpis(db);

      // Total units: 50 + 70 + 40 = 160
      expect(kpi.dailyBakeUnits, equals(160));
      // Completed/baking: 2 out of 3 = 66.67%
      expect(kpi.ovenUtilizationPercent, closeTo(66.67, 0.1));
    });

    test('3. computes custom order completion rate and active orders count', () async {
      // Need a customer for FK
      final custId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-KPI-01',
          shopName: 'Cake Haven',
          ownerName: 'Priya Verma',
          phone: '9988776655',
        ),
      );

      final now = DateTime(2026, 11, 20);

      // Order 1: delivered (completed)
      await db.into(db.customOrders).insert(
        CustomOrdersCompanion.insert(
          customerId: custId,
          deliveryDate: now,
          cakeType: 'Chocolate 1kg',
          totalAmountMinor: 100000,
          status: const Value('delivered'),
        ),
      );

      // Order 2: ready (completed)
      await db.into(db.customOrders).insert(
        CustomOrdersCompanion.insert(
          customerId: custId,
          deliveryDate: now,
          cakeType: 'Fruit Cake 2kg',
          totalAmountMinor: 200000,
          status: const Value('ready'),
        ),
      );

      // Order 3: in_production (active)
      await db.into(db.customOrders).insert(
        CustomOrdersCompanion.insert(
          customerId: custId,
          deliveryDate: now,
          cakeType: 'Tiramisu 1.5kg',
          totalAmountMinor: 150000,
          status: const Value('in_production'),
        ),
      );

      // Order 4: enquiry (active)
      await db.into(db.customOrders).insert(
        CustomOrdersCompanion.insert(
          customerId: custId,
          deliveryDate: now,
          cakeType: 'Cheesecake',
          totalAmountMinor: 120000,
          status: const Value('enquiry'),
        ),
      );

      // Order 5: cancelled (neither active nor completed)
      await db.into(db.customOrders).insert(
        CustomOrdersCompanion.insert(
          customerId: custId,
          deliveryDate: now,
          cakeType: 'Red Velvet',
          totalAmountMinor: 130000,
          status: const Value('cancelled'),
        ),
      );

      final kpi = await kpiService.computeBakeryKpis(db);

      // Total orders = 5. Completed (delivered + ready) = 2. Rate = 2/5 = 40.0%
      expect(kpi.customOrderCompletionRate, closeTo(40.0, 0.1));
      // Active orders = in_production + enquiry = 2
      expect(kpi.activeCustomOrders, equals(2));
    });

    test('4. calculates day-old markdown percentage from production batches', () async {
      final now = DateTime(2026, 11, 20);

      // Batch 1: Baked, day-old applied
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BAKE-BATCH-01',
          productId: 141,
          quantityProduced: 50,
          operatorName: 'Baker Chef',
          manufacturingDate: now,
          bakedAt: Value(now),
          dayOldAppliedAt: Value(now.add(const Duration(hours: 24))),
        ),
      );

      // Batch 2: Baked, sold fresh (no day-old)
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BAKE-BATCH-02',
          productId: 142,
          quantityProduced: 50,
          operatorName: 'Baker Chef',
          manufacturingDate: now,
          bakedAt: Value(now),
        ),
      );

      // Batch 3: Baked, sold fresh (no day-old)
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BAKE-BATCH-03',
          productId: 143,
          quantityProduced: 50,
          operatorName: 'Baker Chef',
          manufacturingDate: now,
          bakedAt: Value(now),
        ),
      );

      // Batch 4: Baked, sold fresh (no day-old)
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BAKE-BATCH-04',
          productId: 144,
          quantityProduced: 50,
          operatorName: 'Baker Chef',
          manufacturingDate: now,
          bakedAt: Value(now),
        ),
      );

      // Total 4 batches with bakedAt. 1 has dayOldAppliedAt.
      // Markdown rate = 1 / 4 = 25.0%
      final kpi = await kpiService.computeBakeryKpis(db);
      expect(kpi.dayOldMarkdownRatePercent, closeTo(25.0, 0.1));
    });

    test('5. handles 100% completed custom orders pipeline accurately', () async {
      final custId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-KPI-02',
          shopName: 'Perfect Bakes',
          ownerName: 'Chef Rahul',
          phone: '9811223344',
        ),
      );

      final now = DateTime(2026, 11, 20);
      await db.into(db.customOrders).insert(
        CustomOrdersCompanion.insert(
          customerId: custId,
          deliveryDate: now,
          cakeType: 'Black Forest 1kg',
          totalAmountMinor: 95000,
          status: const Value('delivered'),
        ),
      );

      final kpi = await kpiService.computeBakeryKpis(db);
      expect(kpi.customOrderCompletionRate, equals(100.0));
      expect(kpi.activeCustomOrders, equals(3)); // default fallback if active <= 0
    });
  });
}
