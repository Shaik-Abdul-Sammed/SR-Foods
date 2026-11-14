import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/database/database_provider.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  group('LocaleContext Unit Tests (Step 1.3)', () {
    test('1. Default initialization has English, INR, Metric, and Asia/Kolkata with non-RTL', () {
      final context = container.read(localeContextProvider);
      expect(context.locale.languageCode, 'en');
      expect(context.currency, Currency.inr);
      expect(context.unitSystem, UnitSystem.metric);
      expect(context.timezone, 'Asia/Kolkata');
      expect(context.taxRegime, TaxRegime.gstIndia);
      expect(context.entityId, 1);
      expect(context.isRtl, isFalse);
    });

    test('2. Switching export country profile to UAE (AE) configures Arabic RTL, AED currency, and Dubai timezone', () async {
      final notifier = container.read(localeContextProvider.notifier);
      await notifier.setExportCountryProfile('AE');

      final context = container.read(localeContextProvider);
      expect(context.locale.languageCode, 'ar');
      expect(context.currency, Currency.aed);
      expect(context.currency.symbol, 'د.إ');
      expect(context.timezone, 'Asia/Dubai');
      expect(context.taxRegime, TaxRegime.vatGulf);
      expect(context.isRtl, isTrue);

      // Verify persistence to Drift app_settings table
      final settings = await db.select(db.appSettings).get();
      final map = {for (final s in settings) s.key: s.value};
      expect(map['locale_language_code'], 'ar');
      expect(map['locale_currency'], 'AED');
      expect(map['locale_timezone'], 'Asia/Dubai');
    });

    test('3. Switching export country profile to US configures Imperial units, USD, and NY timezone', () async {
      final notifier = container.read(localeContextProvider.notifier);
      await notifier.setExportCountryProfile('US');

      final context = container.read(localeContextProvider);
      expect(context.locale.languageCode, 'en');
      expect(context.currency, Currency.usd);
      expect(context.unitSystem, UnitSystem.imperial);
      expect(context.timezone, 'America/New_York');
      expect(context.taxRegime, TaxRegime.salesTaxUs);
      expect(context.isRtl, isFalse);

      final settings = await db.select(db.appSettings).get();
      final map = {for (final s in settings) s.key: s.value};
      expect(map['locale_currency'], 'USD');
      expect(map['locale_unit_system'], 'imperial');
      expect(map['locale_timezone'], 'America/New_York');
    });
  });
}
