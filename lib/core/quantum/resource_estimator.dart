// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:math' as math;

enum QuantumAlgorithmType {
  isingAnnealing,
  qaoaMaxCut,
  groverSearch,
  vrpQubo,
}

/// Estimates physical vs logical quantum hardware requirements for target algorithms.
class QuantumResourceEstimate {
  final QuantumAlgorithmType algorithm;
  final int problemSize;
  final int logicalQubits;
  final int physicalQubits;
  final int surfaceCodeDistance;
  final int tGateCount;
  final int cnotGateCount;
  final int totalCircuitDepth;
  final double estimatedQpuExecutionMs;
  final double classicalSimulatedRamMb;

  const QuantumResourceEstimate({
    required this.algorithm,
    required this.problemSize,
    required this.logicalQubits,
    required this.physicalQubits,
    required this.surfaceCodeDistance,
    required this.tGateCount,
    required this.cnotGateCount,
    required this.totalCircuitDepth,
    required this.estimatedQpuExecutionMs,
    required this.classicalSimulatedRamMb,
  });

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm.name,
        'problemSize': problemSize,
        'logicalQubits': logicalQubits,
        'physicalQubits': physicalQubits,
        'surfaceCodeDistance': surfaceCodeDistance,
        'tGateCount': tGateCount,
        'cnotGateCount': cnotGateCount,
        'totalCircuitDepth': totalCircuitDepth,
        'estimatedQpuExecutionMs': estimatedQpuExecutionMs,
        'classicalSimulatedRamMb': classicalSimulatedRamMb,
      };
}

/// Quantum Resource Estimator for Enterprise Operations.
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Projects physical fault-tolerant quantum computing requirements (surface codes,
/// magic-state distillation, and T-depth) compared to current on-device classical simulation.
class QuantumResourceEstimator {
  final double physicalErrorRate; // e.g. 1e-3 (0.1%)
  final double codeThreshold; // e.g. 1e-2 (1%)
  final double targetFailureRate; // e.g. 1e-6

  const QuantumResourceEstimator({
    this.physicalErrorRate = 0.001,
    this.codeThreshold = 0.01,
    this.targetFailureRate = 1e-6,
  });

  int _calculateSurfaceCodeDistance() {
    // d = 2 * floor( log(targetFailureRate) / log(physicalErrorRate / codeThreshold) ) + 1
    final ratio = physicalErrorRate / codeThreshold;
    final numerator = math.log(targetFailureRate);
    final denominator = math.log(ratio);
    final d = (2 * (numerator / denominator).abs().floor()) + 1;
    return math.max(3, d);
  }

  QuantumResourceEstimate estimate({
    required QuantumAlgorithmType algorithm,
    required int problemSize,
  }) {
    final d = _calculateSurfaceCodeDistance();
    final physicalPerLogical = 2 * d * d;

    int logicalQubits;
    int tGates;
    int cnots;
    int depth;

    switch (algorithm) {
      case QuantumAlgorithmType.isingAnnealing:
        logicalQubits = problemSize;
        tGates = 0; // Transverse field analog annealing
        cnots = problemSize * (problemSize - 1) ~/ 2;
        depth = problemSize * 10;
        break;

      case QuantumAlgorithmType.qaoaMaxCut:
        logicalQubits = problemSize;
        // p=1 layer: 2 * E CNOTs + single-qubit rotations (approx 50 T-gates per arbitrary rotation via Solovay-Kitaev)
        final edges = (problemSize * 1.5).round();
        cnots = 2 * edges;
        tGates = problemSize * 50;
        depth = 4 * edges;
        break;

      case QuantumAlgorithmType.groverSearch:
        logicalQubits = (math.log(problemSize) / math.ln2).ceil();
        final iterations = ((math.pi / 4.0) * math.sqrt(problemSize)).round();
        tGates = iterations * logicalQubits * 16;
        cnots = iterations * logicalQubits * 10;
        depth = iterations * logicalQubits * 8;
        break;

      case QuantumAlgorithmType.vrpQubo:
        // Binary encoding for stops x vehicles
        logicalQubits = problemSize * problemSize;
        cnots = logicalQubits * logicalQubits;
        tGates = logicalQubits * 40;
        depth = logicalQubits * 15;
        break;
    }

    final physicalQubits = logicalQubits * physicalPerLogical;
    // Estimated QPU gate time at 1 microsecond per surface code cycle
    final execMs = (depth * 0.001 * d).clamp(0.01, 10000.0);

    // Classical simulation RAM: 2^N * 16 bytes for state vector (capped at 20 qubits)
    final classicalRamMb = logicalQubits <= 24
        ? (math.pow(2, logicalQubits) * 16) / (1024 * 1024)
        : (logicalQubits * 0.5); // Heuristic memory for classical approximation

    return QuantumResourceEstimate(
      algorithm: algorithm,
      problemSize: problemSize,
      logicalQubits: logicalQubits,
      physicalQubits: physicalQubits,
      surfaceCodeDistance: d,
      tGateCount: tGates,
      cnotGateCount: cnots,
      totalCircuitDepth: depth,
      estimatedQpuExecutionMs: (execMs * 100.0).round() / 100.0,
      classicalSimulatedRamMb: (classicalRamMb * 100.0).round() / 100.0,
    );
  }
}
