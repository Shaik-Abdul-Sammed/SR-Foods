import 'package:intl/intl.dart';
import '../i18n/locale_context.dart';

/// Immutable, type-safe multi-currency Money value object (v2).
/// Stores financial amounts in exact integer minor units (paise, cents, fils, pence).
/// Eliminates IEEE 754 floating-point inaccuracies and supports international currencies and FX conversion.
class Money implements Comparable<Money> {
  final int amountMinor;
  final Currency currency;
  final double? fxRateToBase;

  const Money({
    required this.amountMinor,
    this.currency = Currency.inr,
    this.fxRateToBase,
  });

  const Money._(int paise)
      : amountMinor = paise,
        currency = Currency.inr,
        fxRateToBase = null;

  /// Construct from exact integer paise (legacy & INR backward compatibility)
  const Money.fromPaise(int paise, {this.currency = Currency.inr, this.fxRateToBase})
      : amountMinor = paise;

  /// Construct from standard rupees or major units (e.g. 100.50 -> 10050 minor units) with safe rounding
  factory Money.fromRupees(num rupees, {Currency currency = Currency.inr, double? fxRateToBase}) {
    final factor = currency.minorUnits == 2 ? 100 : currency.minorUnits == 3 ? 1000 : 1;
    return Money(
      amountMinor: (rupees * factor).round(),
      currency: currency,
      fxRateToBase: fxRateToBase,
    );
  }

  /// Construct from standard major units (e.g. $10.99, £5.20, AED 45.00)
  factory Money.fromMajor(num amountMajor, {Currency currency = Currency.inr, double? fxRateToBase}) {
    final factor = currency.minorUnits == 2 ? 100 : currency.minorUnits == 3 ? 1000 : 1;
    return Money(
      amountMinor: (amountMajor * factor).round(),
      currency: currency,
      fxRateToBase: fxRateToBase,
    );
  }

  /// Zero amount
  static const Money zero = Money._(0);

  /// Amount in integer paise (backward compatibility)
  int get paise => amountMinor;

  /// Value in standard floating-point rupees / major units
  double get inRupees => inMajor;

  double get inMajor {
    final factor = currency.minorUnits == 2 ? 100.0 : currency.minorUnits == 3 ? 1000.0 : 1.0;
    return amountMinor / factor;
  }

  bool get isNegative => amountMinor < 0;
  bool get isPositive => amountMinor > 0;
  bool get isZero => amountMinor == 0;

  Money operator +(Money other) {
    _ensureSameCurrency(other);
    return Money(
      amountMinor: amountMinor + other.amountMinor,
      currency: currency,
      fxRateToBase: fxRateToBase,
    );
  }

  Money operator -(Money other) {
    _ensureSameCurrency(other);
    return Money(
      amountMinor: amountMinor - other.amountMinor,
      currency: currency,
      fxRateToBase: fxRateToBase,
    );
  }

  Money operator *(num multiplier) => Money(
        amountMinor: (amountMinor * multiplier).round(),
        currency: currency,
        fxRateToBase: fxRateToBase,
      );

  Money operator /(num divisor) {
    if (divisor == 0) throw ArgumentError('Division by zero');
    return Money(
      amountMinor: (amountMinor / divisor).round(),
      currency: currency,
      fxRateToBase: fxRateToBase,
    );
  }

  Money operator -() => Money(
        amountMinor: -amountMinor,
        currency: currency,
        fxRateToBase: fxRateToBase,
      );

  bool operator <(Money other) {
    _ensureSameCurrency(other);
    return amountMinor < other.amountMinor;
  }

  bool operator <=(Money other) {
    _ensureSameCurrency(other);
    return amountMinor <= other.amountMinor;
  }

  bool operator >(Money other) {
    _ensureSameCurrency(other);
    return amountMinor > other.amountMinor;
  }

  bool operator >=(Money other) {
    _ensureSameCurrency(other);
    return amountMinor >= other.amountMinor;
  }

  /// Convert to another currency using explicit FX rate (rate = 1 unit of this currency in target currency)
  Money convertTo(Currency targetCurrency, double rate) {
    if (currency == targetCurrency) return this;
    final convertedMajor = inMajor * rate;
    return Money.fromMajor(
      convertedMajor,
      currency: targetCurrency,
      fxRateToBase: rate,
    );
  }

  void _ensureSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot perform arithmetic on mismatched currencies: ${currency.code} and ${other.currency.code}. Convert explicitly first.',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _ensureSameCurrency(other);
    return amountMinor.compareTo(other.amountMinor);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Money && other.amountMinor == amountMinor && other.currency == currency);

  @override
  int get hashCode => amountMinor.hashCode ^ currency.hashCode;

  /// Format as localized currency string (e.g. "₹1,250.50", "AED 450.00", "$12.99")
  String get formatted => format();

  String format({String? locale, bool includeSymbol = true, int? decimalDigits}) {
    final effectiveLocale = locale ?? currency.defaultLocale;
    final format = NumberFormat.currency(
      locale: effectiveLocale,
      symbol: includeSymbol ? currency.symbol : '',
      decimalDigits: decimalDigits ?? currency.minorUnits,
    );
    return format.format(inMajor);
  }

  /// Compact representation (e.g. "₹1.2K", "$4.5M")
  String formatCompact({String? locale, bool includeSymbol = true}) {
    final effectiveLocale = locale ?? currency.defaultLocale;
    final format = NumberFormat.compactCurrency(
      locale: effectiveLocale,
      symbol: includeSymbol ? currency.symbol : '',
    );
    return format.format(inMajor);
  }

  @override
  String toString() => format();
}
