import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database_provider.dart';
import '../database/app_database.dart';

enum Currency {
  inr('INR', '₹', 2, 'en_IN'),
  aed('AED', 'د.إ', 2, 'ar_AE'),
  usd('USD', '\$', 2, 'en_US'),
  gbp('GBP', '£', 2, 'en_GB'),
  cad('CAD', 'CA\$', 2, 'en_CA'),
  aud('AUD', 'A\$', 2, 'en_AU');

  final String code;
  final String symbol;
  final int minorUnits;
  final String defaultLocale;

  const Currency(this.code, this.symbol, this.minorUnits, this.defaultLocale);

  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => Currency.inr,
    );
  }
}

enum UnitSystem {
  metric('Metric', 'kg, L, °C'),
  imperial('Imperial', 'lb, gal, °F');

  final String label;
  final String description;

  const UnitSystem(this.label, this.description);

  static UnitSystem fromString(String val) {
    return val.toLowerCase() == 'imperial' ? UnitSystem.imperial : UnitSystem.metric;
  }
}

enum TaxRegime {
  gstIndia('GST (India)', 0.05),
  vatGulf('VAT (GCC 5%)', 0.05),
  salesTaxUs('US Zero/Export (0%)', 0.0),
  vatUk('VAT (UK 20%)', 0.20),
  gstHstCanada('GST/HST (Canada 5%)', 0.05),
  gstAustralia('GST (Australia 10%)', 0.10);

  final String label;
  final double defaultStandardRate;

  const TaxRegime(this.label, this.defaultStandardRate);

  static TaxRegime fromString(String val) {
    return TaxRegime.values.firstWhere(
      (t) => t.name == val || t.label == val,
      orElse: () => TaxRegime.gstIndia,
    );
  }
}

@immutable
class LocaleContext {
  final Locale locale;
  final Currency currency;
  final UnitSystem unitSystem;
  final String timezone;
  final TaxRegime taxRegime;
  final int entityId;

  const LocaleContext({
    this.locale = const Locale('en'),
    this.currency = Currency.inr,
    this.unitSystem = UnitSystem.metric,
    this.timezone = 'Asia/Kolkata',
    this.taxRegime = TaxRegime.gstIndia,
    this.entityId = 1,
  });

  bool get isRtl => locale.languageCode == 'ar';

  LocaleContext copyWith({
    Locale? locale,
    Currency? currency,
    UnitSystem? unitSystem,
    String? timezone,
    TaxRegime? taxRegime,
    int? entityId,
  }) {
    return LocaleContext(
      locale: locale ?? this.locale,
      currency: currency ?? this.currency,
      unitSystem: unitSystem ?? this.unitSystem,
      timezone: timezone ?? this.timezone,
      taxRegime: taxRegime ?? this.taxRegime,
      entityId: entityId ?? this.entityId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocaleContext &&
          runtimeType == other.runtimeType &&
          locale == other.locale &&
          currency == other.currency &&
          unitSystem == other.unitSystem &&
          timezone == other.timezone &&
          taxRegime == other.taxRegime &&
          entityId == other.entityId;

  @override
  int get hashCode =>
      locale.hashCode ^
      currency.hashCode ^
      unitSystem.hashCode ^
      timezone.hashCode ^
      taxRegime.hashCode ^
      entityId.hashCode;
}

class LocaleContextNotifier extends Notifier<LocaleContext> {
  bool _isInitialized = false;

  @override
  LocaleContext build() {
    return const LocaleContext();
  }

  Future<void> loadFromDatabase() async {
    if (_isInitialized) return;
    try {
      final db = ref.read(databaseProvider);
      final allSettings = await db.select(db.appSettings).get();
      final map = {for (final s in allSettings) s.key: s.value};

      final lang = map['locale_language_code'] ?? 'en';
      final curr = map['locale_currency'] ?? 'INR';
      final units = map['locale_unit_system'] ?? 'metric';
      final tz = map['locale_timezone'] ?? 'Asia/Kolkata';
      final tax = map['locale_tax_regime'] ?? 'gstIndia';
      final entity = int.tryParse(map['locale_entity_id'] ?? '1') ?? 1;

      state = LocaleContext(
        locale: Locale(lang),
        currency: Currency.fromCode(curr),
        unitSystem: UnitSystem.fromString(units),
        timezone: tz,
        taxRegime: TaxRegime.fromString(tax),
        entityId: entity,
      );
      _isInitialized = true;
    } catch (_) {
      // Gracefully maintain defaults if DB is loading
    }
  }

  Future<void> updateLocale(Locale newLocale) async {
    _isInitialized = true;
    state = state.copyWith(locale: newLocale);
    await _persistSetting('locale_language_code', newLocale.languageCode);
  }

  Future<void> updateCurrency(Currency newCurrency) async {
    _isInitialized = true;
    state = state.copyWith(currency: newCurrency);
    await _persistSetting('locale_currency', newCurrency.code);
  }

  Future<void> updateUnitSystem(UnitSystem newUnits) async {
    _isInitialized = true;
    state = state.copyWith(unitSystem: newUnits);
    await _persistSetting('locale_unit_system', newUnits.name);
  }

  Future<void> updateTimezone(String newTimezone) async {
    _isInitialized = true;
    state = state.copyWith(timezone: newTimezone);
    await _persistSetting('locale_timezone', newTimezone);
  }

  Future<void> updateTaxRegime(TaxRegime newTaxRegime) async {
    _isInitialized = true;
    state = state.copyWith(taxRegime: newTaxRegime);
    await _persistSetting('locale_tax_regime', newTaxRegime.name);
  }

  Future<void> updateEntityId(int newEntityId) async {
    _isInitialized = true;
    state = state.copyWith(entityId: newEntityId);
    await _persistSetting('locale_entity_id', newEntityId.toString());
  }

  Future<void> setExportCountryProfile(String countryCode) async {
    _isInitialized = true;
    switch (countryCode.toUpperCase()) {
      case 'AE':
        state = state.copyWith(
          locale: const Locale('ar'),
          currency: Currency.aed,
          unitSystem: UnitSystem.metric,
          timezone: 'Asia/Dubai',
          taxRegime: TaxRegime.vatGulf,
        );
        break;
      case 'US':
        state = state.copyWith(
          locale: const Locale('en'),
          currency: Currency.usd,
          unitSystem: UnitSystem.imperial,
          timezone: 'America/New_York',
          taxRegime: TaxRegime.salesTaxUs,
        );
        break;
      case 'GB':
      case 'UK':
        state = state.copyWith(
          locale: const Locale('en'),
          currency: Currency.gbp,
          unitSystem: UnitSystem.metric,
          timezone: 'Europe/London',
          taxRegime: TaxRegime.vatUk,
        );
        break;
      case 'CA':
        state = state.copyWith(
          locale: const Locale('fr'),
          currency: Currency.cad,
          unitSystem: UnitSystem.metric,
          timezone: 'America/Toronto',
          taxRegime: TaxRegime.gstHstCanada,
        );
        break;
      case 'AU':
        state = state.copyWith(
          locale: const Locale('en'),
          currency: Currency.aud,
          unitSystem: UnitSystem.metric,
          timezone: 'Australia/Sydney',
          taxRegime: TaxRegime.gstAustralia,
        );
        break;
      case 'IN':
      default:
        state = state.copyWith(
          locale: const Locale('en'),
          currency: Currency.inr,
          unitSystem: UnitSystem.metric,
          timezone: 'Asia/Kolkata',
          taxRegime: TaxRegime.gstIndia,
        );
        break;
    }
    await _persistSetting('locale_language_code', state.locale.languageCode);
    await _persistSetting('locale_currency', state.currency.code);
    await _persistSetting('locale_unit_system', state.unitSystem.name);
    await _persistSetting('locale_timezone', state.timezone);
    await _persistSetting('locale_tax_regime', state.taxRegime.name);
  }

  Future<void> _persistSetting(String key, String value) async {
    try {
      final db = ref.read(databaseProvider);
      await db.into(db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion(
              key: Value(key),
              value: Value(value),
              type: const Value('string'),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } catch (_) {
      // In-memory or initial setup fallback
    }
  }
}

final localeContextProvider = NotifierProvider<LocaleContextNotifier, LocaleContext>(
  LocaleContextNotifier.new,
);
