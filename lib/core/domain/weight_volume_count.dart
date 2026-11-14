/// Standard commercial Weight units for food manufacturing & export
enum WeightUnit {
  kg('Kilogram', 'kg', 1000.0),
  g('Gram', 'g', 1.0),
  lb('Pound', 'lb', 453.59237),
  oz('Ounce', 'oz', 28.349523125);

  final String label;
  final String symbol;
  final double gramsPerUnit;

  const WeightUnit(this.label, this.symbol, this.gramsPerUnit);

  static WeightUnit fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'kg':
      case 'kilogram':
        return WeightUnit.kg;
      case 'g':
      case 'gram':
      case 'grams':
        return WeightUnit.g;
      case 'lb':
      case 'lbs':
      case 'pound':
        return WeightUnit.lb;
      case 'oz':
      case 'ounce':
        return WeightUnit.oz;
      default:
        return WeightUnit.kg;
    }
  }
}

/// Immutable, type-safe Weight value object with exact conversion matrices
class Weight implements Comparable<Weight> {
  final double value;
  final WeightUnit unit;

  const Weight(this.value, this.unit);

  static const Weight zeroKg = Weight(0, WeightUnit.kg);

  double get inGrams => value * unit.gramsPerUnit;
  double get inKg => inGrams / 1000.0;
  double get inLb => inGrams / 453.59237;
  double get inOz => inGrams / 28.349523125;

  Weight convertTo(WeightUnit targetUnit) {
    if (unit == targetUnit) return this;
    final converted = inGrams / targetUnit.gramsPerUnit;
    return Weight(double.parse(converted.toStringAsFixed(4)), targetUnit);
  }

  Weight operator +(Weight other) {
    final sumGrams = inGrams + other.inGrams;
    return Weight(sumGrams / unit.gramsPerUnit, unit);
  }

  Weight operator -(Weight other) {
    final diffGrams = inGrams - other.inGrams;
    return Weight(diffGrams / unit.gramsPerUnit, unit);
  }

  Weight operator *(num factor) => Weight(value * factor, unit);
  Weight operator /(num divisor) {
    if (divisor == 0) throw ArgumentError('Division by zero');
    return Weight(value / divisor, unit);
  }

  bool operator <(Weight other) => inGrams < other.inGrams;
  bool operator <=(Weight other) => inGrams <= other.inGrams;
  bool operator >(Weight other) => inGrams > other.inGrams;
  bool operator >=(Weight other) => inGrams >= other.inGrams;

  @override
  int compareTo(Weight other) => inGrams.compareTo(other.inGrams);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Weight && (inGrams - other.inGrams).abs() < 1e-6);

  @override
  int get hashCode => inGrams.round().hashCode;

  @override
  String toString() => '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} ${unit.symbol}';
}

/// Standard commercial Volume units for liquid ingredients (oil, water, syrup)
enum VolumeUnit {
  l('Liter', 'L', 1000.0),
  ml('Milliliter', 'ml', 1.0),
  gal('US Gallon', 'gal', 3785.411784),
  flOz('Fluid Ounce', 'fl oz', 29.5735295625);

  final String label;
  final String symbol;
  final double mlPerUnit;

  const VolumeUnit(this.label, this.symbol, this.mlPerUnit);

  static VolumeUnit fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'l':
      case 'liter':
      case 'litre':
        return VolumeUnit.l;
      case 'ml':
      case 'milliliter':
        return VolumeUnit.ml;
      case 'gal':
      case 'gallon':
        return VolumeUnit.gal;
      case 'floz':
      case 'fl_oz':
      case 'fl oz':
        return VolumeUnit.flOz;
      default:
        return VolumeUnit.l;
    }
  }
}

/// Immutable, type-safe Volume value object
class Volume implements Comparable<Volume> {
  final double value;
  final VolumeUnit unit;

  const Volume(this.value, this.unit);

  static const Volume zeroLiters = Volume(0, VolumeUnit.l);

  double get inMl => value * unit.mlPerUnit;
  double get inLiters => inMl / 1000.0;
  double get inGallons => inMl / 3785.411784;
  double get inFlOz => inMl / 29.5735295625;

  Volume convertTo(VolumeUnit targetUnit) {
    if (unit == targetUnit) return this;
    final converted = inMl / targetUnit.mlPerUnit;
    return Volume(double.parse(converted.toStringAsFixed(4)), targetUnit);
  }

  Volume operator +(Volume other) {
    final sumMl = inMl + other.inMl;
    return Volume(sumMl / unit.mlPerUnit, unit);
  }

  Volume operator -(Volume other) {
    final diffMl = inMl - other.inMl;
    return Volume(diffMl / unit.mlPerUnit, unit);
  }

  Volume operator *(num factor) => Volume(value * factor, unit);
  Volume operator /(num divisor) {
    if (divisor == 0) throw ArgumentError('Division by zero');
    return Volume(value / divisor, unit);
  }

  bool operator <(Volume other) => inMl < other.inMl;
  bool operator <=(Volume other) => inMl <= other.inMl;
  bool operator >(Volume other) => inMl > other.inMl;
  bool operator >=(Volume other) => inMl >= other.inMl;

  @override
  int compareTo(Volume other) => inMl.compareTo(other.inMl);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Volume && (inMl - other.inMl).abs() < 1e-6);

  @override
  int get hashCode => inMl.round().hashCode;

  @override
  String toString() => '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} ${unit.symbol}';
}

/// Discrete package and count units for factory cartons, master packs, dozens
enum CountUnit {
  pieces('Pieces', 'pcs', 1),
  packs('Packs', 'pkts', 1),
  dozen('Dozen', 'doz', 12),
  cartons('Master Cartons', 'ctns', 24); // default 24 packs/carton for wholesale

  final String label;
  final String symbol;
  final int piecesPerUnit;

  const CountUnit(this.label, this.symbol, this.piecesPerUnit);

  static CountUnit fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'piece':
      case 'pieces':
      case 'pcs':
        return CountUnit.pieces;
      case 'pack':
      case 'packs':
      case 'pkts':
        return CountUnit.packs;
      case 'doz':
      case 'dozen':
        return CountUnit.dozen;
      case 'ctn':
      case 'ctns':
      case 'carton':
      case 'cartons':
        return CountUnit.cartons;
      default:
        return CountUnit.pieces;
    }
  }
}

/// Immutable, type-safe Count value object
class ItemCount implements Comparable<ItemCount> {
  final int amount;
  final CountUnit unit;

  const ItemCount(this.amount, this.unit);

  static const ItemCount zero = ItemCount(0, CountUnit.pieces);

  int get inPieces => amount * unit.piecesPerUnit;

  ItemCount convertTo(CountUnit targetUnit) {
    if (unit == targetUnit) return this;
    final converted = inPieces / targetUnit.piecesPerUnit;
    return ItemCount(converted.round(), targetUnit);
  }

  ItemCount operator +(ItemCount other) {
    if (unit == other.unit) {
      return ItemCount(amount + other.amount, unit);
    }
    return ItemCount(inPieces + other.inPieces, CountUnit.pieces);
  }

  ItemCount operator -(ItemCount other) {
    if (unit == other.unit) {
      return ItemCount(amount - other.amount, unit);
    }
    return ItemCount(inPieces - other.inPieces, CountUnit.pieces);
  }

  ItemCount operator *(int factor) => ItemCount(amount * factor, unit);

  bool operator <(ItemCount other) => inPieces < other.inPieces;
  bool operator <=(ItemCount other) => inPieces <= other.inPieces;
  bool operator >(ItemCount other) => inPieces > other.inPieces;
  bool operator >=(ItemCount other) => inPieces >= other.inPieces;

  @override
  int compareTo(ItemCount other) => inPieces.compareTo(other.inPieces);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemCount && inPieces == other.inPieces);

  @override
  int get hashCode => inPieces.hashCode;

  @override
  String toString() => '$amount ${unit.symbol}';
}
