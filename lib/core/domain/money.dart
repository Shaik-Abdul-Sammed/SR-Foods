import 'package:intl/intl.dart';

/// Immutable, type-safe representation of financial amounts in integer paise (1/100 of INR).
/// Eliminates IEEE 754 floating-point inaccuracies in financial ledgers and billing.
class Money implements Comparable<Money> {
  final int paise;

  const Money._(this.paise);

  /// Construct from exact integer paise
  const Money.fromPaise(this.paise);

  /// Construct from standard rupees (e.g. 100.50 -> 10050 paise) with safe rounding
  factory Money.fromRupees(num rupees) {
    return Money._((rupees * 100).round());
  }

  /// Zero amount
  static const Money zero = Money._(0);

  /// Value in standard floating-point rupees (for external compatibility)
  double get inRupees => paise / 100.0;

  bool get isNegative => paise < 0;
  bool get isPositive => paise > 0;
  bool get isZero => paise == 0;

  Money operator +(Money other) => Money._(paise + other.paise);
  Money operator -(Money other) => Money._(paise - other.paise);
  Money operator *(num multiplier) => Money._((paise * multiplier).round());
  Money operator /(num divisor) {
    if (divisor == 0) throw ArgumentError('Division by zero');
    return Money._((paise / divisor).round());
  }

  Money operator -() => Money._(-paise);

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Money && other.paise == paise);

  @override
  int get hashCode => paise.hashCode;

  /// Format as INR currency string (e.g. "₹1,250.50")
  String get formatted => format();

  String format({bool includeSymbol = true, int decimalDigits = 2}) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: includeSymbol ? '₹' : '',
      decimalDigits: decimalDigits,
    );
    return format.format(inRupees);
  }

  /// Compact representation (e.g. "₹1.2K", "₹4.5L")
  String formatCompact({bool includeSymbol = true}) {
    final format = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: includeSymbol ? '₹' : '',
    );
    return format.format(inRupees);
  }

  @override
  String toString() => format();
}
