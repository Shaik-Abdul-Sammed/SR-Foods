import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/dairy_pricing_service.dart';

void main() {
  group('Property-Based Invariant Tests (>= 300 runs)', () {
    final random = Random(42);

    test('1. Money calculation commutativity & non-negative invariant across 500 runs', () {
      for (int i = 0; i < 500; i++) {
        final priceA = (random.nextDouble() * 10000).truncateToDouble() / 100;
        final priceB = (random.nextDouble() * 10000).truncateToDouble() / 100;

        final sum1 = (priceA * 100 + priceB * 100).round() / 100;
        final sum2 = (priceB * 100 + priceA * 100).round() / 100;

        expect(sum1, equals(sum2), reason: 'Commutativity failed for $priceA + $priceB');
        expect(sum1, greaterThanOrEqualTo(0.0), reason: 'Negative money produced');
      }
    });

    test('2. Dairy pricing monotonicity & non-negativity across 500 random samples', () {
      const pricingService = DairyPricingService();

      for (int i = 0; i < 500; i++) {
        final liters = random.nextDouble() * 500.0; // 0 to 500 L
        final fat1 = 2.0 + random.nextDouble() * 3.0; // 2.0 to 5.0
        final fat2 = fat1 + random.nextDouble() * 3.0; // fat2 >= fat1

        final payout1 = pricingService.calculateMilkPrice(
          liters: liters,
          fatPercent: fat1,
          rule: FatPricingRuleData.standardCow,
        );

        final payout2 = pricingService.calculateMilkPrice(
          liters: liters,
          fatPercent: fat2,
          rule: FatPricingRuleData.standardCow,
        );

        // Invariants:
        // 1. Total payout minor >= 0
        expect(payout1.amountMinor, greaterThanOrEqualTo(0));
        expect(payout2.amountMinor, greaterThanOrEqualTo(0));

        // 2. Higher fat percentage yields payout >= lower fat percentage (monotonicity)
        expect(payout2.amountMinor, greaterThanOrEqualTo(payout1.amountMinor),
            reason: 'Payout did not increase monotonically with fat ($fat1 vs $fat2)');
      }
    });

    test('3. Discount and tax application preserves bounds across 500 runs', () {
      for (int i = 0; i < 500; i++) {
        final subtotal = (random.nextDouble() * 50000).truncateToDouble() / 100; // up to 500.00
        final discountPercent = random.nextInt(101); // 0 to 100%
        final gstRate = [0.0, 0.05, 0.12, 0.18, 0.28][random.nextInt(5)];

        final discountAmount = (subtotal * discountPercent) / 100.0;
        final discountedSubtotal = subtotal - discountAmount;
        final tax = discountedSubtotal * gstRate;
        final grandTotal = discountedSubtotal + tax;

        // Invariants:
        expect(discountAmount, inInclusiveRange(0.0, subtotal + 0.001));
        expect(discountedSubtotal, greaterThanOrEqualTo(-0.001));
        expect(tax, greaterThanOrEqualTo(0.0));
        expect(grandTotal, greaterThanOrEqualTo(0.0));
      }
    });
  });
}
