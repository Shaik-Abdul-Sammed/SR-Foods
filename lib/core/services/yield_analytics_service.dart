import '../domain/recipe.dart';

class YieldAnalysisResult {
  final String productName;
  final int actualPacksProduced;
  final double theoreticalPacks;
  final double yieldPercentage;
  final double standardYieldPercentage;
  final double variancePercentage;
  final double estimatedWastageKg;
  final double estimatedLossRupees;
  final String status; // 'optimal' | 'acceptable' | 'critical_variance'
  final String diagnosticAdvice;

  const YieldAnalysisResult({
    required this.productName,
    required this.actualPacksProduced,
    required this.theoreticalPacks,
    required this.yieldPercentage,
    required this.standardYieldPercentage,
    required this.variancePercentage,
    required this.estimatedWastageKg,
    required this.estimatedLossRupees,
    required this.status,
    required this.diagnosticAdvice,
  });

  bool get isSevereDeviation => variancePercentage.abs() > 3.0;
}

class YieldAnalyticsService {
  YieldAnalyticsService._();
  static final YieldAnalyticsService instance = YieldAnalyticsService._();

  /// Calculates actual batch yield vs theoretical BOM formulation.
  /// Flags variances > 3% from standard factory expectations.
  YieldAnalysisResult analyzeBatchYield({
    required ProductRecipe recipe,
    required int actualPacksProduced,
    required double actualFlourKgConsumed,
    double flourCostPerKg = 38.0,
  }) {
    // Standard flour required per pack
    final mainFlour = recipe.ingredients.firstWhere(
      (i) => i.unit == 'kg' && (i.rawMaterialName.contains('Flour') || i.rawMaterialName.contains('Atta')),
      orElse: () => recipe.ingredients.first,
    );

    final standardFlourPerPack = mainFlour.quantity / recipe.batchBaseUnits;
    final theoreticalPacks = (actualFlourKgConsumed / standardFlourPerPack) * (recipe.standardYieldPercent / 100.0);

    final yieldPct = theoreticalPacks > 0
        ? (actualPacksProduced / theoreticalPacks) * 100.0
        : 0.0;

    final variance = yieldPct - recipe.standardYieldPercent;

    // Wastage calculation
    final theoreticalFlourNeeded = actualPacksProduced * standardFlourPerPack;
    final wastageKg = (actualFlourKgConsumed - theoreticalFlourNeeded).clamp(0.0, 9999.0);
    final lossRupees = wastageKg * flourCostPerKg;

    String status;
    String advice;

    if (variance < -3.0) {
      status = 'critical_variance';
      advice = 'CRITICAL YIELD DEFICIT (${variance.toStringAsFixed(1)}% below standard). '
          'Investigate dough moisture loss, excessive edge trimming at sheeter, or sub-weight packing.';
    } else if (variance < -1.0) {
      status = 'acceptable';
      advice = 'Minor yield deficit (${variance.toStringAsFixed(1)}%). Normal shift variation.';
    } else if (variance > 3.0) {
      status = 'critical_variance';
      advice = 'ABNORMAL POSITIVE DEVIATION (+${variance.toStringAsFixed(1)}%). '
          'Check individual pack weight! Underweight pieces (< 80g standard) risk customer complaints and FSSAI packaging non-compliance.';
    } else {
      status = 'optimal';
      advice = 'Optimal factory yield (${yieldPct.toStringAsFixed(1)}%). Formulation is well-balanced.';
    }

    return YieldAnalysisResult(
      productName: recipe.productName,
      actualPacksProduced: actualPacksProduced,
      theoreticalPacks: double.parse(theoreticalPacks.toStringAsFixed(1)),
      yieldPercentage: double.parse(yieldPct.toStringAsFixed(1)),
      standardYieldPercentage: recipe.standardYieldPercent,
      variancePercentage: double.parse(variance.toStringAsFixed(1)),
      estimatedWastageKg: double.parse(wastageKg.toStringAsFixed(2)),
      estimatedLossRupees: double.parse(lossRupees.toStringAsFixed(2)),
      status: status,
      diagnosticAdvice: advice,
    );
  }
}
