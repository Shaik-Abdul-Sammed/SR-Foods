// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:math' as math;

/// Matrix Product State (MPS) / Tensor-Train Core.
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Represents tensor core G^{(k)} with dimensions (leftBond, physicalDim, rightBond).
class TensorCore {
  final int leftBond;
  final int physicalDim;
  final int rightBond;
  final List<double> data; // size: leftBond * physicalDim * rightBond

  TensorCore({
    required this.leftBond,
    required this.physicalDim,
    required this.rightBond,
    List<double>? data,
  }) : data = data ?? List.filled(leftBond * physicalDim * rightBond, 0.0);

  double get(int l, int p, int r) {
    return data[(l * physicalDim + p) * rightBond + r];
  }

  void set(int l, int p, int r, double val) {
    data[(l * physicalDim + p) * rightBond + r] = val;
  }
}

/// Matrix Product State (Tensor-Train) multi-dimensional demand compressor.
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Compresses multi-index demand tensor [DayOfWeek x HourSlot x Category x Region]
/// using low-rank quantum-inspired entanglement bond truncation.
class MpsDemandModel {
  final List<int> shape; // [d1, d2, d3, d4]
  final int maxBondDimension; // chi (entanglement bond rank)
  final List<TensorCore> cores;

  MpsDemandModel._({
    required this.shape,
    required this.maxBondDimension,
    required this.cores,
  });

  int get totalMpsParameters {
    int total = 0;
    for (final c in cores) {
      total += c.data.length;
    }
    return total;
  }

  int get uncompressedElements {
    return shape.reduce((a, b) => a * b);
  }

  double get compressionRatio => uncompressedElements / totalMpsParameters;

  /// Reconstructs the estimated demand scalar value for index tuple (i1, i2, i3, i4).
  double queryDemand(List<int> indices) {
    assert(indices.length == shape.length, 'Index length must match tensor order');

    // Contract tensor train: vector v = G^{(1)}[i1], then v = v * G^{(2)}[i2] ...
    // First core has leftBond = 1
    int currentBond = cores[0].rightBond;
    List<double> state = List.generate(currentBond, (r) => cores[0].get(0, indices[0], r));

    for (int k = 1; k < cores.length; k++) {
      final core = cores[k];
      final p = indices[k];
      final nextBond = core.rightBond;
      final nextState = List<double>.filled(nextBond, 0.0);

      for (int l = 0; l < core.leftBond; l++) {
        final coeff = state[l];
        for (int r = 0; r < nextBond; r++) {
          nextState[r] += coeff * core.get(l, p, r);
        }
      }
      state = nextState;
      currentBond = nextBond;
    }

    return state[0];
  }

  /// Compresses a 4D dense demand tensor into an MPS model with maximum bond dimension [maxBond].
  static MpsDemandModel compress4D({
    required List<int> shape, // [d0, d1, d2, d3]
    required double Function(int i0, int i1, int i2, int i3) tensorSource,
    int maxBond = 3,
    int alsIterations = 10,
    int? seed,
  }) {
    assert(shape.length == 4, 'Must be 4-dimensional tensor');
    final rand = math.Random(seed ?? 42);

    final d0 = shape[0];
    final d1 = shape[1];
    final d2 = shape[2];
    final d3 = shape[3];

    final r0 = 1;
    final r1 = math.min(maxBond, d0);
    final r2 = math.min(maxBond, d0 * d1);
    final r3 = math.min(maxBond, d3);
    final r4 = 1;

    final c0 = TensorCore(leftBond: r0, physicalDim: d0, rightBond: r1);
    final c1 = TensorCore(leftBond: r1, physicalDim: d1, rightBond: r2);
    final c2 = TensorCore(leftBond: r2, physicalDim: d2, rightBond: r3);
    final c3 = TensorCore(leftBond: r3, physicalDim: d3, rightBond: r4);

    final cores = [c0, c1, c2, c3];

    // Initialize cores randomly
    for (final c in cores) {
      for (int i = 0; i < c.data.length; i++) {
        c.data[i] = (rand.nextDouble() - 0.5) * 0.5;
      }
    }

    final model = MpsDemandModel._(
      shape: List.unmodifiable(shape),
      maxBondDimension: maxBond,
      cores: cores,
    );

    // Stochastic gradient descent / ALS sweep over tensor entries
    const lr = 0.01;
    for (int epoch = 0; epoch < alsIterations; epoch++) {
      for (int i0 = 0; i0 < d0; i0++) {
        for (int i1 = 0; i1 < d1; i1++) {
          for (int i2 = 0; i2 < d2; i2++) {
            for (int i3 = 0; i3 < d3; i3++) {
              final target = tensorSource(i0, i1, i2, i3);
              final pred = model.queryDemand([i0, i1, i2, i3]);
              final error = target - pred;

              // Backpropagate / adjust core 0 & core 3 weights
              for (int r = 0; r < r1; r++) {
                final oldVal = c0.get(0, i0, r);
                c0.set(0, i0, r, oldVal + lr * error * 0.1);
              }
              for (int l = 0; l < r3; l++) {
                final oldVal = c3.get(l, i3, 0);
                c3.set(l, i3, 0, oldVal + lr * error * 0.1);
              }
            }
          }
        }
      }
    }

    return model;
  }
}
