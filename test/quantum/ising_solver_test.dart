// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/ising_solver.dart';

void main() {
  group('TransverseFieldIsingSolver Tests (Quantum-Inspired Classical)', () {
    test('1. Ferromagnetic 2-spin system aligns both spins to minimize energy', () {
      final model = IsingModel(numSpins: 2);
      model.setCoupling(0, 1, 1.0); // J > 0 encourages s0 == s1

      final solver = TransverseFieldIsingSolver(
        trotterSlices: 4,
        numSweeps: 150,
      );
      final solution = solver.solve(model, seed: 101);

      expect(solution.spins[0], equals(solution.spins[1]));
      expect(solution.energy, equals(-1.0));
    });

    test('2. Antiferromagnetic coupling separates spins into antiparallel alignment', () {
      final model = IsingModel(numSpins: 2);
      model.setCoupling(0, 1, -1.0); // J < 0 encourages s0 != s1

      final solver = TransverseFieldIsingSolver(
        trotterSlices: 4,
        numSweeps: 150,
      );
      final solution = solver.solve(model, seed: 202);

      expect(solution.spins[0], isNot(equals(solution.spins[1])));
      expect(solution.energy, equals(-1.0));
    });

    test('3. Strong external magnetic field forces spin alignment with field', () {
      final model = IsingModel(
        numSpins: 3,
        externalFields: [5.0, -5.0, 5.0],
      );

      final solver = TransverseFieldIsingSolver(
        trotterSlices: 4,
        numSweeps: 100,
      );
      final solution = solver.solve(model, seed: 303);

      expect(solution.spins[0], equals(1));
      expect(solution.spins[1], equals(-1));
      expect(solution.spins[2], equals(1));
      expect(solution.energy, lessThanOrEqualTo(-15.0));
    });

    test('4. 10-spin 1D ring ferromagnetic system reaches ground state', () {
      const n = 10;
      final model = IsingModel(numSpins: n);
      for (int i = 0; i < n; i++) {
        model.setCoupling(i, (i + 1) % n, 1.0);
      }

      final solver = TransverseFieldIsingSolver(
        trotterSlices: 6,
        numSweeps: 250,
      );
      final solution = solver.solve(model, seed: 404);

      // All spins should be identical (+1 or -1) with ground state energy -10.0
      final first = solution.spins[0];
      for (final s in solution.spins) {
        expect(s, equals(first));
      }
      expect(solution.energy, equals(-10.0));
    });

    test('5. Quantum tunneling events occur during transverse-field annealing schedule', () {
      final model = IsingModel(
        numSpins: 8,
        externalFields: [1.0, -1.0, 1.0, -1.0, 0.5, -0.5, 0.2, -0.2],
      );
      for (int i = 0; i < 7; i++) {
        model.setCoupling(i, i + 1, -0.8);
      }

      final solver = TransverseFieldIsingSolver(
        trotterSlices: 8,
        numSweeps: 300,
        initialGamma: 4.0,
      );
      final solution = solver.solve(model, seed: 505);

      expect(solution.quantumTunnelingEvents, greaterThan(0));
      expect(solution.sweepsCompleted, equals(300));
    });
  });
}
