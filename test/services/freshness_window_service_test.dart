import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/freshness_window_service.dart';

void main() {
  late AppDatabase db;
  late FreshnessWindowService freshnessService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    freshnessService = const FreshnessWindowService();
  });

  tearDown(() async {
    await db.close();
  });

  group('FreshnessWindowService', () {
    test('computeFreshnessUntil correctly adds freshness hours to bakedAt', () {
      final baked = DateTime(2026, 11, 20, 6, 0);
      final until = freshnessService.computeFreshnessUntil(baked, 36);
      expect(until, equals(DateTime(2026, 11, 21, 18, 0)));
    });

    test('applyDayOldPricing returns base price with 0% discount when fresh', () {
      final baked = DateTime(2026, 11, 20, 6, 0);
      final checkTime = DateTime(2026, 11, 20, 18, 0); // 12 hours later (within 36h window)

      final result = freshnessService.applyDayOldPricing(
        basePrice: 80.0,
        bakedAt: baked,
        freshnessWindowHours: 36,
        now: checkTime,
      );

      expect(result.isDayOldDiscountApplied, isFalse);
      expect(result.discountPercent, equals(0.0));
      expect(result.hoursPastFreshness, equals(0));
      expect(result.finalPrice.amountMinor, equals(8000));
    });

    test('applyDayOldPricing applies 25% discount when past freshness window', () {
      final baked = DateTime(2026, 11, 20, 6, 0);
      // Window expires at 2026-11-21 18:00. Check at 2026-11-22 00:00 (6 hours past)
      final checkTime = DateTime(2026, 11, 22, 0, 0);

      final result = freshnessService.applyDayOldPricing(
        basePrice: 100.0,
        bakedAt: baked,
        freshnessWindowHours: 36,
        now: checkTime,
      );

      expect(result.isDayOldDiscountApplied, isTrue);
      expect(result.discountPercent, equals(25.0));
      expect(result.hoursPastFreshness, equals(6));
      expect(result.finalPrice.amountMinor, equals(7500)); // Rs 75.00
    });

    test('applyDayOldPricing supports custom markdown percentage', () {
      final baked = DateTime(2026, 11, 20, 6, 0);
      final checkTime = DateTime(2026, 11, 21, 20, 0); // 2 hours past freshness

      final result = freshnessService.applyDayOldPricing(
        basePrice: 200.0,
        bakedAt: baked,
        freshnessWindowHours: 12,
        dayOldDiscountPercent: 40.0,
        now: checkTime,
      );

      expect(result.isDayOldDiscountApplied, isTrue);
      expect(result.discountPercent, equals(40.0));
      expect(result.finalPrice.amountMinor, equals(12000)); // Rs 120.00
    });

    test('flagStaleBatches flags completed stale batches and ignores fresh ones', () async {
      final now = DateTime(2026, 11, 20, 12, 0);

      // Batch 1: Stale (freshness until 4 hours ago, status 'completed')
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'STALE-01',
          productId: 141,
          quantityProduced: 50,
          operatorName: 'Baker A',
          manufacturingDate: now,
          bakedAt: Value(now.subtract(const Duration(hours: 28))),
          freshnessUntil: Value(now.subtract(const Duration(hours: 4))),
          status: const Value('completed'),
        ),
      );

      // Batch 2: Fresh (freshness until tomorrow, status 'completed')
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'FRESH-02',
          productId: 142,
          quantityProduced: 50,
          operatorName: 'Baker B',
          manufacturingDate: now,
          bakedAt: Value(now),
          freshnessUntil: Value(now.add(const Duration(hours: 24))),
          status: const Value('completed'),
        ),
      );

      // Batch 3: Stale time, but status 'planned' (should NOT flag)
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'PLANNED-03',
          productId: 143,
          quantityProduced: 50,
          operatorName: 'Baker C',
          manufacturingDate: now,
          bakedAt: Value(now.subtract(const Duration(hours: 30))),
          freshnessUntil: Value(now.subtract(const Duration(hours: 6))),
          status: const Value('planned'),
        ),
      );

      final alerts = await freshnessService.flagStaleBatches(db: db, now: now);

      expect(alerts.length, equals(1));
      expect(alerts.first.batchNumber, equals('STALE-01'));
      expect(alerts.first.hoursPastFreshness, equals(4));
      expect(alerts.first.suggestedDiscountPercent, equals(25.0));
    });

    test('flagStaleBatches applies progressive markdown tiers (25%, 50%, 70%)', () async {
      final now = DateTime(2026, 11, 20, 12, 0);

      // Tier 1: <= 24h past freshness -> 25% discount
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'TIER-1',
          productId: 141,
          quantityProduced: 10,
          operatorName: 'Baker 1',
          manufacturingDate: now,
          bakedAt: Value(now),
          freshnessUntil: Value(now.subtract(const Duration(hours: 10))),
          status: const Value('completed'),
        ),
      );

      // Tier 2: 25-48h past freshness -> 50% discount
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'TIER-2',
          productId: 141,
          quantityProduced: 10,
          operatorName: 'Baker 2',
          manufacturingDate: now,
          bakedAt: Value(now),
          freshnessUntil: Value(now.subtract(const Duration(hours: 30))),
          status: const Value('completed'),
        ),
      );

      // Tier 3: > 48h past freshness -> 70% discount
      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'TIER-3',
          productId: 141,
          quantityProduced: 10,
          operatorName: 'Baker 3',
          manufacturingDate: now,
          bakedAt: Value(now),
          freshnessUntil: Value(now.subtract(const Duration(hours: 60))),
          status: const Value('completed'),
        ),
      );

      final alerts = await freshnessService.flagStaleBatches(db: db, now: now);
      expect(alerts.length, equals(3));

      final tier1 = alerts.firstWhere((a) => a.batchNumber == 'TIER-1');
      expect(tier1.suggestedDiscountPercent, equals(25.0));

      final tier2 = alerts.firstWhere((a) => a.batchNumber == 'TIER-2');
      expect(tier2.suggestedDiscountPercent, equals(50.0));

      final tier3 = alerts.firstWhere((a) => a.batchNumber == 'TIER-3');
      expect(tier3.suggestedDiscountPercent, equals(70.0));
    });
  });
}
