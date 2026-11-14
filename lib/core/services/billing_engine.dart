import 'dart:math' as math;
import '../database/app_database.dart';

/// Tax regime specification for billing
enum TaxRegimeType {
  intraStateGst('Intra-State GST (CGST + SGST)', 0),
  interStateGst('Inter-State GST (IGST)', 1),
  exportZeroRatedLut('Export Zero-Rated (LUT)', 2),
  uaeVat('UAE Standard VAT (5%)', 3),
  usSalesTax('US State Sales Tax', 4),
  ukZeroRatedFood('UK Zero-Rated Human Food (0%)', 5),
  taxExempt('Tax Exempt', 6);

  final String description;
  final int code;
  const TaxRegimeType(this.description, this.code);
}

/// Volume discount tier rule
class VolumeDiscountTier {
  final int minQuantity;
  final int? maxQuantity;
  final double discountPercent;

  const VolumeDiscountTier({
    required this.minQuantity,
    this.maxQuantity,
    required this.discountPercent,
  });

  bool appliesTo(int quantity) {
    if (quantity < minQuantity) return false;
    if (maxQuantity != null && quantity > maxQuantity!) return false;
    return true;
  }
}

/// Buy X get Y promotional free scheme
class PromotionalScheme {
  final String sku;
  final int buyUnits;
  final String freeSku;
  final int freeUnits;
  final String schemeName;

  const PromotionalScheme({
    required this.sku,
    required this.buyUnits,
    required this.freeSku,
    required this.freeUnits,
    required this.schemeName,
  });

  int computeFreeQuantity(int boughtUnits) {
    if (boughtUnits < buyUnits) return 0;
    final batches = boughtUnits ~/ buyUnits;
    return batches * freeUnits;
  }
}

/// Calculated single line item
class BilledLineItem {
  final Product product;
  final int quantity;
  final double unitPrice;
  final double lineGross;
  final double discountPercent;
  final double discountAmount;
  final int promotionalFreeUnits;
  final String? appliedSchemeName;
  final double taxableAmount;
  final String hsnCode;
  final double taxRatePercent;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTaxAmount;
  final double lineTotal;

  const BilledLineItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.lineGross,
    required this.discountPercent,
    required this.discountAmount,
    this.promotionalFreeUnits = 0,
    this.appliedSchemeName,
    required this.taxableAmount,
    required this.hsnCode,
    required this.taxRatePercent,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTaxAmount,
    required this.lineTotal,
  });
}

/// Tax summary broken down by HSN
class HsnTaxBreakdown {
  final String hsnCode;
  final double taxableValue;
  final double taxRatePercent;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;

  const HsnTaxBreakdown({
    required this.hsnCode,
    required this.taxableValue,
    required this.taxRatePercent,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTax,
  });
}

/// Complete comprehensive calculation result
class BillCalculationResult {
  final List<BilledLineItem> lines;
  final double grossSubtotal;
  final double volumeDiscountTotal;
  final double cashDiscountTotal;
  final double promotionalDiscountTotal;
  final double totalDiscounts;
  final double movSurcharge; // Minimum order value surcharge
  final double crateDepositTotal;
  final double netTaxableSubtotal;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;
  final double totalTax;
  final List<HsnTaxBreakdown> hsnSummary;
  final double tcsAmount; // Tax Collected at Source 0.1% under 206C(1H)
  final double roundingAdjustment;
  final double grandTotal;
  final String currency;
  final double fxRateToInr;

  const BillCalculationResult({
    required this.lines,
    required this.grossSubtotal,
    required this.volumeDiscountTotal,
    required this.cashDiscountTotal,
    required this.promotionalDiscountTotal,
    required this.totalDiscounts,
    required this.movSurcharge,
    required this.crateDepositTotal,
    required this.netTaxableSubtotal,
    required this.cgstTotal,
    required this.sgstTotal,
    required this.igstTotal,
    required this.totalTax,
    required this.hsnSummary,
    required this.tcsAmount,
    required this.roundingAdjustment,
    required this.grandTotal,
    required this.currency,
    this.fxRateToInr = 1.0,
  });
}

/// Payment allocation slice against an individual invoice
class InvoicePaymentAllocation {
  final int invoiceId;
  final String invoiceNumber;
  final double originalPendingAmount;
  final double allocatedAmount;
  final double remainingPendingAmount;
  final bool isFullyPaid;

  const InvoicePaymentAllocation({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.originalPendingAmount,
    required this.allocatedAmount,
    required this.remainingPendingAmount,
    required this.isFullyPaid,
  });
}

/// Master Billing & Commercial Calculation Engine
class BillingEngine {
  BillingEngine._();
  static final BillingEngine instance = BillingEngine._();

  /// Standard volume slab tiers
  static const List<VolumeDiscountTier> defaultVolumeTiers = [
    VolumeDiscountTier(minQuantity: 50, maxQuantity: 99, discountPercent: 3.0),
    VolumeDiscountTier(minQuantity: 100, maxQuantity: 249, discountPercent: 5.0),
    VolumeDiscountTier(minQuantity: 250, maxQuantity: null, discountPercent: 8.0),
  ];

  /// Computes complete commercial bill with all 16 capabilities
  BillCalculationResult calculateBill({
    required List<Map<String, dynamic>> orderItems, // [{product: Product, quantity: int, customPrice: double?, customDiscount: double?}]
    required TaxRegimeType taxRegime,
    Map<String, double>? contractPriceList, // {sku: negotiatedPrice}
    List<VolumeDiscountTier> volumeTiers = defaultVolumeTiers,
    List<PromotionalScheme> activePromotions = const [],
    bool applyEarlyCashDiscount = false, // 2% 24h cash discount
    double cashDiscountPercent = 2.0,
    double minimumOrderValue = 1000.0,
    double movSurchargeAmount = 50.0,
    int crateCount = 0,
    double crateDepositPerUnit = 25.0, // Rs 25 per crate deposit
    bool applyTcs = false, // Section 206C(1H)
    double tcsRatePercent = 0.1,
    String currency = 'INR',
    double fxRateToInr = 1.0,
  }) {
    final billedLines = <BilledLineItem>[];
    double runningGross = 0.0;
    double runningVolumeDiscount = 0.0;
    final hsnMap = <String, List<BilledLineItem>>{};

    for (final item in orderItems) {
      final Product product = item['product'] as Product;
      final int qty = item['quantity'] as int;

      // 1. Base price resolution: contract override -> item custom -> product catalog price
      double unitPrice = product.price;
      if (contractPriceList != null && contractPriceList.containsKey(product.sku)) {
        unitPrice = contractPriceList[product.sku]!;
      } else if (item['customPrice'] != null) {
        unitPrice = (item['customPrice'] as num).toDouble();
      }

      final lineGross = unitPrice * qty;
      runningGross += lineGross;

      // 2. Volume discount tier calculation
      double volDiscountPct = 0.0;
      if (item['customDiscount'] != null) {
        volDiscountPct = (item['customDiscount'] as num).toDouble();
      } else {
        for (final tier in volumeTiers) {
          if (tier.appliesTo(qty)) {
            volDiscountPct = tier.discountPercent;
            break;
          }
        }
      }

      final discountAmount = (lineGross * volDiscountPct) / 100.0;
      runningVolumeDiscount += discountAmount;
      final taxableAmount = math.max(0.0, lineGross - discountAmount);

      // 3. Promotional scheme evaluation
      int promoFreeUnits = 0;
      String? schemeName;
      for (final scheme in activePromotions) {
        if (scheme.sku == product.sku) {
          promoFreeUnits = scheme.computeFreeQuantity(qty);
          if (promoFreeUnits > 0) {
            schemeName = scheme.schemeName;
            break;
          }
        }
      }

      // 4. Tax resolution per line & HSN
      final hsn = product.hsnCode;
      double taxRate = 0.0;
      double cgst = 0.0;
      double sgst = 0.0;
      double igst = 0.0;

      switch (taxRegime) {
        case TaxRegimeType.intraStateGst:
          taxRate = _resolveGstRate(product);
          cgst = (taxableAmount * (taxRate / 2.0)) / 100.0;
          sgst = (taxableAmount * (taxRate / 2.0)) / 100.0;
          break;
        case TaxRegimeType.interStateGst:
          taxRate = _resolveGstRate(product);
          igst = (taxableAmount * taxRate) / 100.0;
          break;
        case TaxRegimeType.uaeVat:
          taxRate = 5.0;
          igst = (taxableAmount * taxRate) / 100.0;
          break;
        case TaxRegimeType.usSalesTax:
          taxRate = 6.25;
          igst = (taxableAmount * taxRate) / 100.0;
          break;
        case TaxRegimeType.exportZeroRatedLut:
        case TaxRegimeType.ukZeroRatedFood:
        case TaxRegimeType.taxExempt:
          taxRate = 0.0;
          break;
      }

      final totalTax = cgst + sgst + igst;
      final lineTotal = taxableAmount + totalTax;

      final billedLine = BilledLineItem(
        product: product,
        quantity: qty,
        unitPrice: unitPrice,
        lineGross: lineGross,
        discountPercent: volDiscountPct,
        discountAmount: discountAmount,
        promotionalFreeUnits: promoFreeUnits,
        appliedSchemeName: schemeName,
        taxableAmount: taxableAmount,
        hsnCode: hsn,
        taxRatePercent: taxRate,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
        totalTaxAmount: totalTax,
        lineTotal: lineTotal,
      );

      billedLines.add(billedLine);
      hsnMap.putIfAbsent(hsn, () => []).add(billedLine);
    }

    // 5. Cash Discount
    final netTaxableBeforeCashDiscount = runningGross - runningVolumeDiscount;
    double cashDiscountAmount = 0.0;
    if (applyEarlyCashDiscount && netTaxableBeforeCashDiscount > 0) {
      cashDiscountAmount = (netTaxableBeforeCashDiscount * cashDiscountPercent) / 100.0;
    }

    final netTaxable = math.max(0.0, netTaxableBeforeCashDiscount - cashDiscountAmount);

    // 6. MOV Surcharge
    double movCharge = 0.0;
    if (runningGross < minimumOrderValue && runningGross > 0) {
      movCharge = movSurchargeAmount;
    }

    // 7. Crate Deposit Ledger
    final crateDeposit = crateCount * crateDepositPerUnit;

    // 8. Aggregate Taxes
    double totalCgst = 0.0;
    double totalSgst = 0.0;
    double totalIgst = 0.0;
    final hsnSummary = <HsnTaxBreakdown>[];

    for (final entry in hsnMap.entries) {
      final code = entry.key;
      final lines = entry.value;
      final hsnTaxable = lines.fold<double>(0.0, (sum, l) => sum + l.taxableAmount);
      final rate = lines.first.taxRatePercent;
      final hsnCgst = lines.fold<double>(0.0, (sum, l) => sum + l.cgstAmount);
      final hsnSgst = lines.fold<double>(0.0, (sum, l) => sum + l.sgstAmount);
      final hsnIgst = lines.fold<double>(0.0, (sum, l) => sum + l.igstAmount);
      final hsnTotalTax = hsnCgst + hsnSgst + hsnIgst;

      totalCgst += hsnCgst;
      totalSgst += hsnSgst;
      totalIgst += hsnIgst;

      hsnSummary.add(HsnTaxBreakdown(
        hsnCode: code,
        taxableValue: hsnTaxable,
        taxRatePercent: rate,
        cgstAmount: hsnCgst,
        sgstAmount: hsnSgst,
        igstAmount: hsnIgst,
        totalTax: hsnTotalTax,
      ));
    }

    final totalTax = totalCgst + totalSgst + totalIgst;

    // 9. TCS Section 206C(1H)
    double tcsAmount = 0.0;
    if (applyTcs) {
      tcsAmount = ((netTaxable + totalTax) * tcsRatePercent) / 100.0;
    }

    // 10. Grand total & Rounding adjustment
    final rawGrandTotal = netTaxable + totalTax + movCharge + crateDeposit + tcsAmount;
    final roundedGrandTotal = rawGrandTotal.roundToDouble();
    final roundingAdjustment = double.parse((roundedGrandTotal - rawGrandTotal).toStringAsFixed(2));

    return BillCalculationResult(
      lines: billedLines,
      grossSubtotal: double.parse(runningGross.toStringAsFixed(2)),
      volumeDiscountTotal: double.parse(runningVolumeDiscount.toStringAsFixed(2)),
      cashDiscountTotal: double.parse(cashDiscountAmount.toStringAsFixed(2)),
      promotionalDiscountTotal: 0.0,
      totalDiscounts: double.parse((runningVolumeDiscount + cashDiscountAmount).toStringAsFixed(2)),
      movSurcharge: movCharge,
      crateDepositTotal: crateDeposit,
      netTaxableSubtotal: double.parse(netTaxable.toStringAsFixed(2)),
      cgstTotal: double.parse(totalCgst.toStringAsFixed(2)),
      sgstTotal: double.parse(totalSgst.toStringAsFixed(2)),
      igstTotal: double.parse(totalIgst.toStringAsFixed(2)),
      totalTax: double.parse(totalTax.toStringAsFixed(2)),
      hsnSummary: hsnSummary,
      tcsAmount: double.parse(tcsAmount.toStringAsFixed(2)),
      roundingAdjustment: roundingAdjustment,
      grandTotal: roundedGrandTotal,
      currency: currency,
      fxRateToInr: fxRateToInr,
    );
  }

  /// FIFO payment settlement algorithm across unpaid/partially-paid invoices
  List<InvoicePaymentAllocation> allocatePaymentFifo({
    required double paymentAmount,
    required List<Invoice> unpaidInvoices,
  }) {
    final allocations = <InvoicePaymentAllocation>[];
    double unallocatedCash = paymentAmount;

    // Sort by invoiceDate or dueDate ascending (FIFO)
    final sortedInvoices = List<Invoice>.from(unpaidInvoices)
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    for (final inv in sortedInvoices) {
      if (unallocatedCash <= 0) break;
      if (inv.pendingAmount <= 0) continue;

      final allocation = math.min(unallocatedCash, inv.pendingAmount);
      final remainingPending = inv.pendingAmount - allocation;
      unallocatedCash -= allocation;

      allocations.add(InvoicePaymentAllocation(
        invoiceId: inv.id,
        invoiceNumber: inv.invoiceNumber,
        originalPendingAmount: inv.pendingAmount,
        allocatedAmount: double.parse(allocation.toStringAsFixed(2)),
        remainingPendingAmount: double.parse(remainingPending.toStringAsFixed(2)),
        isFullyPaid: remainingPending <= 0.01,
      ));
    }

    return allocations;
  }

  /// Calculates overdue commercial interest (default 18% p.a. pro-rata beyond 30 days)
  double computeOverdueInterest({
    required double pendingAmount,
    required DateTime dueDate,
    required DateTime currentDate,
    double annualInterestRate = 18.0,
    int gracePeriodDays = 0,
  }) {
    if (pendingAmount <= 0) return 0.0;
    final overdueDays = currentDate.difference(dueDate).inDays - gracePeriodDays;
    if (overdueDays <= 0) return 0.0;

    final dailyRate = (annualInterestRate / 100.0) / 365.0;
    final interest = pendingAmount * dailyRate * overdueDays;
    return double.parse(interest.toStringAsFixed(2));
  }

  double _resolveGstRate(Product product) {
    if (product.taxCategory.toUpperCase() == 'EXEMPT' || product.taxCategory.toUpperCase() == 'NONE') {
      return 0.0;
    }
    if (product.taxCategory.toUpperCase() == 'GST_5') return 5.0;
    if (product.taxCategory.toUpperCase() == 'GST_12') return 12.0;
    if (product.taxCategory.toUpperCase() == 'GST_18') return 18.0;

    // Frozen parota/chapathi without brand = 5% or 18% depending on classification
    if (product.storageType == 'frozen') {
      return 5.0; // 5% GST on preserved flatbreads
    }
    return 0.0; // fresh flatbreads exempt
  }
}
