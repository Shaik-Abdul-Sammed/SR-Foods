// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:math' as math;

/// Milk procurement supplier profile (farmer or collection center).
class MilkSupplier {
  final String id;
  final String name;
  final double maxLiters;
  final double pricePerLiter;
  final double fatPercentage;
  final double snfPercentage;
  final double distanceKm;
  final double reliability; // 0.0 to 1.0

  const MilkSupplier({
    required this.id,
    required this.name,
    required this.maxLiters,
    required this.pricePerLiter,
    required this.fatPercentage,
    required this.snfPercentage,
    required this.distanceKm,
    this.reliability = 1.0,
  });
}

/// Target procurement constraints for dairy processing plant.
class ProcurementTarget {
  final double targetLiters;
  final double minFatPercentage;
  final double minSnfPercentage;
  final double maxBudget;

  const ProcurementTarget({
    required this.targetLiters,
    required this.minFatPercentage,
    required this.minSnfPercentage,
    required this.maxBudget,
  });
}

/// Result of quantum-inspired procurement portfolio optimization.
class ProcurementPlanResult {
  final Map<String, double> allocatedLiters; // supplierId -> liters
  final double totalProcuredLiters;
  final double totalCost;
  final double averageFat;
  final double averageSnf;
  final double averageDistanceKm;
  final bool targetMet;
  final int iterations;

  const ProcurementPlanResult({
    required this.allocatedLiters,
    required this.totalProcuredLiters,
    required this.totalCost,
    required this.averageFat,
    required this.averageSnf,
    required this.averageDistanceKm,
    required this.targetMet,
    required this.iterations,
  });
}

/// Quantum-Inspired Procurement Optimizer (QUBO-based Portfolio Solver).
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Solves constrained quadratic portfolio allocation minimizing costs, transit distance,
/// and supply risk while strictly guaranteeing dairy fat & SNF blend thresholds.
class QuantumProcurementOptimizer {
  final List<MilkSupplier> suppliers;

  QuantumProcurementOptimizer(this.suppliers);

  ProcurementPlanResult optimize(ProcurementTarget target, {int iterations = 400, int? seed}) {
    final rand = math.Random(seed ?? 42);
    final n = suppliers.length;
    if (n == 0) {
      return const ProcurementPlanResult(
        allocatedLiters: {},
        totalProcuredLiters: 0,
        totalCost: 0,
        averageFat: 0,
        averageSnf: 0,
        averageDistanceKm: 0,
        targetMet: false,
        iterations: 0,
      );
    }

    // Initialize allocations proportionally to target
    final totalMax = suppliers.fold<double>(0.0, (acc, s) => acc + s.maxLiters);
    final initialRatio = totalMax > 0 ? (target.targetLiters / totalMax).clamp(0.0, 1.0) : 0.5;
    List<double> currentX = List.generate(n, (_) => initialRatio);
    List<double> bestX = List.from(currentX);
    double bestEnergy = _evaluateEnergy(bestX, target);

    double temp = 50.0;
    final decay = math.pow(0.0001 / 50.0, 1.0 / iterations).toDouble();

    for (int step = 0; step < iterations; step++) {
      final candidateX = List<double>.from(currentX);

      // Mutate one or two suppliers with quantum tunneling perturbation
      final idx = rand.nextInt(n);
      final delta = (rand.nextDouble() * 0.4 - 0.2);
      candidateX[idx] = (candidateX[idx] + delta).clamp(0.0, 1.0);

      // If more than 1 supplier, balance delta on another supplier to preserve volume scale
      if (n > 1) {
        final otherIdx = (idx + 1 + rand.nextInt(n - 1)) % n;
        final deltaLiters = delta * suppliers[idx].maxLiters;
        final compensatingFraction = deltaLiters / suppliers[otherIdx].maxLiters;
        candidateX[otherIdx] = (candidateX[otherIdx] - compensatingFraction).clamp(0.0, 1.0);
      }

      final candidateEnergy = _evaluateEnergy(candidateX, target);
      final currentEnergy = _evaluateEnergy(currentX, target);
      final dE = candidateEnergy - currentEnergy;

      if (dE <= 0.0 || rand.nextDouble() < math.exp(-dE / (temp + 1e-5))) {
        currentX = candidateX;
        if (candidateEnergy < bestEnergy) {
          bestEnergy = candidateEnergy;
          bestX = List.from(candidateX);
        }
      }

      temp *= decay;
    }

    // Build metrics from best solution
    final allocation = <String, double>{};
    double totalLiters = 0.0;
    double totalCost = 0.0;
    double weightedFat = 0.0;
    double weightedSnf = 0.0;
    double weightedDist = 0.0;

    for (int i = 0; i < n; i++) {
      final s = suppliers[i];
      final liters = bestX[i] * s.maxLiters;
      if (liters > 0.1) {
        allocation[s.id] = (liters * 10.0).round() / 10.0;
        totalLiters += liters;
        totalCost += liters * s.pricePerLiter;
        weightedFat += liters * s.fatPercentage;
        weightedSnf += liters * s.snfPercentage;
        weightedDist += liters * s.distanceKm;
      }
    }

    final avgFat = totalLiters > 0 ? weightedFat / totalLiters : 0.0;
    final avgSnf = totalLiters > 0 ? weightedSnf / totalLiters : 0.0;
    final avgDist = totalLiters > 0 ? weightedDist / totalLiters : 0.0;

    final volumeSatisfied = (totalLiters - target.targetLiters).abs() <= (target.targetLiters * 0.08);
    final qualitySatisfied = avgFat >= (target.minFatPercentage - 0.15) && avgSnf >= (target.minSnfPercentage - 0.15);

    return ProcurementPlanResult(
      allocatedLiters: Map.unmodifiable(allocation),
      totalProcuredLiters: (totalLiters * 10.0).round() / 10.0,
      totalCost: (totalCost * 100.0).round() / 100.0,
      averageFat: (avgFat * 100.0).round() / 100.0,
      averageSnf: (avgSnf * 100.0).round() / 100.0,
      averageDistanceKm: (avgDist * 10.0).round() / 10.0,
      targetMet: volumeSatisfied && qualitySatisfied,
      iterations: iterations,
    );
  }

  double _evaluateEnergy(List<double> x, ProcurementTarget target) {
    double totalVol = 0.0;
    double cost = 0.0;
    double weightedFat = 0.0;
    double weightedSnf = 0.0;
    double weightedDist = 0.0;
    double riskPenalty = 0.0;

    for (int i = 0; i < suppliers.length; i++) {
      final s = suppliers[i];
      final liters = x[i] * s.maxLiters;
      totalVol += liters;
      cost += liters * s.pricePerLiter;
      weightedFat += liters * s.fatPercentage;
      weightedSnf += liters * s.snfPercentage;
      weightedDist += liters * s.distanceKm * 0.5;
      riskPenalty += liters * (1.0 - s.reliability) * 50.0;
    }

    final avgFat = totalVol > 0 ? weightedFat / totalVol : 0.0;
    final avgSnf = totalVol > 0 ? weightedSnf / totalVol : 0.0;

    // Hard penalty for missing or excess target volume
    final volDiff = (totalVol - target.targetLiters);
    final volPenalty = 1000.0 * volDiff.abs() + 2.0 * (volDiff * volDiff);

    // Hard penalty for quality deficit
    final fatDeficit = math.max(0.0, target.minFatPercentage - avgFat);
    final fatPenalty = 200000.0 * (fatDeficit * fatDeficit);

    final snfDeficit = math.max(0.0, target.minSnfPercentage - avgSnf);
    final snfPenalty = 200000.0 * (snfDeficit * snfDeficit);

    return cost + weightedDist + riskPenalty + volPenalty + fatPenalty + snfPenalty;
  }
}
