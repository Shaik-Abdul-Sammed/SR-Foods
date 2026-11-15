// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:math' as math;

/// Represents an edge in a graph for MAX-CUT optimization.
class QaoaEdge {
  final int u;
  final int v;
  final double weight;

  const QaoaEdge(this.u, this.v, [this.weight = 1.0]);
}

/// Result of QAOA classical simulation.
class QaoaResult {
  final List<int> bestBitstring; // e.g. [0, 1, 0, 1]
  final double maxCutValue;
  final double expectedCutValue;
  final double optimalGamma;
  final double optimalBeta;
  final Map<String, double> topSampleProbabilities;

  const QaoaResult({
    required this.bestBitstring,
    required this.maxCutValue,
    required this.expectedCutValue,
    required this.optimalGamma,
    required this.optimalBeta,
    required this.topSampleProbabilities,
  });
}

/// Classical State-Vector Simulator for Quantum Approximate Optimization Algorithm (QAOA).
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Simulates unitary quantum state evolution on MAX-CUT problems up to N <= 20 qubits.
class QaoaSimulator {
  final int numQubits;
  final List<QaoaEdge> edges;
  final int pLayers;

  QaoaSimulator({
    required this.numQubits,
    required this.edges,
    this.pLayers = 1,
  }) : assert(numQubits <= 20, 'State-vector simulation limited to N <= 20 qubits for classical RAM bounds');

  /// Evaluates cut value for a binary string of length N (0 or 1 per node).
  double evaluateCut(int stateIndex) {
    double cut = 0.0;
    for (final edge in edges) {
      final bitU = (stateIndex >> edge.u) & 1;
      final bitV = (stateIndex >> edge.v) & 1;
      if (bitU != bitV) {
        cut += edge.weight;
      }
    }
    return cut;
  }

  /// Classical simulation of QAOA state preparation and expectation value evaluation.
  double evaluateExpectation(double gamma, double beta) {
    final dim = 1 << numQubits;
    final initialAmp = 1.0 / math.sqrt(dim);

    // Initial state |+>^N: real part = 1/sqrt(2^N), imag part = 0
    final real = List.filled(dim, initialAmp);
    final imag = List.filled(dim, 0.0);

    for (int layer = 0; layer < pLayers; layer++) {
      // 1. Cost unitary U(C, gamma) = exp(-i * gamma * C)
      for (int i = 0; i < dim; i++) {
        final cVal = evaluateCut(i);
        final angle = -gamma * cVal;
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);

        final r = real[i];
        final im = imag[i];
        real[i] = r * cosA - im * sinA;
        imag[i] = r * sinA + im * cosA;
      }

      // 2. Mixer unitary U(B, beta) = prod_j exp(-i * beta * X_j)
      final cosB = math.cos(beta);
      final sinB = math.sin(beta);

      for (int j = 0; j < numQubits; j++) {
        final mask = 1 << j;
        for (int i = 0; i < dim; i++) {
          if ((i & mask) == 0) {
            final pair = i | mask;

            final r0 = real[i];
            final im0 = imag[i];
            final r1 = real[pair];
            final im1 = imag[pair];

            // exp(-i beta X) = [ [cos(beta), -i sin(beta)], [-i sin(beta), cos(beta)] ]
            // [r0_new, im0_new] = cosB * [r0, im0] - i sinB * [r1, im1]
            // -i * (r1 + i im1) = im1 - i r1
            real[i] = cosB * r0 + sinB * im1;
            imag[i] = cosB * im0 - sinB * r1;

            real[pair] = cosB * r1 + sinB * im0;
            imag[pair] = cosB * im1 - sinB * r0;
          }
        }
      }
    }

    // Expectation value <psi| C |psi> = sum_i |psi[i]|^2 * C(i)
    double expectedCut = 0.0;
    for (int i = 0; i < dim; i++) {
      final prob = real[i] * real[i] + imag[i] * imag[i];
      expectedCut += prob * evaluateCut(i);
    }

    return expectedCut;
  }

  /// Executes variational optimization over (gamma, beta) and measures output distribution.
  QaoaResult optimize({int gridSteps = 20}) {
    double bestExpected = -1e9;
    double bestGamma = 0.0;
    double bestBeta = 0.0;

    // Grid search over gamma in [0, 2pi) and beta in [0, pi)
    for (int g = 0; g < gridSteps; g++) {
      final gamma = (g / gridSteps) * 2.0 * math.pi;
      for (int b = 0; b < gridSteps; b++) {
        final beta = (b / gridSteps) * math.pi;
        final expVal = evaluateExpectation(gamma, beta);
        if (expVal > bestExpected) {
          bestExpected = expVal;
          bestGamma = gamma;
          bestBeta = beta;
        }
      }
    }

    // Reconstruct state at optimal parameters to find bitstring with highest probability and cut
    final dim = 1 << numQubits;
    final initialAmp = 1.0 / math.sqrt(dim);
    final real = List.filled(dim, initialAmp);
    final imag = List.filled(dim, 0.0);

    // Apply optimal layer
    for (int i = 0; i < dim; i++) {
      final angle = -bestGamma * evaluateCut(i);
      final r = real[i];
      final im = imag[i];
      real[i] = r * math.cos(angle) - im * math.sin(angle);
      imag[i] = r * math.sin(angle) + im * math.cos(angle);
    }

    final cosB = math.cos(bestBeta);
    final sinB = math.sin(bestBeta);
    for (int j = 0; j < numQubits; j++) {
      final mask = 1 << j;
      for (int i = 0; i < dim; i++) {
        if ((i & mask) == 0) {
          final pair = i | mask;
          final r0 = real[i];
          final im0 = imag[i];
          final r1 = real[pair];
          final im1 = imag[pair];

          real[i] = cosB * r0 + sinB * im1;
          imag[i] = cosB * im0 - sinB * r1;

          real[pair] = cosB * r1 + sinB * im0;
          imag[pair] = cosB * im1 - sinB * r0;
        }
      }
    }

    int bestState = 0;
    double highestProb = -1.0;
    final probMap = <String, double>{};

    for (int i = 0; i < dim; i++) {
      final prob = real[i] * real[i] + imag[i] * imag[i];
      final bitStr = i.toRadixString(2).padLeft(numQubits, '0');
      if (prob > 0.05) {
        probMap[bitStr] = prob;
      }
      if (prob > highestProb) {
        highestProb = prob;
        bestState = i;
      }
    }

    final bestBitstring = List.generate(numQubits, (j) => (bestState >> j) & 1);
    final maxCut = evaluateCut(bestState);

    return QaoaResult(
      bestBitstring: bestBitstring,
      maxCutValue: maxCut,
      expectedCutValue: bestExpected,
      optimalGamma: bestGamma,
      optimalBeta: bestBeta,
      topSampleProbabilities: probMap,
    );
  }
}
