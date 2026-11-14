/// Standard commercial measurement units for food production & distribution
enum ProductUnit {
  pack('Pack', 'pkts', UnitCategory.count),
  piece('Piece', 'pcs', UnitCategory.count),
  kg('Kilogram', 'kg', UnitCategory.mass),
  g('Gram', 'g', UnitCategory.mass),
  liter('Liter', 'L', UnitCategory.volume),
  ml('Milliliter', 'ml', UnitCategory.volume);

  final String label;
  final String symbol;
  final UnitCategory category;

  const ProductUnit(this.label, this.symbol, this.category);

  static ProductUnit fromString(String val) {
    final lower = val.trim().toLowerCase();
    switch (lower) {
      case 'pack':
      case 'pkts':
      case 'packet':
        return ProductUnit.pack;
      case 'piece':
      case 'pcs':
        return ProductUnit.piece;
      case 'kg':
      case 'kilogram':
        return ProductUnit.kg;
      case 'g':
      case 'gram':
      case 'grams':
        return ProductUnit.g;
      case 'l':
      case 'liter':
      case 'litre':
        return ProductUnit.liter;
      case 'ml':
      case 'milliliter':
        return ProductUnit.ml;
      default:
        return ProductUnit.pack;
    }
  }
}

enum UnitCategory { count, mass, volume }

/// Typed Quantity value object to prevent unit mismatch bugs in inventory and production
class Quantity implements Comparable<Quantity> {
  final double amount;
  final ProductUnit unit;

  const Quantity(this.amount, this.unit);

  static const Quantity zeroPacks = Quantity(0, ProductUnit.pack);
  static const Quantity zeroKg = Quantity(0, ProductUnit.kg);

  bool get isZero => amount == 0;
  bool get isPositive => amount > 0;
  bool get isNegative => amount < 0;

  /// Convert mass or volume to a compatible unit within the same category
  Quantity convertTo(ProductUnit targetUnit) {
    if (unit == targetUnit) return this;
    if (unit.category != targetUnit.category) {
      throw ArgumentError(
        'Cannot convert incompatible unit categories: ${unit.category} to ${targetUnit.category}',
      );
    }

    double baseValue; // base in grams, ml, or count
    switch (unit) {
      case ProductUnit.kg:
        baseValue = amount * 1000.0;
        break;
      case ProductUnit.g:
        baseValue = amount;
        break;
      case ProductUnit.liter:
        baseValue = amount * 1000.0;
        break;
      case ProductUnit.ml:
        baseValue = amount;
        break;
      case ProductUnit.pack:
      case ProductUnit.piece:
        baseValue = amount;
        break;
    }

    double convertedAmount;
    switch (targetUnit) {
      case ProductUnit.kg:
        convertedAmount = baseValue / 1000.0;
        break;
      case ProductUnit.g:
        convertedAmount = baseValue;
        break;
      case ProductUnit.liter:
        convertedAmount = baseValue / 1000.0;
        break;
      case ProductUnit.ml:
        convertedAmount = baseValue;
        break;
      case ProductUnit.pack:
      case ProductUnit.piece:
        convertedAmount = baseValue;
        break;
    }

    return Quantity(convertedAmount, targetUnit);
  }

  Quantity operator +(Quantity other) {
    if (unit == other.unit) {
      return Quantity(amount + other.amount, unit);
    }
    final converted = other.convertTo(unit);
    return Quantity(amount + converted.amount, unit);
  }

  Quantity operator -(Quantity other) {
    if (unit == other.unit) {
      return Quantity(amount - other.amount, unit);
    }
    final converted = other.convertTo(unit);
    return Quantity(amount - converted.amount, unit);
  }

  Quantity operator *(num factor) => Quantity(amount * factor, unit);
  Quantity operator /(num divisor) {
    if (divisor == 0) throw ArgumentError('Division by zero');
    return Quantity(amount / divisor, unit);
  }

  @override
  int compareTo(Quantity other) {
    final converted = other.convertTo(unit);
    return amount.compareTo(converted.amount);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Quantity) return false;
    if (unit.category != other.unit.category) return false;
    final converted = other.convertTo(unit);
    return (amount - converted.amount).abs() < 0.0001;
  }

  @override
  int get hashCode => Object.hash(amount, unit);

  String format({int decimalPlaces = 2}) {
    if (amount % 1 == 0) {
      return '${amount.toInt()} ${unit.symbol}';
    }
    return '${amount.toStringAsFixed(decimalPlaces)} ${unit.symbol}';
  }

  @override
  String toString() => format();
}
