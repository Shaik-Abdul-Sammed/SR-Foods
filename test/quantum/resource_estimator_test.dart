// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/resource_estimator.dart';

void main() {
  group('QuantumResourceEstimator Tests (Quantum-Inspired Classical)', () {
    const estimator = QuantumResourceEstimator();

    test('1. Surface code distance is calculated with minimum d >= 3', () {
      final estimate = estimator.estimate(
        algorithm: QuantumAlgorithmType.qaoaMaxCut,
        problemSize: 10,
      );

      expect(estimate.surfaceCodeDistance, greaterThanOrEqualTo(3));
      expect(estimate.physicalQubits, greaterThan(estimate.logicalQubits));
    });

    test('2. QAOA estimates logical qubits equal to node count with non-zero T-gates', () {
      final estimate = estimator.estimate(
        algorithm: QuantumAlgorithmType.qaoaMaxCut,
        problemSize: 12,
      );

      expect(estimate.logicalQubits, equals(12));
      expect(estimate.tGateCount, greaterThan(0));
      expect(estimate.cnotGateCount, greaterThan(0));
      expect(estimate.classicalSimulatedRamMb, lessThan(10.0));
    });

    test('3. Grover search estimates logarithmic logical qubit scaling', () {
      final estimate16 = estimator.estimate(
        algorithm: QuantumAlgorithmType.groverSearch,
        problemSize: 16,
      );
      final estimate256 = estimator.estimate(
        algorithm: QuantumAlgorithmType.groverSearch,
        problemSize: 256,
      );

      expect(estimate16.logicalQubits, equals(4));
      expect(estimate256.logicalQubits, equals(8));
      expect(estimate256.totalCircuitDepth, greaterThan(estimate16.totalCircuitDepth));
    });

    test('4. VRP QUBO scales quadratic logical qubits with problem size', () {
      final estimate = estimator.estimate(
        algorithm: QuantumAlgorithmType.vrpQubo,
        problemSize: 10,
      );

      expect(estimate.logicalQubits, equals(100)); // 10 * 10
      expect(estimate.physicalQubits, greaterThan(10000));
    });

    test('5. toJson serializes all resource fields accurately', () {
      final estimate = estimator.estimate(
        algorithm: QuantumAlgorithmType.isingAnnealing,
        problemSize: 20,
      );

      final json = estimate.toJson();
      expect(json['algorithm'], equals('isingAnnealing'));
      expect(json['problemSize'], equals(20));
      expect(json['logicalQubits'], equals(20));
      expect(json['physicalQubits'], isNotNull);
      expect(json['surfaceCodeDistance'], isNotNull);
    });
  });
}
