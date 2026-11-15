// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/grover_search.dart';

void main() {
  group('GroverSkuSearchEngine Tests (Quantum-Inspired Classical)', () {
    final sampleCatalog = [
      const SkuItem(skuCode: 'SRF-DAI-001', name: 'Standard Cow Milk 500ml', category: 'dairy', price: 28.0, shelfLifeDays: 2),
      const SkuItem(skuCode: 'SRF-DAI-002', name: 'Toned Milk 500ml', category: 'dairy', price: 26.0, shelfLifeDays: 2),
      const SkuItem(skuCode: 'SRF-DAI-003', name: 'Buffalo Milk 1L', category: 'dairy', price: 70.0, shelfLifeDays: 2),
      const SkuItem(skuCode: 'SRF-DAI-004', name: 'Organic A2 Milk 500ml', category: 'dairy', price: 45.0, shelfLifeDays: 3),
      const SkuItem(skuCode: 'SRF-BAK-001', name: 'Whole Wheat Bread 400g', category: 'bakery', price: 40.0, shelfLifeDays: 4),
      const SkuItem(skuCode: 'SRF-BAK-002', name: 'Gluten-Free Brown Bread', category: 'bakery', price: 65.0, shelfLifeDays: 5, isGlutenFree: true),
      const SkuItem(skuCode: 'SRF-BAK-003', name: 'Milk Bread 400g', category: 'bakery', price: 35.0, shelfLifeDays: 3),
      const SkuItem(skuCode: 'SRF-BAK-004', name: 'Vegan Multigrain Sourdough', category: 'bakery', price: 85.0, shelfLifeDays: 5, isVegan: true, isGlutenFree: true),
      const SkuItem(skuCode: 'SRF-FRO-001', name: 'Green Peas 500g', category: 'frozen', price: 60.0, shelfLifeDays: 180),
      const SkuItem(skuCode: 'SRF-FRO-002', name: 'Sweet Corn 500g', category: 'frozen', price: 65.0, shelfLifeDays: 180),
    ];

    test('1. Amplifies single target state probability well above 1/N baseline', () {
      final engine = GroverSkuSearchEngine(sampleCatalog);
      // Target: Gluten-free bread
      final result = engine.findSubstitutes(
        oraclePredicate: (item) => item.skuCode == 'SRF-BAK-002',
      );

      expect(result.matchedSkus.length, 1);
      expect(result.matchedSkus.first.skuCode, 'SRF-BAK-002');
      // Baseline 1/10 = 0.10; Grover amplified probability should be significantly higher
      expect(result.peakProbability, greaterThan(0.50));
    });

    test('2. Multiple target items amplify collective probability', () {
      final engine = GroverSkuSearchEngine(sampleCatalog);
      // Target: All dairy items under ₹30
      final result = engine.findSubstitutes(
        oraclePredicate: (item) => item.category == 'dairy' && item.price <= 30.0,
      );

      expect(result.matchedSkus.length, 2);
      expect(result.finalProbabilities.length, 2);
      for (final p in result.finalProbabilities) {
        expect(p, greaterThan(0.20));
      }
    });

    test('3. Empty match condition returns gracefully without errors', () {
      final engine = GroverSkuSearchEngine(sampleCatalog);
      final result = engine.findSubstitutes(
        oraclePredicate: (item) => item.price > 10000.0,
      );

      expect(result.matchedSkus, isEmpty);
      expect(result.peakProbability, equals(0.0));
      expect(result.optimalIterations, equals(0));
    });

    test('4. Successfully finds dietary/allergen compliant substitute', () {
      final engine = GroverSkuSearchEngine(sampleCatalog);
      // Scenario: Regular bread out of stock, customer requires vegan and gluten-free
      final result = engine.findSubstitutes(
        oraclePredicate: (item) => item.category == 'bakery' && item.isVegan && item.isGlutenFree,
      );

      expect(result.matchedSkus.length, 1);
      expect(result.matchedSkus.first.name, 'Vegan Multigrain Sourdough');
      expect(result.peakProbability, greaterThan(0.50));
    });

    test('5. Optimal iteration count corresponds to pi/4 * sqrt(N/M)', () {
      final engine = GroverSkuSearchEngine(sampleCatalog);
      final result = engine.findSubstitutes(
        oraclePredicate: (item) => item.category == 'frozen',
      );

      // N=10, M=2 => (pi/4) * sqrt(5) = 0.785 * 2.236 ~= 1.75 => round to 2
      expect(result.optimalIterations, equals(2));
      expect(result.totalEvaluations, equals(20));
    });
  });
}
