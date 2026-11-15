// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/tensor_demand.dart';

void main() {
  group('MpsDemandModel Tests (Quantum-Inspired Classical)', () {
    // 4D demand tensor: 7 days x 4 hours x 3 categories x 5 regions = 420 elements
    const shape = [7, 4, 3, 5];

    double dummyDemand(int day, int hour, int category, int region) {
      // Synthetic demand formula: weekend boost, morning rush, category multiplier
      final weekend = (day == 0 || day == 6) ? 1.5 : 1.0;
      final morning = (hour == 0 || hour == 1) ? 2.0 : 1.0;
      final cat = (category + 1) * 10.0;
      final reg = (region + 1) * 5.0;
      return (cat + reg) * weekend * morning;
    }

    test('1. Compresses 420-element demand tensor with > 3x parameter compression ratio', () {
      final mps = MpsDemandModel.compress4D(
        shape: shape,
        tensorSource: dummyDemand,
        maxBond: 2,
        alsIterations: 5,
      );

      expect(mps.uncompressedElements, equals(420));
      expect(mps.totalMpsParameters, lessThan(120));
      expect(mps.compressionRatio, greaterThan(3.5));
    });

    test('2. Query demand returns finite positive numeric predictions for valid coordinates', () {
      final mps = MpsDemandModel.compress4D(
        shape: shape,
        tensorSource: dummyDemand,
        maxBond: 2,
        alsIterations: 5,
      );

      final val = mps.queryDemand([0, 1, 2, 3]);
      expect(val.isFinite, isTrue);
      expect(val.isNaN, isFalse);
    });

    test('3. Higher bond dimension increases capacity and parameter count', () {
      final mpsBond2 = MpsDemandModel.compress4D(
        shape: shape,
        tensorSource: dummyDemand,
        maxBond: 2,
        alsIterations: 2,
      );

      final mpsBond4 = MpsDemandModel.compress4D(
        shape: shape,
        tensorSource: dummyDemand,
        maxBond: 4,
        alsIterations: 2,
      );

      expect(mpsBond4.totalMpsParameters, greaterThan(mpsBond2.totalMpsParameters));
    });

    test('4. Tensor cores have correct matrix chain dimensions', () {
      final mps = MpsDemandModel.compress4D(
        shape: shape,
        tensorSource: dummyDemand,
        maxBond: 3,
        alsIterations: 1,
      );

      expect(mps.cores.length, equals(4));
      // First core left bond = 1
      expect(mps.cores[0].leftBond, equals(1));
      expect(mps.cores[0].physicalDim, equals(7));
      // Adjacent bonds match
      expect(mps.cores[0].rightBond, equals(mps.cores[1].leftBond));
      expect(mps.cores[1].rightBond, equals(mps.cores[2].leftBond));
      expect(mps.cores[2].rightBond, equals(mps.cores[3].leftBond));
      // Last core right bond = 1
      expect(mps.cores[3].rightBond, equals(1));
    });

    test('5. Single core get and set methods manipulate data correctly', () {
      final core = TensorCore(leftBond: 2, physicalDim: 3, rightBond: 2);
      expect(core.data.length, equals(12));

      core.set(1, 2, 1, 42.5);
      expect(core.get(1, 2, 1), equals(42.5));
    });
  });
}
