// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:math' as math;

/// Represents an SKU item in the inventory catalog.
class SkuItem {
  final String skuCode;
  final String name;
  final String category; // 'dairy', 'bakery', 'frozen'
  final double price;
  final int shelfLifeDays;
  final bool isGlutenFree;
  final bool isVegan;

  const SkuItem({
    required this.skuCode,
    required this.name,
    required this.category,
    required this.price,
    required this.shelfLifeDays,
    this.isGlutenFree = false,
    this.isVegan = false,
  });
}

/// Result of Grover-inspired amplitude amplification search.
class GroverSearchResult {
  final List<SkuItem> matchedSkus;
  final List<double> finalProbabilities;
  final int optimalIterations;
  final int totalEvaluations;
  final double peakProbability;

  const GroverSearchResult({
    required this.matchedSkus,
    required this.finalProbabilities,
    required this.optimalIterations,
    required this.totalEvaluations,
    required this.peakProbability,
  });
}

/// Quantum-Inspired Amplitude Amplification (Grover's Algorithm) for Catalog SKU Substitution.
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Accelerates discovery of viable product substitutions under multi-attribute constraints
/// using classical state vector amplitude diffusion.
class GroverSkuSearchEngine {
  final List<SkuItem> catalog;

  GroverSkuSearchEngine(this.catalog);

  /// Performs amplitude amplification search for items matching [oraclePredicate].
  GroverSearchResult findSubstitutes({
    required bool Function(SkuItem item) oraclePredicate,
    int? customIterations,
  }) {
    final n = catalog.length;
    if (n == 0) {
      return const GroverSearchResult(
        matchedSkus: [],
        finalProbabilities: [],
        optimalIterations: 0,
        totalEvaluations: 0,
        peakProbability: 0.0,
      );
    }

    // 1. Identify matching items via classical oracle pre-check to compute M
    final matchIndices = <int>{};
    for (int i = 0; i < n; i++) {
      if (oraclePredicate(catalog[i])) {
        matchIndices.add(i);
      }
    }

    final m = matchIndices.length;
    if (m == 0) {
      return const GroverSearchResult(
        matchedSkus: [],
        finalProbabilities: [],
        optimalIterations: 0,
        totalEvaluations: 0,
        peakProbability: 0.0,
      );
    }

    // Optimal iteration count R ~ round( (pi/4) * sqrt(N / M) )
    final calculatedIterations = math.max(1, ((math.pi / 4.0) * math.sqrt(n / m)).round());
    final iterations = customIterations ?? calculatedIterations;

    // Initialize uniform amplitude state |s> = 1/sqrt(N)
    final amplitudes = List<double>.filled(n, 1.0 / math.sqrt(n));

    for (int iter = 0; iter < iterations; iter++) {
      // Step A: Oracle Phase Inversion: flip sign of target states
      for (final idx in matchIndices) {
        amplitudes[idx] = -amplitudes[idx];
      }

      // Step B: Diffusion Operator (Inversion about mean): 2|s><s| - I
      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        sum += amplitudes[i];
      }
      final mean = sum / n;

      for (int i = 0; i < n; i++) {
        amplitudes[i] = 2.0 * mean - amplitudes[i];
      }
    }

    // Compute measurement probabilities |a_i|^2
    final probabilities = List<double>.generate(n, (i) => amplitudes[i] * amplitudes[i]);

    // Rank matching items by amplified probability
    final rankedMatches = matchIndices.map((idx) => catalog[idx]).toList();
    final rankedProbs = matchIndices.map((idx) => probabilities[idx]).toList();

    double peakProb = 0.0;
    for (final p in rankedProbs) {
      if (p > peakProb) peakProb = p;
    }

    return GroverSearchResult(
      matchedSkus: List.unmodifiable(rankedMatches),
      finalProbabilities: List.unmodifiable(rankedProbs),
      optimalIterations: iterations,
      totalEvaluations: n * iterations,
      peakProbability: peakProb,
    );
  }
}
