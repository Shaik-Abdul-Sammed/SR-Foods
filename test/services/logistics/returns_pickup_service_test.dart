import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/logistics/returns_pickup_service.dart';

void main() {
  late AppDatabase db;
  late ReturnsPickupService service;
  int testCustomerId = 1;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ReturnsPickupService(db);

    testCustomerId = await db.into(db.customers).insert(
          CustomersCompanion.insert(
            code: 'CUST-RET-01',
            shopName: 'Green Grocers',
            ownerName: 'Returns Customer',
            phone: '9876540001',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('ReturnsPickupService Tests', () {
    test('1. Schedules return pickup and calculates deposit refund', () async {
      final request = PickupRequest(
        customerId: testCustomerId,
        containerType: 'chilled_crate_20l',
        quantity: 5,
        depositPerUnitMinor: 20000, // ₹200.00
      );

      final result = await service.processPickup(request);
      expect(result.isProcessed, isTrue);
      expect(result.totalUnitsCollected, 5);
      expect(result.totalDepositRefundMinor, 100000); // ₹1,000.00
      expect(result.depositRefundRupees, 1000.0);
    });

    test('2. Accurately tracks customer outstanding deposit balance', () async {
      // 1. Issue 10 containers @ ₹200
      for (int i = 0; i < 10; i++) {
        await db.into(db.returnableContainers).insert(
              ReturnableContainersCompanion.insert(
                containerType: 'chilled_crate_20l',
                containerCode: 'CRATE-INIT-$i',
                customerId: Value(testCustomerId),
                depositAmountMinor: const Value(20000),
                status: const Value('with_customer'),
              ),
            );
      }

      var outstanding = await service.getCustomerOutstandingDepositMinor(testCustomerId);
      expect(outstanding, 200000); // ₹2,000.00 held

      // 2. Return 6 containers
      await service.processPickup(PickupRequest(
        customerId: testCustomerId,
        containerType: 'chilled_crate_20l',
        quantity: 6,
        depositPerUnitMinor: 20000,
      ));

      outstanding = await service.getCustomerOutstandingDepositMinor(testCustomerId);
      expect(outstanding, 80000); // 4 remaining * 200 = ₹800.00
    });
  });
}
