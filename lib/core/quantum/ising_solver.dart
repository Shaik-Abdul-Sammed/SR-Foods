// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:math' as math;

/// Represents an Ising spin glass configuration and energy evaluation.
///
/// Hamiltonian: H(s) = - \sum_{i < j} J_{ij} s_i s_j - \sum_i h_i s_i
/// where s_i \in {-1, +1} are classical Ising spins.
class IsingModel {
  final int numSpins;
  final List<double> externalFields; // h_i
  final Map<int, double> couplings; // index: (i * numSpins + j) -> J_{ij}

  IsingModel({
    required this.numSpins,
    List<double>? externalFields,
    Map<int, double>? couplings,
  })  : externalFields = externalFields ?? List.filled(numSpins, 0.0),
        couplings = couplings ?? {};

  int _key(int i, int j) => i < j ? i * numSpins + j : j * numSpins + i;

  void setCoupling(int i, int j, double jVal) {
    if (i == j) return;
    couplings[_key(i, j)] = jVal;
  }

  double getCoupling(int i, int j) {
    if (i == j) return 0.0;
    return couplings[_key(i, j)] ?? 0.0;
  }

  /// Evaluates total classical Hamiltonian energy of spin configuration s \in {-1, +1}^N.
  double computeEnergy(List<int> spins) {
    double energy = 0.0;
    for (int i = 0; i < numSpins; i++) {
      energy -= externalFields[i] * spins[i];
    }
    for (final entry in couplings.entries) {
      final i = entry.key ~/ numSpins;
      final j = entry.key % numSpins;
      energy -= entry.value * spins[i] * spins[j];
    }
    return energy;
  }
}

/// Result of Transverse-Field Simulated Quantum Annealing.
class IsingSolution {
  final List<int> spins;
  final double energy;
  final int quantumTunnelingEvents;
  final int sweepsCompleted;

  const IsingSolution({
    required this.spins,
    required this.energy,
    required this.quantumTunnelingEvents,
    required this.sweepsCompleted,
  });
}

/// Simulated Transverse-Field Quantum Annealing (Path-Integral Monte Carlo) Solver.
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Employs Suzuki-Trotter decomposition mapping a 1D quantum spin system to a
/// (1+1)D classical Ising model with Trotter slices coupled in the imaginary time direction.
class TransverseFieldIsingSolver {
  final int trotterSlices; // M Trotter replicas
  final int numSweeps;
  final double initialGamma; // Transverse field Gamma_0
  final double finalGamma; // Transverse field Gamma_final -> 0
  final double temperature; // System temperature T

  TransverseFieldIsingSolver({
    this.trotterSlices = 8,
    this.numSweeps = 500,
    this.initialGamma = 3.0,
    this.finalGamma = 0.01,
    this.temperature = 0.5,
  });

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final e2x = math.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }

  IsingSolution solve(IsingModel model, {int? seed}) {
    final rand = math.Random(seed ?? 42);
    final n = model.numSpins;
    final m = trotterSlices;

    // Initialize M Trotter replicas randomly with +1 / -1 spins
    final state = List.generate(m, (_) => List.generate(n, (_) => rand.nextBool() ? 1 : -1));

    int tunnelingEvents = 0;

    for (int sweep = 0; sweep < numSweeps; sweep++) {
      final progress = sweep / numSweeps;
      // Annealing schedule: Transverse field Gamma decays, longitudinal classical field scales up
      final gamma = initialGamma * (1.0 - progress) + finalGamma * progress;
      final classicalWeight = progress;

      // Inter-slice coupling J_perp = -0.5 * T * ln(tanh(Gamma / (m * T)))
      final tanhArg = (gamma / (m * temperature)).clamp(1e-7, 10.0);
      final jPerp = -0.5 * temperature * math.log(_tanh(tanhArg));

      // Metropolis updates across all Trotter slices
      for (int k = 0; k < m; k++) {
        final prevSlice = (k - 1 + m) % m;
        final nextSlice = (k + 1) % m;

        for (int i = 0; i < n; i++) {
          final sIk = state[k][i];

          // Classical energy delta from in-slice neighbors and external field
          double classicalField = model.externalFields[i];
          for (int j = 0; j < n; j++) {
            if (i != j) {
              final jCoupling = model.getCoupling(i, j);
              if (jCoupling != 0.0) {
                classicalField += jCoupling * state[k][j];
              }
            }
          }
          final deltaEClassical = 2.0 * sIk * classicalField * (classicalWeight / m);

          // Quantum fluctuation delta from neighboring Trotter slices
          final sPrev = state[prevSlice][i];
          final sNext = state[nextSlice][i];
          final deltaEQuantum = 2.0 * sIk * jPerp * (sPrev + sNext);

          final totalDeltaE = deltaEClassical + deltaEQuantum;

          // Metropolis criterion
          if (totalDeltaE <= 0.0 || rand.nextDouble() < math.exp(-totalDeltaE / temperature)) {
            // Check if spin flip tunnels through classical energy barrier (deltaEClassical > 0)
            if (deltaEClassical > 0.0 && totalDeltaE <= 0.0) {
              tunnelingEvents++;
            }
            state[k][i] = -sIk;
          }
        }
      }
    }

    // Select the best Trotter slice with minimum classical energy
    List<int> bestSpins = state[0];
    double minEnergy = model.computeEnergy(bestSpins);

    for (int k = 1; k < m; k++) {
      final e = model.computeEnergy(state[k]);
      if (e < minEnergy) {
        minEnergy = e;
        bestSpins = state[k];
      }
    }

    return IsingSolution(
      spins: List.unmodifiable(bestSpins),
      energy: minEnergy,
      quantumTunnelingEvents: tunnelingEvents,
      sweepsCompleted: numSweeps,
    );
  }
}
