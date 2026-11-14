import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';
import 'package:sr_foods/core/services/transfer_pricing_engine.dart';

void main() {
  const engine = TransferPricingEngine();

  group('Transfer Pricing Engine & Multi-Entity P&L Tests', () {
    test('1. India -> UAE Transfer Pricing (15% markup + export handling fees)', () {
      // 500 cartons of Parota, 24 packs/carton = 12,000 packs
      // Base factory manufacturing cost: ₹30.00 / pack = 3,000 paise
      // Total Base COGS: 12,000 * ₹30 = ₹3,60,000.00 (36,000,000 paise)
      // 15% Cost-plus markup: ₹3,60,000 * 0.15 = ₹54,000.00 (5,400,000 paise)
      // Handling fees: (500 * ₹25 = ₹12,500) + ₹1,500 doc fee = ₹14,000.00 (1,400,000 paise)
      // Total Transfer Price Source: 3,60,000 + 54,000 + 14,000 = ₹4,28,000.00 (42,800,000 paise)
      // FX Rate: 1 INR = 0.044 AED (or 1/22.73)
      final input = TransferOrderInput(
        sourceEntityId: 1,
        sourceEntityName: 'SR Foods India Pvt Ltd',
        destinationEntityId: 2,
        destinationEntityName: 'SR Foods Middle East FZE (Dubai)',
        sourceCurrency: Currency.inr,
        destinationCurrency: Currency.aed,
        fxRateSourceToDest: 0.044, // 1 INR = 0.044 AED
        sku: 'PAROTA-FRZ-EXP',
        productName: 'Frozen Malabar Parota',
        cartonCount: 500,
        unitsPerCarton: 24,
        baseFactoryCostMinor: 3000, // ₹30.00
      );

      final result = engine.calculateTransferPrice(
        input,
        rule: const TransferPricingRule(
          markupPercentage: 15.0,
          exportHandlingFeePerCartonMinor: 2500,
          documentationFeeMinor: 150000,
        ),
        timestamp: DateTime(2026, 11, 14, 10, 0, 0),
      );

      expect(result.baseCostTotalSource.paise, 36000000);
      expect(result.markupAmountSource.paise, 5400000);
      expect(result.handlingFeesSource.paise, 1400000);
      expect(result.transferPriceTotalSource.paise, 42800000);
      expect(result.transferPriceTotalSource.inRupees, 428000.0);

      // Per carton source: 42,800,000 / 500 = 85,600 paise = ₹856.00
      expect(result.transferPricePerCartonSource.inRupees, 856.0);

      // Per pack source: 42,800,000 / 12,000 = 3,567 paise = ₹35.67
      expect(result.transferPricePerPackSource.inRupees, closeTo(35.67, 0.01));

      // Destination currency (AED): ₹428,000 * 0.044 = 18,832.00 AED
      expect(result.transferPriceTotalDest.currency, Currency.aed);
      expect(result.transferPriceTotalDest.inMajor, closeTo(18832.0, 0.5));

      // Per carton AED: 18,832 / 500 = 37.66 AED
      expect(result.transferPricePerCartonDest.inMajor, closeTo(37.66, 0.1));

      // Challan verification
      expect(result.challanNumber, contains('DC-TRF-1-2-'));
    });

    test('2. Multi-Entity P&L: India Manufacturing Entity (INR)', () {
      // Gross Revenue: ₹50,00,000.00
      // COGS (Factory Flour, Oil, Wages): ₹32,00,000.00
      // Gross Profit: ₹18,00,000.00 (36% margin)
      // Opex: ₹6,00,000.00
      // Net Profit: ₹12,00,000.00 (24% margin)
      final pnl = engine.computeEntityPnl(
        entityId: 1,
        entityName: 'SR Foods India Pvt Ltd',
        currency: Currency.inr,
        grossRevenue: Money.fromRupees(5000000.0),
        cogs: Money.fromRupees(3200000.0),
        operatingExpenses: Money.fromRupees(600000.0),
      );

      expect(pnl.grossProfit.inRupees, 1800000.0);
      expect(pnl.netOperatingProfit.inRupees, 1200000.0);
      expect(pnl.grossMarginPercent, 36.0);
      expect(pnl.netMarginPercent, 24.0);
    });

    test('3. Multi-Entity P&L: UAE Distribution Entity (AED)', () {
      // Gross Wholesale Revenue in UAE: 300,000.00 AED
      // COGS (Inter-company transfer import price): 180,000.00 AED
      // Gross Profit: 120,000.00 AED (40% margin)
      // Local Warehousing & Cold-van Logistics: 45,000.00 AED
      // Net Operating Profit: 75,000.00 AED (25% margin)
      final pnl = engine.computeEntityPnl(
        entityId: 2,
        entityName: 'SR Foods Middle East FZE',
        currency: Currency.aed,
        grossRevenue: Money.fromMajor(300000.0, currency: Currency.aed),
        cogs: Money.fromMajor(180000.0, currency: Currency.aed),
        operatingExpenses: Money.fromMajor(45000.0, currency: Currency.aed),
      );

      expect(pnl.grossProfit.inMajor, 120000.0);
      expect(pnl.netOperatingProfit.inMajor, 75000.0);
      expect(pnl.grossMarginPercent, 40.0);
      expect(pnl.netMarginPercent, 25.0);
    });

    test('4. Currency mismatch in Entity P&L throws ArgumentError', () {
      expect(
        () => engine.computeEntityPnl(
          entityId: 1,
          entityName: 'SR Foods India',
          currency: Currency.inr,
          grossRevenue: Money.fromMajor(10000.0, currency: Currency.usd), // USD mismatch!
          cogs: Money.fromRupees(5000.0),
          operatingExpenses: Money.fromRupees(1000.0),
        ),
        throwsArgumentError,
      );
    });
  });
}
