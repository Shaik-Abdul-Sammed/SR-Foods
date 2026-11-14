import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/standing_order_service.dart';
import 'package:sr_foods/features/orders/presentation/widgets/dispatch_live_tracker_card.dart';
import 'package:sr_foods/features/orders/presentation/widgets/quick_reorder_sheet.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 6 — Swiggy UX & Sysco B2B Experience Tests', () {
    final sampleProduct = Product(
      id: 1,
      sku: 'SRF-BRD-001',
      name: 'Classic Malabar Parota (5 pcs)',
      category: 'Breads',
      price: 45.0,
      costPrice: 28.0,
      piecesPerPack: 5,
      weightGrams: 400.0,
      unit: 'Pack',
      currentStock: 1000,
      minStock: 100,
      isActive: true,
      isAvailable: true,
      taxCategory: 'EXEMPT',
      storageType: 'ambient',
      allergens: 'Wheat (Gluten)',
      hsnCode: '19059040',
      shelfLifeDays: 7,
      unitsPerInnerPack: 1,
      packsPerMasterCarton: 20, // 20 packs per carton
      priceBandCurrency: 'INR',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('Step 6.1: Sysco-Grade Multi-Unit Conversion (Pieces, Cartons, Pallets, Weight)', () {
      // 200 packs:
      // pieces = 200 * 5 = 1,000 pcs
      // cartons = 200 / 20 = 10 cartons
      // pallets = 10 / 40 = 0.25 pallet loads
      // weight = 200 * 400g / 1000 = 80.0 kg
      final result = StandingOrderService.instance.convertUnits(
        product: sampleProduct,
        quantityPacks: 200,
      );

      expect(result.totalPieces, 1000);
      expect(result.totalPacks, 200);
      expect(result.masterCartons, 10.0);
      expect(result.palletLoads, 0.25);
      expect(result.totalWeightKg, 80.0);
    });

    test('Step 6.2: Standing Order Schedule (MWF cadence) and Idempotency Check', () {
      final mwfOrder = StandingOrder(
        id: 1,
        customerId: 10,
        recurringDaysJson: '[1, 3, 5]', // Mon, Wed, Fri
        defaultBasketJson: '[{"productId": 1, "quantity": 50}]',
        autoInvoiceOnDelivery: true,
        activeFrom: DateTime(2026, 11, 1),
        isActive: true,
      );

      // 2026-11-16 is Monday (weekday = 1) -> should generate
      final monday = DateTime(2026, 11, 16);
      expect(StandingOrderService.instance.shouldGenerateOrderForDate(standingOrder: mwfOrder, targetDate: monday), isTrue);

      // 2026-11-17 is Tuesday (weekday = 2) -> should NOT generate
      final tuesday = DateTime(2026, 11, 17);
      expect(StandingOrderService.instance.shouldGenerateOrderForDate(standingOrder: mwfOrder, targetDate: tuesday), isFalse);

      // Idempotency: if already generated on Monday, running again on Monday returns false
      final alreadyRunOrder = mwfOrder.copyWith(lastGeneratedAt: Value(monday));
      expect(StandingOrderService.instance.shouldGenerateOrderForDate(standingOrder: alreadyRunOrder, targetDate: monday), isFalse);
    });

    test('Step 6.3: Automated Standing Order Execution into Database', () async {
      final customer = Customer(
        id: 10,
        code: 'CUST-HOTEL-01',
        shopName: 'Pista House Charminar',
        ownerName: 'Mirza Baig',
        phone: '9848012345',
        creditLimit: 50000.0,
        openingBalance: 0.0,
        currentBalance: 0.0,
        isActive: true,
        isFavorite: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.into(db.customers).insert(customer);

      final standingOrder = StandingOrder(
        id: 1,
        customerId: 10,
        recurringDaysJson: '[1, 2, 3, 4, 5, 6, 7]', // Daily
        defaultBasketJson: '[{"productId": 1, "quantity": 100}]',
        autoInvoiceOnDelivery: true,
        activeFrom: DateTime(2026, 1, 1),
        isActive: true,
      );
      await db.into(db.standingOrders).insert(standingOrder);

      final orderDate = DateTime(2026, 11, 14);
      final orderId = await StandingOrderService.instance.generateStandingOrderExecution(
        db: db,
        standingOrder: standingOrder,
        targetDate: orderDate,
      );

      expect(orderId, isNotNull);

      // Verify order generated in database
      final order = await (db.select(db.orders)..where((o) => o.id.equals(orderId!))).getSingle();
      expect(order.subtotal, 8500.0); // 100 packs * Rs 85 (SRF-BRD-001)
      expect(order.status, 'pending');

      final items = await (db.select(db.orderItems)..where((oi) => oi.orderId.equals(orderId!))).get();
      expect(items.length, 1);
      expect(items.first.quantity, 100);
    });

    testWidgets('Step 6.4: DispatchLiveTrackerCard renders live cold-chain status and milestones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DispatchLiveTrackerCard(
              orderNumber: 'ORD-2026-5501',
              hotelName: 'Taj Falaknuma Palace',
              reeferTemperature: -18.4,
              onReorderTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LIVE DISPATCH RADAR'), findsOneWidget);
      expect(find.text('ORD-2026-5501'), findsOneWidget);
      expect(find.text('-18.4°C [Cold Chain OK]'), findsOneWidget);
      expect(find.text('Dough Mixing & Proofing'), findsOneWidget);
      expect(find.text('Parota Pressing & Griddle'), findsOneWidget);
      expect(find.text('Reefer Van Dispatched'), findsOneWidget);
      expect(find.text('10-Sec Quick Reorder for Tomorrow'), findsOneWidget);
    });

    testWidgets('Step 6.5: QuickReorderSheet allows 1-tap quantity modification and confirmation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickReorderSheet(
              hotelName: 'Minerva Coffee Shop',
              favoriteItems: [
                {'name': 'Malabar Parota (5 pcs)', 'qty': 50, 'price': 45.0},
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('10-SECOND QUICK REORDER'), findsOneWidget);
      expect(find.text('Minerva Coffee Shop'), findsOneWidget);
      expect(find.text('50 pk'), findsOneWidget);
      expect(find.text('₹2250'), findsOneWidget); // 50 * 45

      // Tap '+' to add 10 packs
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('60 pk'), findsOneWidget);
      expect(find.text('₹2700'), findsOneWidget); // 60 * 45

      // Tap confirm button
      await tester.tap(find.text('Confirm for Tomorrow 06:00 AM Drop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Order Confirmed for 06:00 AM Morning Route!'), findsOneWidget);
    });
  });
}
