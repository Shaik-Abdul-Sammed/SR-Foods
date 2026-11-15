import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';
import 'package:sr_foods/core/services/dairy_pricing_service.dart';

void main() {
  group('DairyPricingService Unit Tests', () {
    const service = DairyPricingService();

    test('1. Standard Cow Milk at base fat (3.5%) produces exact base rate (₹38.00/L)', () {
      final price = service.calculateMilkPrice(
        liters: 100.0,
        fatPercent: 3.5,
        rule: FatPricingRuleData.standardCow,
      );
      // 100L * ₹38.00 = ₹3,800.00 = 380,000 paise
      expect(price.amountMinor, equals(380000));
      expect(price.currency, equals(Currency.inr));
    });

    test('2. Standard Cow Milk with higher fat (4.0% = +5 slabs of 0.1%) earns ₹1.50/L bonus', () {
      // Base: ₹38.00 + (5 * ₹0.30) = ₹39.50/L
      // 50L * ₹39.50 = ₹1,975.00 = 197,500 paise
      final price = service.calculateMilkPrice(
        liters: 50.0,
        fatPercent: 4.0,
        rule: FatPricingRuleData.standardCow,
      );
      expect(price.amountMinor, equals(197500));
    });

    test('3. Premium Buffalo Milk at base fat (6.0%) produces exact base rate (₹58.00/L)', () {
      // 200L * ₹58.00 = ₹11,600.00 = 1,160,000 paise
      final price = service.calculateMilkPrice(
        liters: 200.0,
        fatPercent: 6.0,
        rule: FatPricingRuleData.premiumBuffalo,
      );
      expect(price.amountMinor, equals(1160000));
    });

    test('4. Premium Buffalo Milk with high fat (7.0% = +10 slabs of 0.1%) earns ₹4.00/L bonus', () {
      // Base: ₹58.00 + (10 * ₹0.40) = ₹62.00/L
      // 100L * ₹62.00 = ₹6,200.00 = 620,000 paise
      final price = service.calculateMilkPrice(
        liters: 100.0,
        fatPercent: 7.0,
        rule: FatPricingRuleData.premiumBuffalo,
      );
      expect(price.amountMinor, equals(620000));
    });

    test('5. Low fat rate floor at 50% base rate prevents predatory zero/negative pricing', () {
      // Fat = 0.5% (delta = -3.0%, 30 steps below base of 38.00)
      // Unbounded: 38.00 - (30 * 0.30) = 38.00 - 9.00 = 29.00
      // Extreme test: Fat = 0.0% -> 38.00 - 10.50 = 27.50
      // Floor is baseRate / 2 = 19.00
      final price = service.calculateMilkPrice(
        liters: 10.0,
        fatPercent: 0.0,
        rule: const FatPricingRuleData(
          name: 'Aggressive Penalty Rule',
          baseRatePerLiterMinor: 2000,
          baseFatPercent: 4.0,
          fatSlabStep: 0.1,
          priceStepPerLiterMinor: 100, // Large penalty
        ),
      );
      // Floor is 2000 / 2 = 1000 minor per liter. For 10L = 10,000 paise
      expect(price.amountMinor, equals(10000));
    });

    test('6. Zero or negative liters safely returns Money.zero', () {
      final zeroLiters = service.calculateMilkPrice(
        liters: 0.0,
        fatPercent: 4.5,
        rule: FatPricingRuleData.standardCow,
      );
      expect(zeroLiters.amountMinor, equals(0));

      final negativeLiters = service.calculateMilkPrice(
        liters: -25.0,
        fatPercent: 4.5,
        rule: FatPricingRuleData.standardCow,
      );
      expect(negativeLiters.amountMinor, equals(0));
    });

    test('7. computeFatYield calculates ratio and guards division by zero', () {
      // Normal: expected 4.0%, actual 4.2% -> 105.0%
      final yieldNormal = service.computeFatYield(
        expectedFat: 4.0,
        actualFat: 4.2,
        liters: 100,
      );
      expect(yieldNormal, equals(105.0));

      // Guard zero expected
      expect(service.computeFatYield(expectedFat: 0.0, actualFat: 4.0, liters: 100), equals(0.0));
      // Guard zero liters
      expect(service.computeFatYield(expectedFat: 4.0, actualFat: 4.0, liters: 0), equals(0.0));
    });

    test('8. suggestProcurementPrice auto-selects Cow vs Buffalo based on 5.0% threshold', () {
      // < 5.0% should select Cow Milk Rule
      final cowSuggest = service.suggestProcurementPrice(
        supplierId: 'FARMER-01',
        historicalAvgFat: 3.8,
      );
      // 3.8% is +3 steps on Cow rule (38.00 + 0.90 = ₹38.90 = 3890 paise)
      expect(cowSuggest.amountMinor, equals(3890));

      // >= 5.0% should select Buffalo Milk Rule
      final buffaloSuggest = service.suggestProcurementPrice(
        supplierId: 'FARMER-02',
        historicalAvgFat: 6.5,
      );
      // 6.5% is +5 steps on Buffalo rule (58.00 + 2.00 = ₹60.00 = 6000 paise)
      expect(buffaloSuggest.amountMinor, equals(6000));
    });

    test('9. Custom currency support converts minor units to target currency', () {
      final priceAed = service.calculateMilkPrice(
        liters: 10.0,
        fatPercent: 3.5,
        rule: FatPricingRuleData.standardCow,
        currency: Currency.aed,
      );
      expect(priceAed.currency, equals(Currency.aed));
      expect(priceAed.amountMinor, equals(38000));
    });
  });
}
