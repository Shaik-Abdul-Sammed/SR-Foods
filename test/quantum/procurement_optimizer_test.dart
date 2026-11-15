// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/procurement_optimizer.dart';

void main() {
  group('QuantumProcurementOptimizer Tests (Quantum-Inspired Classical)', () {
    final sampleSuppliers = [
      const MilkSupplier(
        id: 'SUP-01',
        name: 'Dairy Farmer Cooperative Medchal',
        maxLiters: 1000.0,
        pricePerLiter: 38.0,
        fatPercentage: 4.2,
        snfPercentage: 8.6,
        distanceKm: 15.0,
        reliability: 0.95,
      ),
      const MilkSupplier(
        id: 'SUP-02',
        name: 'Shamirpet Milk Hub',
        maxLiters: 1500.0,
        pricePerLiter: 37.0,
        fatPercentage: 3.8,
        snfPercentage: 8.4,
        distanceKm: 22.0,
        reliability: 0.90,
      ),
      const MilkSupplier(
        id: 'SUP-03',
        name: 'Gajwel Premium Buffalo Center',
        maxLiters: 800.0,
        pricePerLiter: 55.0,
        fatPercentage: 6.5,
        snfPercentage: 9.0,
        distanceKm: 35.0,
        reliability: 0.98,
      ),
      const MilkSupplier(
        id: 'SUP-04',
        name: 'Siddipet High-Fat Source',
        maxLiters: 1200.0,
        pricePerLiter: 52.0,
        fatPercentage: 6.0,
        snfPercentage: 8.8,
        distanceKm: 45.0,
        reliability: 0.85,
      ),
    ];

    test('1. Fulfills 2000L procurement volume with quality targets', () {
      final optimizer = QuantumProcurementOptimizer(sampleSuppliers);
      final target = const ProcurementTarget(
        targetLiters: 2000.0,
        minFatPercentage: 4.0,
        minSnfPercentage: 8.5,
        maxBudget: 100000.0,
      );

      final plan = optimizer.optimize(target, iterations: 500, seed: 101);

      expect(plan.allocatedLiters, isNotEmpty);
      expect((plan.totalProcuredLiters - 2000.0).abs(), lessThanOrEqualTo(150.0));
      expect(plan.averageFat, greaterThanOrEqualTo(3.9));
      expect(plan.averageSnf, greaterThanOrEqualTo(8.4));
      expect(plan.totalCost, greaterThan(0.0));
    });

    test('2. Prefers high-fat supplier when target requires rich fat blend', () {
      final optimizer = QuantumProcurementOptimizer(sampleSuppliers);
      final target = const ProcurementTarget(
        targetLiters: 1000.0,
        minFatPercentage: 5.5, // High fat requires SUP-03 / SUP-04
        minSnfPercentage: 8.7,
        maxBudget: 60000.0,
      );

      final plan = optimizer.optimize(target, iterations: 500, seed: 202);

      expect(plan.averageFat, greaterThanOrEqualTo(5.2));
      // Rich fat sources SUP-03 or SUP-04 should be allocated substantial volume
      final buffaloLiters = (plan.allocatedLiters['SUP-03'] ?? 0.0) + (plan.allocatedLiters['SUP-04'] ?? 0.0);
      expect(buffaloLiters, greaterThan(500.0));
    });

    test('3. Reliability penalty discourages unreliable suppliers', () {
      final suppliers = [
        const MilkSupplier(
          id: 'RELIABLE',
          name: 'Reliable Co-op',
          maxLiters: 1000.0,
          pricePerLiter: 40.0,
          fatPercentage: 4.0,
          snfPercentage: 8.5,
          distanceKm: 20.0,
          reliability: 1.0,
        ),
        const MilkSupplier(
          id: 'UNRELIABLE',
          name: 'Flaky Supplier',
          maxLiters: 1000.0,
          pricePerLiter: 39.5, // Slightly cheaper but very unreliable
          fatPercentage: 4.0,
          snfPercentage: 8.5,
          distanceKm: 20.0,
          reliability: 0.20,
        ),
      ];

      final optimizer = QuantumProcurementOptimizer(suppliers);
      final target = const ProcurementTarget(
        targetLiters: 800.0,
        minFatPercentage: 3.8,
        minSnfPercentage: 8.3,
        maxBudget: 50000.0,
      );

      final plan = optimizer.optimize(target, iterations: 400, seed: 303);

      expect((plan.allocatedLiters['RELIABLE'] ?? 0.0), greaterThan(plan.allocatedLiters['UNRELIABLE'] ?? 0.0));
    });

    test('4. Empty supplier list returns safe empty result', () {
      final optimizer = QuantumProcurementOptimizer([]);
      final target = const ProcurementTarget(
        targetLiters: 500.0,
        minFatPercentage: 4.0,
        minSnfPercentage: 8.5,
        maxBudget: 30000.0,
      );

      final plan = optimizer.optimize(target);
      expect(plan.allocatedLiters, isEmpty);
      expect(plan.totalProcuredLiters, equals(0.0));
      expect(plan.targetMet, isFalse);
    });

    test('5. Distance penalty favors closer suppliers when other parameters match', () {
      final suppliers = [
        const MilkSupplier(
          id: 'NEARBY',
          name: 'Nearby Farm',
          maxLiters: 600.0,
          pricePerLiter: 40.0,
          fatPercentage: 4.0,
          snfPercentage: 8.5,
          distanceKm: 5.0,
        ),
        const MilkSupplier(
          id: 'FAR_AWAY',
          name: 'Distant Farm',
          maxLiters: 600.0,
          pricePerLiter: 40.0,
          fatPercentage: 4.0,
          snfPercentage: 8.5,
          distanceKm: 120.0,
        ),
      ];

      final optimizer = QuantumProcurementOptimizer(suppliers);
      final target = const ProcurementTarget(
        targetLiters: 500.0,
        minFatPercentage: 3.8,
        minSnfPercentage: 8.3,
        maxBudget: 30000.0,
      );

      final plan = optimizer.optimize(target, iterations: 400, seed: 404);
      expect((plan.allocatedLiters['NEARBY'] ?? 0.0), greaterThan(plan.allocatedLiters['FAR_AWAY'] ?? 0.0));
    });
  });
}
