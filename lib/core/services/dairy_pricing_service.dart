import '../domain/money.dart';
import '../i18n/locale_context.dart';

/// Rule parameters for fat-based milk payment
class FatPricingRuleData {
  final int id;
  final String name;
  final int baseRatePerLiterMinor;
  final double baseFatPercent;
  final double fatSlabStep; // e.g. 0.1%
  final int priceStepPerLiterMinor; // e.g. 30 paise per 0.1% step
  final bool isActive;

  const FatPricingRuleData({
    this.id = 1,
    required this.name,
    required this.baseRatePerLiterMinor,
    required this.baseFatPercent,
    this.fatSlabStep = 0.1,
    this.priceStepPerLiterMinor = 30,
    this.isActive = true,
  });

  static const standardCow = FatPricingRuleData(
    id: 1,
    name: 'Standard Cow Milk Rule',
    baseRatePerLiterMinor: 3800, // ₹38.00 / L
    baseFatPercent: 3.5,
    fatSlabStep: 0.1,
    priceStepPerLiterMinor: 30, // ₹0.30 per 0.1% step
  );

  static const premiumBuffalo = FatPricingRuleData(
    id: 2,
    name: 'Premium Buffalo Milk Rule',
    baseRatePerLiterMinor: 5800, // ₹58.00 / L
    baseFatPercent: 6.0,
    fatSlabStep: 0.1,
    priceStepPerLiterMinor: 40, // ₹0.40 per 0.1% step
  );
}

/// Service providing fat-based pricing, yield analytics, and procurement recommendations
class DairyPricingService {
  const DairyPricingService();

  /// Calculates total milk price based on volume, fat test %, and slab pricing rule
  Money calculateMilkPrice({
    required double liters,
    required double fatPercent,
    required FatPricingRuleData rule,
    Currency currency = Currency.inr,
  }) {
    if (liters <= 0) return Money.zero;

    // Calculate slab step delta from base fat
    final fatDiff = fatPercent - rule.baseFatPercent;
    // Number of 0.1% steps (positive or negative)
    final stepCount = (fatDiff / rule.fatSlabStep).round();

    final ratePerLiterMinor = rule.baseRatePerLiterMinor + (stepCount * rule.priceStepPerLiterMinor);
    // Floor rate at 50% of base rate to prevent negative or predatory rates
    final finalRateMinor = ratePerLiterMinor < (rule.baseRatePerLiterMinor ~/ 2)
        ? (rule.baseRatePerLiterMinor ~/ 2)
        : ratePerLiterMinor;

    final totalMinor = (finalRateMinor * liters).round();

    return Money(
      amountMinor: totalMinor,
      currency: currency,
    );
  }

  /// Calculates fat yield percentage comparing expected fat output to actual fat output
  double computeFatYield({
    required double expectedFat,
    required double actualFat,
    required double liters,
  }) {
    if (expectedFat <= 0 || liters <= 0) return 0.0;
    final yieldPct = (actualFat / expectedFat) * 100.0;
    return double.parse(yieldPct.toStringAsFixed(2));
  }

  /// Recommends a procurement price for a supplier based on their historical fat average
  Money suggestProcurementPrice({
    required String supplierId,
    required double historicalAvgFat,
    FatPricingRuleData? rule,
    Currency currency = Currency.inr,
  }) {
    final activeRule = rule ?? (historicalAvgFat >= 5.0 ? FatPricingRuleData.premiumBuffalo : FatPricingRuleData.standardCow);
    return calculateMilkPrice(
      liters: 1.0,
      fatPercent: historicalAvgFat,
      rule: activeRule,
      currency: currency,
    );
  }
}
