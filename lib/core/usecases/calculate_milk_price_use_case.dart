import '../domain/money.dart';
import '../i18n/locale_context.dart';
import '../patterns/result.dart';
import '../patterns/use_case.dart';
import '../services/dairy_pricing_service.dart';

class MilkPricingParams {
  final double fatPercent;
  final double snfPercent;
  final double quantityLiters;
  final FatPricingRuleData? rule;
  final Currency currency;

  const MilkPricingParams({
    required this.fatPercent,
    required this.snfPercent,
    required this.quantityLiters,
    this.rule,
    this.currency = Currency.inr,
  });
}

class CalculateMilkPriceUseCase implements SyncUseCase<MilkPricingParams, Money> {
  final DairyPricingService service;

  const CalculateMilkPriceUseCase({this.service = const DairyPricingService()});

  @override
  Result<Money, Object> call(MilkPricingParams params) {
    if (params.quantityLiters < 0) {
      return Result.err(ArgumentError('Milk quantity cannot be negative: ${params.quantityLiters}'));
    }
    if (params.fatPercent < 0 || params.fatPercent > 15.0) {
      return Result.err(ArgumentError('Fat percentage must be between 0.0 and 15.0: ${params.fatPercent}'));
    }
    if (params.snfPercent < 0 || params.snfPercent > 15.0) {
      return Result.err(ArgumentError('SNF percentage must be between 0.0 and 15.0: ${params.snfPercent}'));
    }

    try {
      final rule = params.rule ??
          (params.fatPercent >= 5.0
              ? FatPricingRuleData.premiumBuffalo
              : FatPricingRuleData.standardCow);

      final price = service.calculateMilkPrice(
        liters: params.quantityLiters,
        fatPercent: params.fatPercent,
        rule: rule,
        currency: params.currency,
      );
      return Result.ok(price);
    } catch (e) {
      return Result.err(e);
    }
  }
}
