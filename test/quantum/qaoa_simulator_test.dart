// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/qaoa_simulator.dart';

void main() {
  group('QaoaSimulator Tests (Quantum-Inspired Classical)', () {
    test('1. 2-qubit single edge finds maximal cut of 1.0', () {
      final sim = QaoaSimulator(
        numQubits: 2,
        edges: [const QaoaEdge(0, 1)],
      );

      final result = sim.optimize(gridSteps: 15);
      expect(result.maxCutValue, equals(1.0));
      expect(result.bestBitstring[0], isNot(equals(result.bestBitstring[1])));
    });

    test('2. 3-qubit triangle graph reaches maximum cut of 2.0', () {
      final sim = QaoaSimulator(
        numQubits: 3,
        edges: [
          const QaoaEdge(0, 1),
          const QaoaEdge(1, 2),
          const QaoaEdge(0, 2),
        ],
      );

      final result = sim.optimize(gridSteps: 15);
      expect(result.maxCutValue, equals(2.0));
      expect(result.expectedCutValue, greaterThan(1.2));
    });

    test('3. 4-qubit square/cycle graph C4 reaches maximal cut of 4.0', () {
      final sim = QaoaSimulator(
        numQubits: 4,
        edges: [
          const QaoaEdge(0, 1),
          const QaoaEdge(1, 2),
          const QaoaEdge(2, 3),
          const QaoaEdge(3, 0),
        ],
      );

      final result = sim.optimize(gridSteps: 16);
      expect(result.maxCutValue, equals(4.0));
      // Bipartite alternating partition [0, 1, 0, 1] or [1, 0, 1, 0]
      expect(result.bestBitstring[0], equals(result.bestBitstring[2]));
      expect(result.bestBitstring[1], equals(result.bestBitstring[3]));
      expect(result.bestBitstring[0], isNot(equals(result.bestBitstring[1])));
    });

    test('4. Variational parameter optimization yields expected cut > random baseline', () {
      final sim = QaoaSimulator(
        numQubits: 4,
        edges: [
          const QaoaEdge(0, 1, 2.0),
          const QaoaEdge(1, 2, 1.5),
          const QaoaEdge(2, 3, 3.0),
        ],
      );

      final baselineCut = sim.evaluateExpectation(0.0, 0.0);
      final result = sim.optimize(gridSteps: 12);

      expect(result.expectedCutValue, greaterThan(baselineCut));
    });

    test('5. Top sample probabilities correctly populated for significant amplitudes', () {
      final sim = QaoaSimulator(
        numQubits: 3,
        edges: [const QaoaEdge(0, 1), const QaoaEdge(1, 2)],
      );

      final result = sim.optimize(gridSteps: 12);
      expect(result.topSampleProbabilities, isNotEmpty);
      for (final prob in result.topSampleProbabilities.values) {
        expect(prob, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
