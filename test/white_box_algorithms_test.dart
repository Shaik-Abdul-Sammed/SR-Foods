import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/ai_expert_engine.dart';
import 'package:sr_foods/core/services/yield_analytics_service.dart';
import 'package:sr_foods/core/domain/recipe.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/domain/quantity.dart';

void main() {
  group('White Box Tests: AiExpertEngine Algorithmic Branch Coverage', () {
    test('Weekly Seasonality Multipliers covers all 7 weekdays branches', () {
      // Monday = 0.95
      expect(AiExpertEngine.getWeeklySeasonalityMultiplier(DateTime(2026, 11, 9)), 0.95);
      // Tuesday = 0.85 (fasting dip)
      expect(AiExpertEngine.getWeeklySeasonalityMultiplier(DateTime(2026, 11, 10)), 0.85);
      // Wednesday = 1.00
      expect(AiExpertEngine.getWeeklySeasonalityMultiplier(DateTime(2026, 11, 11)), 1.00);
      // Thursday = 0.95
      expect(AiExpertEngine.getWeeklySeasonalityMultiplier(DateTime(2026, 11, 12)), 0.95);
      // Friday = 1.30 (weekend pre-stock)
      expect(AiExpertEngine.getWeeklySeasonalityMultiplier(DateTime(2026, 11, 13)), 1.30);
      // Saturday = 1.45 (peak weekend consumption)
      expect(AiExpertEngine.getWeeklySeasonalityMultiplier(DateTime(2026, 11, 14)), 1.45);
      // Sunday = 1.35 (hotel morning breakfast)
      expect(AiExpertEngine.getWeeklySeasonalityMultiplier(DateTime(2026, 11, 15)), 1.35);
    });

    test('Indian Festival Uplift branch testing across date ranges', () {
      // Pongal / Sankranti (Jan 14)
      final pongal = AiExpertEngine.getFestivalUplift(DateTime(2026, 1, 14));
      expect(pongal.isFestivalActive, isTrue);
      expect(pongal.upliftMultiplier, 1.40);
      expect(pongal.festivalName, contains('Pongal'));

      // Ugadi / Ramadan (March 25)
      final ugadi = AiExpertEngine.getFestivalUplift(DateTime(2026, 3, 25));
      expect(ugadi.isFestivalActive, isTrue);
      expect(ugadi.upliftMultiplier, 1.50);

      // Diwali Season (Nov 5)
      final diwali = AiExpertEngine.getFestivalUplift(DateTime(2026, 11, 5));
      expect(diwali.isFestivalActive, isTrue);
      expect(diwali.upliftMultiplier, 1.45);

      // New Year (Dec 31)
      final newYear = AiExpertEngine.getFestivalUplift(DateTime(2026, 12, 31));
      expect(newYear.isFestivalActive, isTrue);
      expect(newYear.upliftMultiplier, 1.50);

      // Regular Season (August 10)
      final regular = AiExpertEngine.getFestivalUplift(DateTime(2026, 8, 10));
      expect(regular.isFestivalActive, isFalse);
      expect(regular.upliftMultiplier, 1.00);
    });
  });

  group('White Box Tests: Yield & Wastage Analytics Decision Paths', () {
    final recipe = StandardRecipes.parotaRecipe;

    test('Optimal Yield Branch (normal production run)', () {
      // 100 packs produced with 55 kg flour = exactly 98% yield
      final result = YieldAnalyticsService.instance.analyzeBatchYield(
        recipe: recipe,
        actualPacksProduced: 98,
        actualFlourKgConsumed: 55.0,
      );
      expect(result.status, 'optimal');
      expect(result.isSevereDeviation, isFalse);
      expect(result.diagnosticAdvice, contains('Optimal factory yield'));
    });

    test('Critical Deficit Branch (variance < -3% triggers dough moisture / roll-trim alert)', () {
      // Only 85 packs produced from 55 kg flour (severe loss)
      final result = YieldAnalyticsService.instance.analyzeBatchYield(
        recipe: recipe,
        actualPacksProduced: 85,
        actualFlourKgConsumed: 55.0,
      );
      expect(result.status, 'critical_variance');
      expect(result.isSevereDeviation, isTrue);
      expect(result.diagnosticAdvice, contains('CRITICAL YIELD DEFICIT'));
      expect(result.estimatedWastageKg, greaterThan(5.0));
      expect(result.estimatedLossRupees, greaterThan(200.0));
    });

    test('Critical Positive Deviation Branch (variance > +3% triggers underweight warning)', () {
      // 110 packs produced from 55 kg flour (pieces must be underweight)
      final result = YieldAnalyticsService.instance.analyzeBatchYield(
        recipe: recipe,
        actualPacksProduced: 110,
        actualFlourKgConsumed: 55.0,
      );
      expect(result.status, 'critical_variance');
      expect(result.isSevereDeviation, isTrue);
      expect(result.diagnosticAdvice, contains('ABNORMAL POSITIVE DEVIATION'));
      expect(result.diagnosticAdvice, contains('Underweight pieces'));
    });
  });

  group('White Box Tests: Money Value Object Precision & Division', () {
    test('Multiplication with fractional factor preserves integer truncation/rounding', () {
      final m = Money.fromRupees(150.75); // 15075 paise
      final half = m * 0.5;
      expect(half.paise, 7538); // 15075 * 0.5 = 7537.5 -> rounded to 7538
    });

    test('Division by zero throws ArgumentError', () {
      final m = Money.fromRupees(100);
      expect(() => m / 0, throwsArgumentError);
    });

    test('Negative paise arithmetic', () {
      final m1 = Money.fromRupees(50);
      final m2 = Money.fromRupees(120);
      final diff = m1 - m2;
      expect(diff.paise, -7000);
      expect(diff.inRupees, -70.0);
    });
  });

  group('White Box Tests: Quantity Conversion Matrix', () {
    test('Exact gram to kg boundary conversions', () {
      final q1 = const Quantity(500, ProductUnit.g);
      expect(q1.convertTo(ProductUnit.kg).amount, 0.5);

      final q2 = const Quantity(2.5, ProductUnit.kg);
      expect(q2.convertTo(ProductUnit.g).amount, 2500);
    });

    test('Exact milliliter to liter boundary conversions', () {
      final q1 = const Quantity(750, ProductUnit.ml);
      expect(q1.convertTo(ProductUnit.liter).amount, 0.75);

      final q2 = const Quantity(4.0, ProductUnit.liter);
      expect(q2.convertTo(ProductUnit.ml).amount, 4000);
    });
  });
}
