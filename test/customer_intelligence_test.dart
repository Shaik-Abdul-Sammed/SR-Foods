import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/database/database_provider.dart';
import 'package:sr_foods/core/services/customer_intelligence_service.dart';
import 'package:sr_foods/features/customers/presentation/screens/hotel_360_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 3 — Customer Intelligence Tests (14 Analyses)', () {
    final testCustomer = Customer(
      id: 1,
      code: 'CUST-001',
      shopName: 'Grand Swagath Hotel',
      ownerName: 'Venkatesh Rao',
      phone: '9876543210',
      creditLimit: 20000.0,
      openingBalance: 0.0,
      currentBalance: 8500.0,
      isActive: true,
      isFavorite: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final seededProducts = [
      Product(
        id: 1,
        sku: 'SRF-BRD-001',
        name: 'Classic Parota (5 pcs)',
        category: 'Breads',
        price: 45.0,
        costPrice: 28.0,
        piecesPerPack: 5,
        weightGrams: 400.0,
        unit: 'Pack',
        currentStock: 100,
        minStock: 20,
        isActive: true,
        isAvailable: true,
        taxCategory: 'EXEMPT',
        storageType: 'ambient',
        allergens: 'Wheat (Gluten)',
        hsnCode: '19059040',
        shelfLifeDays: 7,
        unitsPerInnerPack: 1,
        packsPerMasterCarton: 20,
        priceBandCurrency: 'INR',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Product(
        id: 2,
        sku: 'SRF-BRD-002',
        name: 'Whole Wheat Chapathi (10 pcs)',
        category: 'Breads',
        price: 55.0,
        costPrice: 32.0,
        piecesPerPack: 10,
        weightGrams: 450.0,
        unit: 'Pack',
        currentStock: 150,
        minStock: 25,
        isActive: true,
        isAvailable: true,
        taxCategory: 'EXEMPT',
        storageType: 'ambient',
        allergens: 'Wheat (Gluten)',
        hsnCode: '19059040',
        shelfLifeDays: 5,
        unitsPerInnerPack: 1,
        packsPerMasterCarton: 20,
        priceBandCurrency: 'INR',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    test('Step 3.1: RFM, Regularity, Margin, and Churn Risk calculation for active customer', () {
      final now = DateTime(2026, 11, 14);
      final orders = [
        Order(
          id: 101,
          orderNumber: 'ORD-101',
          customerId: 1,
          status: 'delivered',
          subtotal: 4500.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 4500.0,
          paidAmount: 4500.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderDate: now.subtract(const Duration(days: 2)),
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
        Order(
          id: 102,
          orderNumber: 'ORD-102',
          customerId: 1,
          status: 'delivered',
          subtotal: 4500.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 4500.0,
          paidAmount: 4500.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderDate: now.subtract(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(days: 5)),
        ),
        Order(
          id: 103,
          orderNumber: 'ORD-103',
          customerId: 1,
          status: 'delivered',
          subtotal: 4500.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 4500.0,
          paidAmount: 4500.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderDate: now.subtract(const Duration(days: 8)),
          createdAt: now.subtract(const Duration(days: 8)),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
      ];

      final items = [
        OrderItem(
          id: 1,
          orderId: 101,
          productId: 1,
          productName: 'Classic Parota (5 pcs)',
          price: 45.0,
          quantity: 100,
          discount: 0.0,
          total: 4500.0,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      final profile = CustomerIntelligenceService.instance.buildHotel360Profile(
        customer: testCustomer,
        orders: orders,
        orderItems: items,
        invoices: [],
        products: seededProducts,
        referenceDate: now,
      );

      // Verify RFM
      expect(profile.daysSinceLastOrder, 2);
      expect(profile.totalRevenue, 13500.0);
      expect(profile.rfmSegment, isIn([RfmSegment.loyal, RfmSegment.champions, RfmSegment.potential]));

      // Verify Regularity
      expect(profile.orderCycleDays, closeTo(3.0, 0.5));
      expect(profile.regularityScore, greaterThan(0.5));

      // Verify Margin
      expect(profile.grossMarginPercentage, greaterThan(30.0));
      expect(profile.grossMarginRupees, greaterThan(1000.0));

      // Verify Low Churn
      expect(profile.churnRiskLevel, ChurnRiskLevel.low);
      expect(profile.churnRiskProbability, lessThan(0.25));

      // Verify Cross-sell identifies missing Chapathi
      expect(profile.crossSellRecommendations.any((r) => r.contains('Chapathi')), isTrue);
    });

    test('Step 3.2: Churn Detection fires early warnings when order cycle is overdue', () {
      final now = DateTime(2026, 11, 14);
      final staleOrders = [
        Order(
          id: 201,
          orderNumber: 'ORD-201',
          customerId: 1,
          status: 'delivered',
          subtotal: 3000.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 3000.0,
          paidAmount: 3000.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderDate: now.subtract(const Duration(days: 25)),
          createdAt: now.subtract(const Duration(days: 25)),
          updatedAt: now.subtract(const Duration(days: 25)),
        ),
        Order(
          id: 202,
          orderNumber: 'ORD-202',
          customerId: 1,
          status: 'delivered',
          subtotal: 3000.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 3000.0,
          paidAmount: 3000.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderDate: now.subtract(const Duration(days: 28)),
          createdAt: now.subtract(const Duration(days: 28)),
          updatedAt: now.subtract(const Duration(days: 28)),
        ),
      ];

      final profile = CustomerIntelligenceService.instance.buildHotel360Profile(
        customer: testCustomer,
        orders: staleOrders,
        orderItems: [],
        invoices: [],
        products: seededProducts,
        referenceDate: now,
      );

      expect(profile.daysSinceLastOrder, 25);
      expect(profile.churnRiskLevel, isIn([ChurnRiskLevel.high, ChurnRiskLevel.critical]));
      expect(profile.churnSignals.isNotEmpty, isTrue);
      expect(profile.nextBestAction.contains('Win-Back') || profile.nextBestAction.contains('Call'), isTrue);
    });

    test('Step 3.3: Dunning Tier identifies credit frozen when debt breaches limit or overdue', () {
      final now = DateTime(2026, 11, 14);
      final overdueInvoices = [
        Invoice(
          id: 301,
          invoiceNumber: 'INV-2026-301',
          orderId: 101,
          customerId: 1,
          status: 'unpaid',
          subtotal: 22000.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 22000.0,
          paidAmount: 0.0,
          pendingAmount: 22000.0,
          isPrinted: false,
          invoiceDate: now.subtract(const Duration(days: 45)),
          dueDate: now.subtract(const Duration(days: 15)),
          createdAt: now.subtract(const Duration(days: 45)),
        ),
      ];

      final stressedCustomer = testCustomer.copyWith(
        currentBalance: 22000.0,
        creditLimit: 20000.0,
      );

      final profile = CustomerIntelligenceService.instance.buildHotel360Profile(
        customer: stressedCustomer,
        orders: [],
        orderItems: [],
        invoices: overdueInvoices,
        products: seededProducts,
        referenceDate: now,
      );

      expect(profile.dunningTier, DunningTier.creditFrozen);
      expect(profile.nextBestAction.contains('Freeze Credit'), isTrue);
      expect(profile.suggestedWhatsAppMessage.contains('overdue'), isTrue);
    });

    testWidgets('Step 3.4: Hotel360Screen pumps cleanly with cards, risk radar, and action buttons', (tester) async {
      await db.into(db.customers).insert(testCustomer);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Hotel360Screen(customerId: 1),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hotel 360° Intelligence'), findsOneWidget);
      expect(find.text('Grand Swagath Hotel'), findsOneWidget);
      expect(find.text('AI NEXT BEST ACTION'), findsOneWidget);
      expect(find.text('CHURN RISK RADAR'), findsOneWidget);
      expect(find.text('FINANCIAL & CREDIT HEALTH'), findsOneWidget);
      expect(find.text('BREAD BASKET & CROSS-SELL'), findsOneWidget);
      expect(find.text('WhatsApp 1-Tap'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
    });
  });
}
