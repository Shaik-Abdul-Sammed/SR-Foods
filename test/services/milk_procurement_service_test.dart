import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/dairy_pricing_service.dart';
import 'package:sr_foods/core/services/milk_procurement_service.dart';

void main() {
  group('MilkProcurementService Unit & DB Tests', () {
    const service = MilkProcurementService();
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('1. slotCutoffCheck returns OPEN for Morning slot (08:30 AM)', () {
      final morningTime = DateTime(2026, 11, 15, 8, 30);
      final status = service.slotCutoffCheck(morningTime);
      expect(status.isIntakeAllowed, isTrue);
      expect(status.activeSlot, equals('morning'));
    });

    test('2. slotCutoffCheck returns CLOSED for Midday gap (02:15 PM)', () {
      final middayTime = DateTime(2026, 11, 15, 14, 15);
      final status = service.slotCutoffCheck(middayTime);
      expect(status.isIntakeAllowed, isFalse);
      expect(status.activeSlot, equals('none'));
      expect(status.message, contains('Morning intake closed'));
    });

    test('3. slotCutoffCheck returns OPEN for Evening slot (06:00 PM)', () {
      final eveningTime = DateTime(2026, 11, 15, 18, 0);
      final status = service.slotCutoffCheck(eveningTime);
      expect(status.isIntakeAllowed, isTrue);
      expect(status.activeSlot, equals('evening'));
    });

    test('4. slotCutoffCheck returns CLOSED for Night gap (11:30 PM)', () {
      final nightTime = DateTime(2026, 11, 15, 23, 30);
      final status = service.slotCutoffCheck(nightTime);
      expect(status.isIntakeAllowed, isFalse);
      expect(status.activeSlot, equals('none'));
      expect(status.message, contains('Chilling center locked'));
    });

    test('5. recordProcurement writes valid row and calculates rate & total accurately', () async {
      final result = await service.recordProcurement(
        db: db,
        supplierId: 'SUPPLIER-MEDAK-12',
        quantityLiters: 150.0,
        fatPercent: 4.0,
        snfPercent: 8.5,
        slot: 'morning',
        chillingCenterId: 'CHILL-UNIT-01',
      );

      expect(result.procurementId, greaterThan(0));
      expect(result.supplierId, equals('SUPPLIER-MEDAK-12'));
      expect(result.quantityLiters, equals(150.0));
      // Cow rule: base ₹38.00 + 5 steps of 0.30 = ₹39.50/L
      expect(result.ratePerLiter.amountMinor, equals(3950));
      // 150 * 39.50 = 5925.00 = 592,500 paise
      expect(result.totalAmount.amountMinor, equals(592500));

      // Verify row persisted in database
      final rows = await db.customSelect('SELECT * FROM milk_procurements WHERE id = ?', variables: [
        Variable.withInt(result.procurementId),
      ]).get();
      expect(rows.length, equals(1));
      expect(rows.first.read<String>('supplier_id'), equals('SUPPLIER-MEDAK-12'));
      expect(rows.first.read<double>('quantity_liters'), equals(150.0));
    });

    test('6. recordProcurement automatically applies Buffalo rule when fat >= 5.0%', () async {
      final result = await service.recordProcurement(
        db: db,
        supplierId: 'FARMER-BUFFALO-01',
        quantityLiters: 100.0,
        fatPercent: 6.5,
        snfPercent: 9.0,
        slot: 'evening',
      );

      // Buffalo rule: base 58.00 + 5 steps of 0.40 = ₹60.00/L
      expect(result.ratePerLiter.amountMinor, equals(6000));
      expect(result.totalAmount.amountMinor, equals(600000));
    });

    test('7. autoDeductOnProduction allocates unassigned milk intakes to production batch', () async {
      // 1. Record 2 procurements
      await service.recordProcurement(
        db: db,
        supplierId: 'F1',
        quantityLiters: 50.0,
        fatPercent: 4.0,
        snfPercent: 8.5,
        slot: 'morning',
      );
      await service.recordProcurement(
        db: db,
        supplierId: 'F2',
        quantityLiters: 80.0,
        fatPercent: 4.2,
        snfPercent: 8.6,
        slot: 'morning',
      );

      // Create a valid parent production batch
      final batchId = await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BAT-DAI-TEST-01',
          productId: 1,
          operatorName: 'Operator Dairy',
          quantityProduced: 100,
          manufacturingDate: DateTime.now(),
        ),
      );

      // 2. Allocate 100 Liters to the production batch
      final linked = await service.autoDeductOnProduction(
        db: db,
        batchId: batchId,
        requiredLiters: 100.0,
      );

      // Both 50L and 80L should be linked to fulfill 100L
      expect(linked, equals(2));

      // 3. Verify batch_id was updated in DB
      final linkedRows = await db.customSelect(
        'SELECT id FROM milk_procurements WHERE batch_id = ?',
        variables: [Variable.withInt(batchId)],
      ).get();
      expect(linkedRows.length, equals(2));
    });
  });
}
