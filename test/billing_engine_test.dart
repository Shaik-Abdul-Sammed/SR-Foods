import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/billing_engine.dart';

void main() {
  group('Phase 4 — Commercial Billing Engine Tests (16 Capabilities)', () {
    final freshParota = Product(
      id: 1,
      sku: 'SRF-BRD-001',
      name: 'Fresh Malabar Parota (5 pcs)',
      category: 'Breads',
      price: 45.0,
      costPrice: 28.0,
      piecesPerPack: 5,
      weightGrams: 400.0,
      unit: 'Pack',
      currentStock: 500,
      minStock: 50,
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
    );

    final frozenParota = Product(
      id: 2,
      sku: 'SRF-FRZ-001',
      name: 'Frozen Malabar Parota (10 pcs Blast Frozen)',
      category: 'Frozen',
      price: 90.0,
      costPrice: 55.0,
      piecesPerPack: 10,
      weightGrams: 800.0,
      unit: 'Pack',
      currentStock: 300,
      minStock: 40,
      isActive: true,
      isAvailable: true,
      taxCategory: 'GST_5',
      storageType: 'frozen',
      allergens: 'Wheat (Gluten)',
      hsnCode: '19059040',
      shelfLifeDays: 365,
      unitsPerInnerPack: 1,
      packsPerMasterCarton: 12,
      priceBandCurrency: 'INR',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('Capability 1 & 2: Volume Slab Discount (5% on 100 packs) + Contract Price Override', () {
      final bill = BillingEngine.instance.calculateBill(
        orderItems: [
          {
            'product': freshParota,
            'quantity': 100,
          },
        ],
        taxRegime: TaxRegimeType.intraStateGst,
        contractPriceList: {
          'SRF-BRD-001': 42.0, // Negotiated contract price instead of Rs 45
        },
      );

      expect(bill.lines.first.unitPrice, 42.0);
      expect(bill.grossSubtotal, 4200.0);
      // 100 packs qualifies for 5% volume tier (100-249 packs)
      expect(bill.volumeDiscountTotal, 210.0); // 5% of 4200
      expect(bill.netTaxableSubtotal, 3990.0);
    });

    test('Capability 3 & 4: Early Cash Discount (2%) and Buy-X-Get-Y Promotional Scheme', () {
      final promotions = [
        const PromotionalScheme(
          sku: 'SRF-FRZ-001',
          buyUnits: 20,
          freeSku: 'SRF-BRD-001',
          freeUnits: 1,
          schemeName: 'Buy 20 Frozen, Get 1 Fresh Free',
        ),
      ];

      final bill = BillingEngine.instance.calculateBill(
        orderItems: [
          {
            'product': frozenParota,
            'quantity': 45, // 2 full batches of 20 = 2 free units
          },
        ],
        taxRegime: TaxRegimeType.intraStateGst,
        activePromotions: promotions,
        applyEarlyCashDiscount: true,
        cashDiscountPercent: 2.0,
      );

      final line = bill.lines.first;
      expect(line.promotionalFreeUnits, 2);
      expect(line.appliedSchemeName, 'Buy 20 Frozen, Get 1 Fresh Free');
      expect(bill.cashDiscountTotal, greaterThan(0.0));
      expect(bill.totalDiscounts, bill.cashDiscountTotal + bill.volumeDiscountTotal);
    });

    test('Capability 5, 6, 7 & 8: Dual Tax Regimes (Intra-State vs Inter-State vs Export LUT)', () {
      // Intra-state (5% = 2.5% CGST + 2.5% SGST)
      final intraBill = BillingEngine.instance.calculateBill(
        orderItems: [
          {'product': frozenParota, 'quantity': 10},
        ],
        taxRegime: TaxRegimeType.intraStateGst,
      );
      expect(intraBill.cgstTotal, intraBill.sgstTotal);
      expect(intraBill.cgstTotal, 22.5); // 2.5% of 900
      expect(intraBill.sgstTotal, 22.5);
      expect(intraBill.igstTotal, 0.0);
      expect(intraBill.totalTax, 45.0);

      // Inter-state (5% IGST)
      final interBill = BillingEngine.instance.calculateBill(
        orderItems: [
          {'product': frozenParota, 'quantity': 10},
        ],
        taxRegime: TaxRegimeType.interStateGst,
      );
      expect(interBill.cgstTotal, 0.0);
      expect(interBill.sgstTotal, 0.0);
      expect(interBill.igstTotal, 45.0);
      expect(interBill.totalTax, 45.0);

      // Export LUT (0%)
      final lutBill = BillingEngine.instance.calculateBill(
        orderItems: [
          {'product': frozenParota, 'quantity': 10},
        ],
        taxRegime: TaxRegimeType.exportZeroRatedLut,
      );
      expect(lutBill.totalTax, 0.0);
    });

    test('Capability 9, 10, 11 & 12: HSN Summary, MOV Surcharge, Crate Deposit, TCS 206C(1H)', () {
      final bill = BillingEngine.instance.calculateBill(
        orderItems: [
          {'product': freshParota, 'quantity': 5}, // 5 * 45 = Rs 225 (< Rs 1000 MOV)
        ],
        taxRegime: TaxRegimeType.intraStateGst,
        minimumOrderValue: 1000.0,
        movSurchargeAmount: 50.0,
        crateCount: 2,
        crateDepositPerUnit: 25.0, // Rs 50 crate deposit
        applyTcs: true,
        tcsRatePercent: 0.1,
      );

      expect(bill.movSurcharge, 50.0);
      expect(bill.crateDepositTotal, 50.0);
      expect(bill.hsnSummary.length, 1);
      expect(bill.hsnSummary.first.hsnCode, '19059040');
      expect(bill.tcsAmount, greaterThan(0.0));
      expect(bill.grandTotal, closeTo(225.0 + 50.0 + 50.0 + bill.tcsAmount, 1.0));
    });

    test('Capability 14: FIFO Payment Allocation across Multiple Invoices with Partial Settlement', () {
      final now = DateTime(2026, 11, 14);
      final unpaidInvoices = [
        Invoice(
          id: 1,
          invoiceNumber: 'INV-001',
          orderId: 10,
          customerId: 1,
          status: 'unpaid',
          subtotal: 1000.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 1000.0,
          paidAmount: 0.0,
          pendingAmount: 1000.0,
          isPrinted: false,
          invoiceDate: now.subtract(const Duration(days: 20)),
          dueDate: now.subtract(const Duration(days: 10)),
          createdAt: now.subtract(const Duration(days: 20)),
        ),
        Invoice(
          id: 2,
          invoiceNumber: 'INV-002',
          orderId: 11,
          customerId: 1,
          status: 'partial',
          subtotal: 2000.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 2000.0,
          paidAmount: 500.0,
          pendingAmount: 1500.0,
          isPrinted: false,
          invoiceDate: now.subtract(const Duration(days: 15)),
          dueDate: now.subtract(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 15)),
        ),
        Invoice(
          id: 3,
          invoiceNumber: 'INV-003',
          orderId: 12,
          customerId: 1,
          status: 'unpaid',
          subtotal: 1200.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 1200.0,
          paidAmount: 0.0,
          pendingAmount: 1200.0,
          isPrinted: false,
          invoiceDate: now.subtract(const Duration(days: 5)),
          dueDate: now.add(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 5)),
        ),
      ];

      // Customer makes a payment of Rs 2,000 via UPI
      final allocations = BillingEngine.instance.allocatePaymentFifo(
        paymentAmount: 2000.0,
        unpaidInvoices: unpaidInvoices,
      );

      expect(allocations.length, 2);

      // First invoice (Rs 1,000) fully paid
      expect(allocations[0].invoiceId, 1);
      expect(allocations[0].allocatedAmount, 1000.0);
      expect(allocations[0].remainingPendingAmount, 0.0);
      expect(allocations[0].isFullyPaid, isTrue);

      // Second invoice (Rs 1,500 pending) receives remaining Rs 1,000
      expect(allocations[1].invoiceId, 2);
      expect(allocations[1].allocatedAmount, 1000.0);
      expect(allocations[1].remainingPendingAmount, 500.0);
      expect(allocations[1].isFullyPaid, isFalse);
    });

    test('Capability 15: Overdue Commercial Interest calculation at 18% p.a.', () {
      final dueDate = DateTime(2026, 10, 15);
      final currentDate = DateTime(2026, 11, 14); // 30 days overdue

      final interest = BillingEngine.instance.computeOverdueInterest(
        pendingAmount: 10000.0,
        dueDate: dueDate,
        currentDate: currentDate,
        annualInterestRate: 18.0,
      );

      // Daily interest = (10000 * 0.18) / 365 = 4.9315 per day
      // 30 days = ~147.95
      expect(interest, closeTo(147.95, 1.0));
    });
  });
}
