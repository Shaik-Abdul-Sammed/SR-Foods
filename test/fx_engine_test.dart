import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';
import 'package:sr_foods/core/services/fx_engine.dart';

void main() {
  group('FX Engine & Cross-Rate Mathematical Tests', () {
    late AppDatabase db;
    late FxEngine fx;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      fx = FxEngine(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Direct INR <-> AED conversion and inverse calculations', () {
      // 1 AED = 22.73 INR
      final aed100 = Money.fromMajor(100.0, currency: Currency.aed);
      final inrConverted = fx.convert(aed100, Currency.inr);

      expect(inrConverted.currency, Currency.inr);
      expect(inrConverted.inMajor, closeTo(2273.0, 0.01));

      // Inverse: 2273 INR -> AED
      final inr2273 = Money.fromRupees(2273.0);
      final aedConverted = fx.convert(inr2273, Currency.aed);
      expect(aedConverted.currency, Currency.aed);
      expect(aedConverted.inMajor, closeTo(100.0, 0.05));
    });

    test('2. Direct INR <-> USD conversion and inverse calculations', () {
      // 1 USD = 83.50 INR
      final usd100 = Money.fromMajor(100.0, currency: Currency.usd);
      final inr = fx.convert(usd100, Currency.inr);

      expect(inr.currency, Currency.inr);
      expect(inr.inMajor, 8350.0);

      // Inverse: 8350 INR -> USD
      final inrAmount = Money.fromRupees(8350.0);
      final usd = fx.convert(inrAmount, Currency.usd);
      expect(usd.currency, Currency.usd);
      expect(usd.inMajor, 100.0);
    });

    test('3. Cross-rate USD <-> AED derived via INR base anchor', () {
      // USD -> INR is 83.50, AED -> INR is 22.73
      // Expected cross rate USD -> AED = 83.50 / 22.73 = 3.67355
      final derivedRate = fx.getRate(from: Currency.usd, to: Currency.aed);
      expect(derivedRate, closeTo(3.67355, 0.001));

      final usd500 = Money.fromMajor(500.0, currency: Currency.usd);
      final aed = fx.convert(usd500, Currency.aed);

      expect(aed.currency, Currency.aed);
      // 500 * 3.67355 = 1836.78 AED
      expect(aed.inMajor, closeTo(1836.78, 0.10));

      // Inverse AED -> USD: 1836.78 / 3.67355 = 500 USD
      final usdBack = fx.convert(aed, Currency.usd);
      expect(usdBack.inMajor, closeTo(500.0, 0.10));
    });

    test('4. Manual contract locked rate override', () {
      final orderAmount = Money.fromMajor(1000.0, currency: Currency.usd);

      // Spot rate would yield ~83,500 INR, but contract locked at 84.20
      final contractInr = fx.convert(orderAmount, Currency.inr, contractOverrideRate: 84.20);
      expect(contractInr.inMajor, 84200.0);
      expect(contractInr.fxRateToBase, 84.20);
    });

    test('5. Lock contract rate persists into Drift FxRates table', () async {
      await fx.lockContractRate(
        base: Currency.cad,
        target: Currency.inr,
        rate: 61.85,
        source: 'contract_exp_089',
      );

      final ratesInDb = await db.select(db.fxRates).get();
      expect(ratesInDb.any((r) => r.baseCurrency == 'CAD' && r.rate == 61.85), isTrue);

      final cad100 = Money.fromMajor(100.0, currency: Currency.cad);
      final inr = fx.convert(cad100, Currency.inr);
      expect(inr.inMajor, 6185.0);
    });
  });
}
