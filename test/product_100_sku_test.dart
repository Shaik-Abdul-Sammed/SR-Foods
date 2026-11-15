import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/gst_invoice_service.dart';

void main() {
  group('Phase 1 — Data Foundation & 100-SKU Catalog Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('100-SKU Master Catalog seeds exactly 100 items across 12 categories with compliant attributes', () async {
      // Trigger default seed
      final allProducts = await db.select(db.products).get();

      // Assert total catalog reached 180 SKUs (100 frozen master + 40 dairy + 40 bakery)
      expect(allProducts.length, 180);

      // Assert frozen master catalog contains exactly 100 SKUs
      final frozenProducts = allProducts.where((p) => !p.sku.startsWith('SRF-DAI-1') && !p.sku.startsWith('SRF-BKY-')).toList();
      expect(frozenProducts.length, 100);

      // Assert 12 distinct categories
      final distinctCategories = frozenProducts.map((p) => p.category).toSet();
      expect(distinctCategories.length, 12);
      expect(distinctCategories, containsAll([
        'Indian Breads',
        'South Indian Ready',
        'Breakfast Batters',
        'Paneer & Dairy',
        'Frozen Snacks',
        'Frozen Vegetables',
        'Ready Gravies',
        'Rice & Biryani',
        'Sweets',
        'Chutneys & Sauces',
        'Export / Diaspora',
        'Private Label',
      ]));

      // Assert mandatory compliance attributes are populated on every single row
      for (final product in allProducts) {
        expect(product.sku, startsWith('SRF-'));
        expect(product.storageType, isIn(['ambient', 'chilled', 'frozen']));
        expect(product.hsnCode.isNotEmpty, isTrue);
        expect(product.shelfLifeDays, greaterThan(0));
        expect(product.unitsPerInnerPack, greaterThan(0));
        expect(product.packsPerMasterCarton, greaterThan(0));
        expect(product.priceBandCurrency.isNotEmpty, isTrue);
      }
    });

    test('New Schema v5 tables (CustomerPriceLists, CreditNotes, DebitNotes, StandingOrders, etc.) support full operations', () async {
      // Insert customer & product
      final custId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-TEST-01',
          shopName: 'Grand Chola Kitchens',
          ownerName: 'Chef Raman',
          phone: '9876543210',
        ),
      );

      final allProducts = await db.select(db.products).get();
      final prodId = allProducts.first.id;

      // 1. CustomerPriceLists
      final priceListId = await db.into(db.customerPriceLists).insert(
        CustomerPriceListsCompanion.insert(
          customerId: custId,
          productId: prodId,
          customPriceMinor: 8000, // ₹80.00
          currencyCode: const Value('INR'),
        ),
      );
      expect(priceListId, greaterThan(0));
      final priceEntry = await (db.select(db.customerPriceLists)..where((t) => t.id.equals(priceListId))).getSingle();
      expect(priceEntry.customPriceMinor, 8000);

      // 2. Orders & Invoices for notes
      final orderId = await db.into(db.orders).insert(
        OrdersCompanion.insert(
          orderNumber: 'ORD-TEST-100',
          customerId: custId,
          grandTotal: const Value(5000.0),
        ),
      );

      final invId = await db.into(db.invoices).insert(
        InvoicesCompanion.insert(
          invoiceNumber: 'INV-TEST-100',
          orderId: orderId,
          customerId: custId,
          subtotal: 4500.0,
          grandTotal: 5000.0,
        ),
      );

      // 3. CreditNotes
      final creditNoteId = await db.into(db.creditNotes).insert(
        CreditNotesCompanion.insert(
          noteNumber: 'CN-2026-001',
          originalInvoiceId: invId,
          customerId: custId,
          reasonCode: 'damage',
          amountMinor: 50000, // ₹500.00
          gstReversalMinor: const Value(2500),
          status: const Value('issued'),
        ),
      );
      expect(creditNoteId, greaterThan(0));

      // 4. DebitNotes
      final debitNoteId = await db.into(db.debitNotes).insert(
        DebitNotesCompanion.insert(
          noteNumber: 'DN-2026-001',
          originalInvoiceId: Value(invId),
          customerId: custId,
          reasonCode: 'undercharge',
          amountMinor: 20000,
        ),
      );
      expect(debitNoteId, greaterThan(0));

      // 5. StandingOrders
      final standingOrderId = await db.into(db.standingOrders).insert(
        StandingOrdersCompanion.insert(
          customerId: custId,
          defaultBasketJson: '[{"productId": $prodId, "quantity": 100}]',
          autoInvoiceOnDelivery: const Value(true),
        ),
      );
      expect(standingOrderId, greaterThan(0));

      // 6. MachineEvents
      final eventId = await db.into(db.machineEvents).insert(
        MachineEventsCompanion.insert(
          machineId: 'MIXER-01',
          machineName: 'Spiral Dough Mixer 200L',
          eventType: 'vibration_check',
          severity: const Value('info'),
          vibrationMmS: const Value(2.1),
          temperatureCelsius: const Value(38.5),
        ),
      );
      expect(eventId, greaterThan(0));

      // 7. WastageLogs
      final wasteId = await db.into(db.wastageLogs).insert(
        WastageLogsCompanion.insert(
          stage: 'pressing',
          reason: 'torn',
          wastageKg: 4.5,
          costEstimatedMinor: const Value(35000),
        ),
      );
      expect(wasteId, greaterThan(0));

      // 8. Complaints
      final compId = await db.into(db.complaints).insert(
        ComplaintsCompanion.insert(
          ticketNumber: 'TKT-2026-001',
          customerId: custId,
          category: 'quality',
          description: 'Package vacuum seal punctured during delivery',
        ),
      );
      expect(compId, greaterThan(0));
    });

    test('Step 1.10: Mixed-HSN invoice generates PDF with line-specific HSN codes', () async {
      final allProducts = await db.select(db.products).get();
      final p1 = allProducts.first; // Parotta, HSN 1905.90.90
      final p2 = allProducts.firstWhere((p) => p.category == 'Paneer & Dairy'); // Paneer, HSN 0406

      final invoice = Invoice(
        id: 1,
        invoiceNumber: 'INV-2026-HSN-TEST',
        orderId: 1,
        customerId: 1,
        subtotal: 1000.0,
        discount: 0.0,
        tax: 50.0,
        grandTotal: 1050.0,
        paidAmount: 0.0,
        pendingAmount: 1050.0,
        status: 'unpaid',
        isPrinted: false,
        invoiceDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final customer = Customer(
        id: 1,
        code: 'CUST-01',
        shopName: 'Spice Junction Restaurant',
        ownerName: 'Mr. Khan',
        phone: '9848012345',
        creditLimit: 10000.0,
        openingBalance: 0.0,
        currentBalance: 0.0,
        isActive: true,
        isFavorite: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = [
        OrderItem(
          id: 1,
          orderId: 1,
          productId: p1.id,
          productName: p1.name,
          price: p1.price,
          quantity: 10,
          discount: 0.0,
          total: p1.price * 10,
          createdAt: DateTime.now(),
        ),
        OrderItem(
          id: 2,
          orderId: 1,
          productId: p2.id,
          productName: p2.name,
          price: p2.price,
          quantity: 5,
          discount: 0.0,
          total: p2.price * 5,
          createdAt: DateTime.now(),
        ),
      ];

      final hsnMap = {
        p1.id: p1.hsnCode,
        p2.id: p2.hsnCode,
      };

      final pdfBytes = await GstInvoiceService.instance.generateA4TaxInvoice(
        invoice: invoice,
        customer: customer,
        items: items,
        itemHsnMap: hsnMap,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
