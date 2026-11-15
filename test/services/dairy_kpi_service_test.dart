import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/dairy_kpi_service.dart';

void main() {
  late AppDatabase db;
  late DairyKpiService kpiService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kpiService = const DairyKpiService();
  });

  tearDown(() async {
    await db.close();
  });

  group('DairyKpiService Tests', () {
    test('1. returns realistic industry baseline when database has no records', () async {
      final kpi = await kpiService.computeDairyKpis(db);

      expect(kpi.totalMilkIntakeLiters, equals(2450.0));
      expect(kpi.weightedAvgFat, equals(4.2));
      expect(kpi.weightedAvgSnf, equals(8.6));
      expect(kpi.chillingBreachAlerts, equals(0));
      expect(kpi.containerReturnRate, equals(94.2));
      expect(kpi.totalProcurementSpendInr, equals(85400.0));
    });

    test('2. calculates total volume and spend from procurement entries', () async {
      // Entry 1: 100L @ ₹40.00 = ₹4,000.00 (400,000 minor)
      await db.into(db.milkProcurements).insert(
        MilkProcurementsCompanion.insert(
          supplierId: 'SUP-01',
          quantityLiters: 100.0,
          fatPercent: 4.0,
          snfPercent: 8.5,
          ratePerLiterMinor: 4000,
          totalAmountMinor: 400000,
        ),
      );

      // Entry 2: 200L @ ₹50.00 = ₹10,000.00 (1,000,000 minor)
      await db.into(db.milkProcurements).insert(
        MilkProcurementsCompanion.insert(
          supplierId: 'SUP-02',
          quantityLiters: 200.0,
          fatPercent: 5.0,
          snfPercent: 9.0,
          ratePerLiterMinor: 5000,
          totalAmountMinor: 1000000,
        ),
      );

      final kpi = await kpiService.computeDairyKpis(db);

      expect(kpi.totalMilkIntakeLiters, equals(300.0));
      expect(kpi.totalProcurementSpendInr, equals(14000.0)); // 4000 + 10000
      expect(kpi.totalCollectionsCount, equals(2));
    });

    test('3. computes weighted average fat and SNF percentages', () async {
      // 100L with 4.0% fat, 8.0% snf -> 400 fat units, 800 snf units
      await db.into(db.milkProcurements).insert(
        MilkProcurementsCompanion.insert(
          supplierId: 'SUP-A',
          quantityLiters: 100.0,
          fatPercent: 4.0,
          snfPercent: 8.0,
          ratePerLiterMinor: 4000,
          totalAmountMinor: 400000,
        ),
      );

      // 300L with 6.0% fat, 9.0% snf -> 1800 fat units, 2700 snf units
      await db.into(db.milkProcurements).insert(
        MilkProcurementsCompanion.insert(
          supplierId: 'SUP-B',
          quantityLiters: 300.0,
          fatPercent: 6.0,
          snfPercent: 9.0,
          ratePerLiterMinor: 6000,
          totalAmountMinor: 1800000,
        ),
      );

      // Total = 400L.
      // Weighted fat = (400 + 1800) / 400 = 2200 / 400 = 5.5%
      // Weighted snf = (800 + 2700) / 400 = 3500 / 400 = 8.75%
      final kpi = await kpiService.computeDairyKpis(db);

      expect(kpi.weightedAvgFat, closeTo(5.5, 0.001));
      expect(kpi.weightedAvgSnf, closeTo(8.75, 0.001));
    });

    test('4. counts chilling breach alerts when temperature exceeds 4.5°C threshold', () async {
      // Normal batch (3.8°C <= 4.5°C)
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BATCH-COLD-01',
          productId: 101,
          quantityProduced: 500,
          operatorName: 'Chilling Operator 1',
          manufacturingDate: DateTime(2026, 11, 20),
          chillingCenterId: const Value('CHILL-01'),
          pasteurizationTempC: const Value(3.8),
        ),
      );

      // Breached batch 1 (5.2°C > 4.5°C)
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BATCH-WARM-02',
          productId: 101,
          quantityProduced: 500,
          operatorName: 'Chilling Operator 2',
          manufacturingDate: DateTime(2026, 11, 20),
          chillingCenterId: const Value('CHILL-01'),
          pasteurizationTempC: const Value(5.2),
        ),
      );

      // Breached batch 2 (6.0°C > 4.5°C)
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BATCH-WARM-03',
          productId: 101,
          quantityProduced: 500,
          operatorName: 'Chilling Operator 3',
          manufacturingDate: DateTime(2026, 11, 20),
          chillingCenterId: const Value('CHILL-02'),
          pasteurizationTempC: const Value(6.0),
        ),
      );

      final kpi = await kpiService.computeDairyKpis(db);
      expect(kpi.chillingBreachAlerts, equals(2));
    });

    test('5. computes container return rate accurately', () async {
      // 3 returned containers
      for (int i = 1; i <= 3; i++) {
        await db.into(db.returnableContainers).insert(
          ReturnableContainersCompanion.insert(
            containerType: 'crate',
            containerCode: 'CR-RET-0$i',
            status: const Value('returned'),
          ),
        );
      }

      // 1 in_warehouse container
      await db.into(db.returnableContainers).insert(
        ReturnableContainersCompanion.insert(
          containerType: 'crate',
          containerCode: 'CR-WH-01',
          status: const Value('in_warehouse'),
        ),
      );

      // 1 with_customer container
      await db.into(db.returnableContainers).insert(
        ReturnableContainersCompanion.insert(
          containerType: 'crate',
          containerCode: 'CR-CUST-01',
          status: const Value('with_customer'),
        ),
      );

      // Total = 5 containers, 4 returned/in_warehouse -> 4/5 = 80.0%
      final kpi = await kpiService.computeDairyKpis(db);
      expect(kpi.containerReturnRate, closeTo(80.0, 0.01));
    });
  });
}
