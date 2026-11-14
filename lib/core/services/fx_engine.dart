import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../domain/money.dart';
import '../i18n/locale_context.dart';

class FxEngine {
  final AppDatabase? db;
  final Map<String, double> _localRateCache = {};

  FxEngine({this.db}) {
    _seedDefaultRates();
  }

  void _seedDefaultRates() {
    // Default baseline rates against INR (1 Unit Foreign Currency = X INR)
    setRate(base: Currency.usd, target: Currency.inr, rate: 83.50);
    setRate(base: Currency.aed, target: Currency.inr, rate: 22.73);
    setRate(base: Currency.gbp, target: Currency.inr, rate: 105.80);
    setRate(base: Currency.cad, target: Currency.inr, rate: 61.20);
    setRate(base: Currency.aud, target: Currency.inr, rate: 54.60);
  }

  String _pairKey(Currency base, Currency target) => '${base.code}_${target.code}';

  /// Register or override an FX rate in-memory
  void setRate({required Currency base, required Currency target, required double rate}) {
    if (rate <= 0) throw ArgumentError('FX rate must be positive');
    _localRateCache[_pairKey(base, target)] = rate;
    _localRateCache[_pairKey(target, base)] = 1.0 / rate;
  }

  /// Lock contract rate for a specific export order into Drift database
  Future<void> lockContractRate({
    required Currency base,
    required Currency target,
    required double rate,
    String source = 'contract_lock',
  }) async {
    setRate(base: base, target: target, rate: rate);
    final database = db;
    if (database != null) {
      await database.into(database.fxRates).insert(
            FxRatesCompanion.insert(
              baseCurrency: base.code,
              targetCurrency: target.code,
              rate: rate,
              source: Value(source),
            ),
          );
    }
  }

  /// Fetch rate between two currencies (direct, inverse, or cross-rate via INR)
  double getRate({required Currency from, required Currency to, Currency anchor = Currency.inr}) {
    if (from == to) return 1.0;

    // 1. Direct or inverse lookup
    final directKey = _pairKey(from, to);
    if (_localRateCache.containsKey(directKey)) {
      return _localRateCache[directKey]!;
    }

    // 2. Cross-rate via anchor currency (default INR)
    final fromToAnchorKey = _pairKey(from, anchor);
    final toToAnchorKey = _pairKey(to, anchor);

    if (_localRateCache.containsKey(fromToAnchorKey) && _localRateCache.containsKey(toToAnchorKey)) {
      final rateFromAnchor = _localRateCache[fromToAnchorKey]!;
      final rateToAnchor = _localRateCache[toToAnchorKey]!;
      final crossRate = rateFromAnchor / rateToAnchor;
      return crossRate;
    }

    throw ArgumentError('No FX rate or cross-rate path found between ${from.code} and ${to.code}');
  }

  /// Convert Money from one currency to target currency using resolved FX rate
  Money convert(Money money, Currency targetCurrency, {double? contractOverrideRate}) {
    if (money.currency == targetCurrency) return money;

    final effectiveRate = contractOverrideRate ?? getRate(from: money.currency, to: targetCurrency);
    final convertedMajor = money.inMajor * effectiveRate;

    return Money.fromMajor(
      convertedMajor,
      currency: targetCurrency,
      fxRateToBase: effectiveRate,
    );
  }
}
