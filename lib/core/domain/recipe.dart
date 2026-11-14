/// Bill of Materials (BOM) & Recipe Domain Models for SR Foods
/// Represents industrial food manufacturing formulation, yields, and raw material costs.
library;

class RecipeIngredient {
  final String rawMaterialName;
  final double quantity; // Quantity required for batchBaseUnits
  final String unit; // 'kg', 'L', 'pcs', 'g'
  final double standardUnitCost; // Cost in INR per unit

  const RecipeIngredient({
    required this.rawMaterialName,
    required this.quantity,
    required this.unit,
    required this.standardUnitCost,
  });

  double get totalCost => quantity * standardUnitCost;
}

class ProductRecipe {
  final String sku;
  final String productName;
  final int batchBaseUnits; // e.g. 100 packs (500 pcs)
  final double standardYieldPercent; // e.g. 98.0%
  final String machineType; // Machine A (Semi-Auto Parota Press), etc.
  final int capacityPacksPerHour; // Standard machine throughput
  final int shelfLifeDays; // Days before expiry
  final List<RecipeIngredient> ingredients;

  const ProductRecipe({
    required this.sku,
    required this.productName,
    required this.batchBaseUnits,
    required this.standardYieldPercent,
    required this.machineType,
    required this.capacityPacksPerHour,
    required this.shelfLifeDays,
    required this.ingredients,
  });

  /// Compute exact raw material quantities needed for an arbitrary number of packs
  Map<String, double> computeMaterialsFor(int packCount) {
    if (packCount <= 0 || batchBaseUnits <= 0) return {};
    final ratio = packCount / batchBaseUnits;
    final Map<String, double> result = {};
    for (final ing in ingredients) {
      final key = '${ing.rawMaterialName} (${ing.unit})';
      result[key] = double.parse((ing.quantity * ratio).toStringAsFixed(2));
    }
    return result;
  }

  /// Compute theoretical material cost for a batch using either live or standard ingredient rates
  double computeTheoreticalBatchCost(
    int packCount, {
    Map<String, double>? customRates,
  }) {
    if (packCount <= 0 || batchBaseUnits <= 0) return 0.0;
    final ratio = packCount / batchBaseUnits;
    double totalCost = 0.0;
    for (final ing in ingredients) {
      final rate = customRates?[ing.rawMaterialName] ?? ing.standardUnitCost;
      totalCost += (ing.quantity * ratio) * rate;
    }
    return totalCost;
  }

  /// Cost per pack (BOM cost)
  double computeCostPerPack(
    int packCount, {
    Map<String, double>? customRates,
  }) {
    if (packCount <= 0) return 0.0;
    return computeTheoreticalBatchCost(packCount, customRates: customRates) / packCount;
  }

  /// Gross margin % = ((Selling Price - BOM Cost) / Selling Price) * 100
  double computeGrossMargin(
    double sellingPrice,
    int packCount, {
    Map<String, double>? customRates,
  }) {
    if (sellingPrice <= 0) return 0.0;
    final costPerPack = computeCostPerPack(packCount, customRates: customRates);
    return ((sellingPrice - costPerPack) / sellingPrice) * 100.0;
  }
}

/// Standard verified factory formulations for SR Foods product line
class StandardRecipes {
  StandardRecipes._();

  /// Half Boiled Parota (100 packs = 500 pcs)
  static const parotaRecipe = ProductRecipe(
    sku: 'SRF-HBP-001',
    productName: 'Half Boiled Parota',
    batchBaseUnits: 100,
    standardYieldPercent: 98.0,
    machineType: 'Machine A (Semi-Auto Parota Press & Roaster)',
    capacityPacksPerHour: 80,
    shelfLifeDays: 6,
    ingredients: [
      RecipeIngredient(
        rawMaterialName: 'Maida Flour',
        quantity: 55.0,
        unit: 'kg',
        standardUnitCost: 38.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Refined Sunflower Oil',
        quantity: 6.0,
        unit: 'L',
        standardUnitCost: 135.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Iodized Salt',
        quantity: 1.2,
        unit: 'kg',
        standardUnitCost: 18.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Food Grade Pouches (50u)',
        quantity: 100.0,
        unit: 'pcs',
        standardUnitCost: 1.80,
      ),
    ],
  );

  /// Triangular Chapathi (100 packs = 500 pcs)
  static const chapathiRecipe = ProductRecipe(
    sku: 'SRF-TC-002',
    productName: 'Triangular Chapathi',
    batchBaseUnits: 100,
    standardYieldPercent: 97.0,
    machineType: 'Machine B (Rotary Chapathi Press)',
    capacityPacksPerHour: 90,
    shelfLifeDays: 5,
    ingredients: [
      RecipeIngredient(
        rawMaterialName: 'Whole Wheat Atta',
        quantity: 52.0,
        unit: 'kg',
        standardUnitCost: 42.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Refined Sunflower Oil',
        quantity: 4.0,
        unit: 'L',
        standardUnitCost: 135.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Iodized Salt',
        quantity: 1.0,
        unit: 'kg',
        standardUnitCost: 18.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Food Grade Pouches (50u)',
        quantity: 100.0,
        unit: 'pcs',
        standardUnitCost: 1.80,
      ),
    ],
  );

  /// Phulka / Pulka (Oil-Free, 100 packs = 500 pcs)
  static const pulkaRecipe = ProductRecipe(
    sku: 'SRF-PUL-003',
    productName: 'Pulka',
    batchBaseUnits: 100,
    standardYieldPercent: 96.0,
    machineType: 'Machine C (Phulka Puffing Unit)',
    capacityPacksPerHour: 100,
    shelfLifeDays: 4,
    ingredients: [
      RecipeIngredient(
        rawMaterialName: 'Whole Wheat Atta',
        quantity: 55.0,
        unit: 'kg',
        standardUnitCost: 42.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Iodized Salt',
        quantity: 1.0,
        unit: 'kg',
        standardUnitCost: 18.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Food Grade Pouches (50u)',
        quantity: 100.0,
        unit: 'pcs',
        standardUnitCost: 1.80,
      ),
    ],
  );

  /// Puri (100 packs = 500 pcs)
  static const puriRecipe = ProductRecipe(
    sku: 'SRF-PUR-004',
    productName: 'Puri',
    batchBaseUnits: 100,
    standardYieldPercent: 97.0,
    machineType: 'Machine D (Puri Sheeter & Cutter)',
    capacityPacksPerHour: 90,
    shelfLifeDays: 4,
    ingredients: [
      RecipeIngredient(
        rawMaterialName: 'Whole Wheat Atta',
        quantity: 30.0,
        unit: 'kg',
        standardUnitCost: 42.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Maida Flour',
        quantity: 20.0,
        unit: 'kg',
        standardUnitCost: 38.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Refined Sunflower Oil',
        quantity: 5.0,
        unit: 'L',
        standardUnitCost: 135.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Iodized Salt',
        quantity: 1.0,
        unit: 'kg',
        standardUnitCost: 18.0,
      ),
      RecipeIngredient(
        rawMaterialName: 'Food Grade Pouches (50u)',
        quantity: 100.0,
        unit: 'pcs',
        standardUnitCost: 1.80,
      ),
    ],
  );

  /// Get recipe for product by SKU or name
  static ProductRecipe getRecipeFor(String skuOrName) {
    final query = skuOrName.toLowerCase();
    if (query.contains('srf-hbp') || query.contains('parota')) {
      return parotaRecipe;
    } else if (query.contains('srf-tc') || query.contains('chapathi')) {
      return chapathiRecipe;
    } else if (query.contains('srf-pul') || query.contains('pulka') || query.contains('phulka')) {
      return pulkaRecipe;
    } else if (query.contains('srf-pur') || query.contains('puri')) {
      return puriRecipe;
    }
    // Fallback default recipe
    return parotaRecipe;
  }
}
