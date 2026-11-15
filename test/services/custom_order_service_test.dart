import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/custom_order_service.dart';

void main() {
  late AppDatabase db;
  late CustomOrderService orderService;
  int testCustomerId = 1;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    orderService = const CustomOrderService();

    // Ensure customer exists for FK constraint
    final customer = await (db.select(db.customers)..limit(1)).getSingleOrNull();
    if (customer == null) {
      testCustomerId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-BAKE-01',
          shopName: 'Sweet Tooth Bakery Cafe',
          ownerName: 'Sunita Rao',
          phone: '9876543210',
          address: const Value('45 MG Road, Bengaluru'),
        ),
      );
    } else {
      testCustomerId = customer.id;
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomOrderService', () {
    test('createCustomOrder inserts record and correctly computes balance due', () async {
      final delivery = DateTime(2026, 11, 25, 16, 0);

      final result = await orderService.createCustomOrder(
        db: db,
        customerId: testCustomerId,
        deliveryDate: delivery,
        cakeType: 'Dutch Chocolate Truffle 2kg',
        decorationNotes: 'Happy 50th Anniversary written in gold cursive lettering',
        photoRef: 'uploads/cakes/anniv_gold_01.jpg',
        totalAmountMinor: 250000, // Rs 2,500.00
        advanceAmountMinor: 100000, // Rs 1,000.00
      );

      expect(result.orderId, greaterThan(0));
      expect(result.customerId, equals(testCustomerId));
      expect(result.cakeType, equals('Dutch Chocolate Truffle 2kg'));
      expect(result.advanceAmount.amountMinor, equals(100000));
      expect(result.totalAmount.amountMinor, equals(250000));
      expect(result.balanceDue.amountMinor, equals(150000)); // 2500 - 1000 = 1500
      expect(result.status, equals('confirmed'));
    });

    test('createCustomOrder with 0 advance leaves total as balance due', () async {
      final delivery = DateTime(2026, 11, 25, 18, 0);

      final result = await orderService.createCustomOrder(
        db: db,
        customerId: testCustomerId,
        deliveryDate: delivery,
        cakeType: 'Red Velvet Heart Cake 1kg',
        totalAmountMinor: 120000,
        advanceAmountMinor: 0,
        status: 'enquiry',
      );

      expect(result.advanceAmount.amountMinor, equals(0));
      expect(result.balanceDue.amountMinor, equals(120000));
      expect(result.status, equals('enquiry'));
    });

    test('advanceStatus traverses full status pipeline', () async {
      final delivery = DateTime(2026, 11, 25, 16, 0);

      // Start at 'enquiry'
      final order = await orderService.createCustomOrder(
        db: db,
        customerId: testCustomerId,
        deliveryDate: delivery,
        cakeType: 'Vanilla Buttercream Floral',
        totalAmountMinor: 80000,
        status: 'enquiry',
      );

      // Step 1: enquiry -> confirmed
      final s1 = await orderService.advanceStatus(db: db, orderId: order.orderId);
      expect(s1, equals('confirmed'));

      // Step 2: confirmed -> in_production
      final s2 = await orderService.advanceStatus(db: db, orderId: order.orderId);
      expect(s2, equals('in_production'));

      // Step 3: in_production -> ready
      final s3 = await orderService.advanceStatus(db: db, orderId: order.orderId);
      expect(s3, equals('ready'));

      // Step 4: ready -> delivered
      final s4 = await orderService.advanceStatus(db: db, orderId: order.orderId);
      expect(s4, equals('delivered'));

      // Step 5: already at delivered -> stays delivered
      final s5 = await orderService.advanceStatus(db: db, orderId: order.orderId);
      expect(s5, equals('delivered'));
    });

    test('advanceStatus throws ArgumentError for non-existent order', () async {
      expect(
        () => orderService.advanceStatus(db: db, orderId: 999999),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('not found'))),
      );
    });

    test('generateCustomOrderTicket formats kitchen work ticket accurately', () async {
      final delivery = DateTime(2026, 11, 25, 14, 30);
      final order = await orderService.createCustomOrder(
        db: db,
        customerId: testCustomerId,
        deliveryDate: delivery,
        cakeType: 'Black Forest Royale 3kg',
        decorationNotes: 'Extra cherries, shaved dark Belgian chocolate flakes',
        totalAmountMinor: 300000,
        advanceAmountMinor: 150000,
        status: 'in_production',
      );

      final ticket = await orderService.generateCustomOrderTicket(
        db: db,
        orderId: order.orderId,
      );

      expect(ticket, contains('SR FOODS BAKERY — KITCHEN WORK TICKET'));
      expect(ticket, contains('#CK-${order.orderId}'));
      expect(ticket, contains('[IN_PRODUCTION]'));
      expect(ticket, contains('Black Forest Royale 3kg'));
      expect(ticket, contains('Extra cherries, shaved dark Belgian chocolate flakes'));
      expect(ticket, contains('Total Price:'));
      expect(ticket, contains('Advance Paid:'));
      expect(ticket, contains('Balance Due:'));
      expect(ticket, contains('QC Passed: [x]'));
    });

    test('generateCustomOrderTicket throws ArgumentError for non-existent order', () async {
      expect(
        () => orderService.generateCustomOrderTicket(db: db, orderId: 888888),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('not found'))),
      );
    });
  });
}
