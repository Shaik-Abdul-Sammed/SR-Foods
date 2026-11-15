import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/services/container_return_service.dart';

void main() {
  late AppDatabase db;
  late ContainerReturnService containerService;
  int testCust1 = 1;
  int testCust2 = 2;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    containerService = const ContainerReturnService();

    // Insert 2 test customers for foreign key constraints
    testCust1 = await db.into(db.customers).insert(
      CustomersCompanion.insert(
        code: 'CUST-RET-01',
        shopName: 'Green Mart Dairy',
        ownerName: 'Venkatesh Rao',
        phone: '9845012345',
      ),
    );

    testCust2 = await db.into(db.customers).insert(
      CustomersCompanion.insert(
        code: 'CUST-RET-02',
        shopName: 'Golden Crust Bakers',
        ownerName: 'Anand Kumar',
        phone: '9845067890',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ContainerReturnService Tests', () {
    test('1. issueContainer assigns container to customer with deposit and active status', () async {
      await containerService.issueContainer(
        db: db,
        containerCode: 'CRATE-101',
        customerId: testCust1,
        depositAmountMinor: 15000, // Rs 150.00
        containerType: 'crate',
        notes: 'Blue insulated milk crate',
      );

      final row = await (db.select(db.returnableContainers)
            ..where((t) => t.containerCode.equals('CRATE-101')))
          .getSingle();

      expect(row.containerType, equals('crate'));
      expect(row.customerId, equals(testCust1));
      expect(row.depositAmountMinor, equals(15000));
      expect(row.status, equals('with_customer'));
      expect(row.notes, equals('Blue insulated milk crate'));
    });

    test('2. issueContainer updates status and reassigns on conflict', () async {
      // First issue to customer 1
      await containerService.issueContainer(
        db: db,
        containerCode: 'CAN-40L-01',
        customerId: testCust1,
        depositAmountMinor: 50000, // Rs 500.00
        containerType: 'milk_can',
      );

      // Re-issue to customer 2 (e.g. after return or re-scan)
      await containerService.issueContainer(
        db: db,
        containerCode: 'CAN-40L-01',
        customerId: testCust2,
        depositAmountMinor: 55000,
        containerType: 'milk_can',
        notes: 'Transferred to Golden Crust',
      );

      final row = await (db.select(db.returnableContainers)
            ..where((t) => t.containerCode.equals('CAN-40L-01')))
          .getSingle();

      expect(row.customerId, equals(testCust2));
      expect(row.depositAmountMinor, equals(55000));
      expect(row.status, equals('with_customer'));
      expect(row.notes, equals('Transferred to Golden Crust'));
    });

    test('3. returnContainer marks container as returned and clears customer reference', () async {
      await containerService.issueContainer(
        db: db,
        containerCode: 'TRAY-BAKE-01',
        customerId: testCust1,
        depositAmountMinor: 20000,
        containerType: 'tray',
      );

      await containerService.returnContainer(
        db: db,
        containerCode: 'TRAY-BAKE-01',
        driverId: 10,
        condition: 'good',
        notes: 'Returned in pristine condition',
      );

      final row = await (db.select(db.returnableContainers)
            ..where((t) => t.containerCode.equals('TRAY-BAKE-01')))
          .getSingle();

      expect(row.customerId, isNull);
      expect(row.driverId, equals(10));
      expect(row.status, equals('returned'));
      expect(row.notes, equals('Returned in pristine condition'));
    });

    test('4. returnContainer with damaged condition marks status as damaged', () async {
      await containerService.issueContainer(
        db: db,
        containerCode: 'CRATE-DAMAGED-01',
        customerId: testCust1,
        depositAmountMinor: 15000,
      );

      await containerService.returnContainer(
        db: db,
        containerCode: 'CRATE-DAMAGED-01',
        driverId: 12,
        condition: 'damaged',
        notes: 'Cracked side wall, unusable',
      );

      final row = await (db.select(db.returnableContainers)
            ..where((t) => t.containerCode.equals('CRATE-DAMAGED-01')))
          .getSingle();

      expect(row.status, equals('damaged'));
      expect(row.notes, contains('Cracked side wall'));
    });

    test('5. trackDeposit calculates total deposit sum across all active containers', () async {
      await containerService.issueContainer(
        db: db,
        containerCode: 'CRATE-A1',
        customerId: testCust1,
        depositAmountMinor: 15000, // 150
      );
      await containerService.issueContainer(
        db: db,
        containerCode: 'CRATE-A2',
        customerId: testCust1,
        depositAmountMinor: 15000, // 150
      );
      await containerService.issueContainer(
        db: db,
        containerCode: 'CAN-A3',
        customerId: testCust1,
        depositAmountMinor: 50000, // 500
      );

      final totalDeposit = await containerService.trackDeposit(db: db, customerId: testCust1);
      expect(totalDeposit.amountMinor, equals(80000)); // 150 + 150 + 500 = 800
    });

    test('6. trackDeposit ignores returned containers and isolates other customers', () async {
      // Container 1 with customer 1
      await containerService.issueContainer(
        db: db,
        containerCode: 'CRATE-C1',
        customerId: testCust1,
        depositAmountMinor: 15000,
      );

      // Container 2 with customer 1, but returned
      await containerService.issueContainer(
        db: db,
        containerCode: 'CRATE-C2',
        customerId: testCust1,
        depositAmountMinor: 15000,
      );
      await containerService.returnContainer(db: db, containerCode: 'CRATE-C2');

      // Container 3 with customer 2
      await containerService.issueContainer(
        db: db,
        containerCode: 'CRATE-C3',
        customerId: testCust2,
        depositAmountMinor: 25000,
      );

      final cust1Deposit = await containerService.trackDeposit(db: db, customerId: testCust1);
      final cust2Deposit = await containerService.trackDeposit(db: db, customerId: testCust2);

      expect(cust1Deposit.amountMinor, equals(15000)); // Only C1 active
      expect(cust2Deposit.amountMinor, equals(25000)); // Only C3 active
    });

    test('7. trackDeposit returns Money.zero when customer has no active containers', () async {
      final deposit = await containerService.trackDeposit(db: db, customerId: 9999);
      expect(deposit.amountMinor, equals(0));
      expect(deposit, equals(Money.zero));
    });

    test('8. flagLostContainers detects containers held longer than threshold', () async {
      final now = DateTime(2026, 11, 20, 10, 0);

      // Issued 20 days ago (lost)
      await db.into(db.returnableContainers).insert(
        ReturnableContainersCompanion.insert(
          containerType: 'milk_can',
          containerCode: 'CAN-LOST-01',
          customerId: Value(testCust1),
          depositAmountMinor: const Value(50000),
          status: const Value('with_customer'),
          lastScanAt: Value(now.subtract(const Duration(days: 20))),
        ),
      );

      // Issued 5 days ago (normal)
      await db.into(db.returnableContainers).insert(
        ReturnableContainersCompanion.insert(
          containerType: 'crate',
          containerCode: 'CRATE-RECENT-02',
          customerId: Value(testCust1),
          depositAmountMinor: const Value(15000),
          status: const Value('with_customer'),
          lastScanAt: Value(now.subtract(const Duration(days: 5))),
        ),
      );

      // Issued 30 days ago, but status is 'returned' (should NOT flag)
      await db.into(db.returnableContainers).insert(
        ReturnableContainersCompanion.insert(
          containerType: 'tray',
          containerCode: 'TRAY-OLD-RETURNED-03',
          status: const Value('returned'),
          lastScanAt: Value(now.subtract(const Duration(days: 30))),
        ),
      );

      final alerts = await containerService.flagLostContainers(db: db, days: 14, now: now);

      expect(alerts.length, equals(1));
      expect(alerts.first.containerCode, equals('CAN-LOST-01'));
      expect(alerts.first.daysWithCustomer, greaterThanOrEqualTo(20));
      expect(alerts.first.depositHeld.amountMinor, equals(50000));
    });
  });
}
