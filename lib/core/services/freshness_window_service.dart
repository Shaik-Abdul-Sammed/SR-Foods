import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../domain/money.dart';
import '../i18n/locale_context.dart';

class DayOldPricingResult {
  final Money finalPrice;
  final bool isDayOldDiscountApplied;
  final double discountPercent;
  final DateTime freshnessUntil;
  final int hoursPastFreshness;

  const DayOldPricingResult({
    required this.finalPrice,
    required this.isDayOldDiscountApplied,
    required this.discountPercent,
    required this.freshnessUntil,
    required this.hoursPastFreshness,
  });
}

class StaleBatchAlert {
  final int batchId;
  final String batchNumber;
  final int productId;
  final DateTime bakedAt;
  final DateTime freshnessUntil;
  final int hoursPastFreshness;
  final double suggestedDiscountPercent;

  const StaleBatchAlert({
    required this.batchId,
    required this.batchNumber,
    required this.productId,
    required this.bakedAt,
    required this.freshnessUntil,
    required this.hoursPastFreshness,
    required this.suggestedDiscountPercent,
  });
}

/// Service managing fresh bakery shelf life, freshness windows, and automatic day-old markdowns
class FreshnessWindowService {
  const FreshnessWindowService();

  /// Computes the exact timestamp when a fresh baked batch leaves its prime freshness window
  DateTime computeFreshnessUntil(DateTime bakedAt, int freshnessWindowHours) {
    return bakedAt.add(Duration(hours: freshnessWindowHours));
  }

  /// Calculates dynamic product price applying markdown if current time is past prime freshness
  DayOldPricingResult applyDayOldPricing({
    required double basePrice,
    required DateTime bakedAt,
    required int freshnessWindowHours,
    double dayOldDiscountPercent = 25.0,
    DateTime? now,
    Currency currency = Currency.inr,
  }) {
    final currentTime = now ?? DateTime.now();
    final freshnessUntil = computeFreshnessUntil(bakedAt, freshnessWindowHours);
    final isStale = currentTime.isAfter(freshnessUntil);

    if (isStale) {
      final hoursPast = currentTime.difference(freshnessUntil).inHours;
      final discountFactor = (100.0 - dayOldDiscountPercent) / 100.0;
      final discountedMinor = (Money.fromRupees(basePrice, currency: currency).amountMinor * discountFactor).round();

      return DayOldPricingResult(
        finalPrice: Money(amountMinor: discountedMinor, currency: currency),
        isDayOldDiscountApplied: true,
        discountPercent: dayOldDiscountPercent,
        freshnessUntil: freshnessUntil,
        hoursPastFreshness: hoursPast,
      );
    }

    return DayOldPricingResult(
      finalPrice: Money.fromRupees(basePrice, currency: currency),
      isDayOldDiscountApplied: false,
      discountPercent: 0.0,
      freshnessUntil: freshnessUntil,
      hoursPastFreshness: 0,
    );
  }

  /// Scans database for bakery batches that have crossed their freshness window and require liquidation
  Future<List<StaleBatchAlert>> flagStaleBatches({
    required AppDatabase db,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();

    final staleBatches = await (db.select(db.productionBatches)
          ..where((tbl) =>
              tbl.freshnessUntil.isNotNull() &
              tbl.freshnessUntil.isSmallerThanValue(currentTime) &
              tbl.status.equals('completed')))
        .get();

    final alerts = <StaleBatchAlert>[];
    for (final batch in staleBatches) {
      final baked = batch.bakedAt ?? currentTime.subtract(const Duration(hours: 24));
      final freshUntil = batch.freshnessUntil!;
      final hoursPast = currentTime.difference(freshUntil).inHours;

      double discount = 25.0;
      if (hoursPast > 24) discount = 50.0;
      if (hoursPast > 48) discount = 70.0;

      alerts.add(
        StaleBatchAlert(
          batchId: batch.id,
          batchNumber: batch.batchNumber,
          productId: batch.productId,
          bakedAt: baked,
          freshnessUntil: freshUntil,
          hoursPastFreshness: hoursPast,
          suggestedDiscountPercent: discount,
        ),
      );
    }

    return alerts;
  }
}
