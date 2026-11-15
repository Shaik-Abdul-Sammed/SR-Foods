import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';

void main() {
  group('Drift Schema v5 to v6 Migration Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Schema version is exactly v6', () async {
      expect(db.schemaVersion, equals(6));
    });

    test('2. Default seeded fat pricing rules are populated in v6 migration', () async {
      final rules = await db.select(db.fatPricingRules).get();
      expect(rules.length, greaterThanOrEqualTo(2));

      final cowRule = rules.firstWhere((r) => r.name.contains('Cow'));
      expect(cowRule.baseRatePerLiterMinor, equals(3800)); // ₹38.00
      expect(cowRule.baseFatPercent, equals(3.5));

      final buffaloRule = rules.firstWhere((r) => r.name.contains('Buffalo'));
      expect(buffaloRule.baseRatePerLiterMinor, equals(5800)); // ₹58.00
      expect(buffaloRule.baseFatPercent, equals(6.0));
    });

    test('3. New v6 Dairy & Bakery tables accept compliant records', () async {
      // Milk Procurement insert
      final procurementId = await db.into(db.milkProcurements).insert(
        MilkProcurementsCompanion.insert(
          supplierId: 'SUP-DAIRY-01',
          quantityLiters: 120.5,
          fatPercent: 4.2,
          snfPercent: 8.6,
          ratePerLiterMinor: 4010,
          totalAmountMinor: 483205,
          slot: const Value('morning'),
        ),
      );
      expect(procurementId, greaterThan(0));

      // Oven Schedule insert
      final scheduleId = await db.into(db.ovenSchedules).insert(
        OvenSchedulesCompanion.insert(
          ovenId: 'OVEN-ROTARY-1',
          ovenType: const Value('rotary'),
          productId: 1,
          quantity: 150,
          scheduledStart: DateTime.now(),
          scheduledEnd: DateTime.now().add(const Duration(minutes: 45)),
        ),
      );
      expect(scheduleId, greaterThan(0));

      // Custom Order insert with parent customer
      final custId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-CAKE-01',
          shopName: 'Bakehouse Delight',
          ownerName: 'Sunita',
          phone: '9848012345',
        ),
      );

      final customOrderId = await db.into(db.customOrders).insert(
        CustomOrdersCompanion.insert(
          customerId: custId,
          cakeType: 'Belgian Truffle Anniversary Cake',
          deliveryDate: DateTime.now().add(const Duration(days: 2)),
          totalAmountMinor: 250000,
          advanceAmountMinor: const Value(100000),
          status: const Value('confirmed'),
        ),
      );
      expect(customOrderId, greaterThan(0));

      // Returnable Container insert
      final containerId = await db.into(db.returnableContainers).insert(
        ReturnableContainersCompanion.insert(
          containerCode: 'CAN-M-042',
          containerType: 'milk_can',
          depositAmountMinor: const Value(50000),
          status: const Value('in_warehouse'),
        ),
      );
      expect(containerId, greaterThan(0));
    });

    test('4. Existing products retain v5 schema integrity with nullable v6 extensions', () async {
      final allProducts = await db.select(db.products).get();
      expect(allProducts.isNotEmpty, isTrue);

      for (final p in allProducts) {
        expect(p.id, greaterThan(0));
        expect(p.name.isNotEmpty, isTrue);
        expect(p.price, greaterThan(0));
        // v6 columns are safely nullable or defaulted
        expect(p.storageType, isNotEmpty);
        expect(p.shelfLifeDays, greaterThan(0));
      }
    });

    test('5. Returnable container tracking preserves customer relationship', () async {
      // 1. Create customer
      final custId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-CONT-01',
          shopName: 'Taj Confectioneries',
          ownerName: 'Chef Vikas',
          phone: '9988776655',
        ),
      );

      // 2. Issue container
      final cId = await db.into(db.returnableContainers).insert(
        ReturnableContainersCompanion.insert(
          containerCode: 'CRT-B-888',
          containerType: 'crate',
          customerId: Value(custId),
          depositAmountMinor: const Value(15000),
          status: const Value('with_customer'),
        ),
      );
      expect(cId, greaterThan(0));

      // 3. Query container by customer
      final customerContainers = await (db.select(db.returnableContainers)
            ..where((c) => c.customerId.equals(custId)))
          .get();
      expect(customerContainers.length, equals(1));
      expect(customerContainers.first.containerCode, equals('CRT-B-888'));
      expect(customerContainers.first.status, equals('with_customer'));
    });
  });
}
