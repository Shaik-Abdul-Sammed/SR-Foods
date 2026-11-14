import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/domain/quantity.dart';
import 'package:sr_foods/core/domain/recipe.dart';
import 'package:sr_foods/core/services/fefo_inventory_service.dart';

void main() {
  group('Black Box Testing: Equivalence Partitioning & Boundary Value Analysis', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('FEFO Allocation Boundary: Zero and Negative quantity requests', () async {
      final zeroRes = await FefoInventoryService.instance.allocateBatches(
        db: db,
        productId: 1,
        requestedPacks: 0,
      );
      expect(zeroRes.isFullyAllocated, isTrue);
      expect(zeroRes.totalAllocated, 0);

      final negRes = await FefoInventoryService.instance.allocateBatches(
        db: db,
        productId: 1,
        requestedPacks: -15,
      );
      expect(negRes.isFullyAllocated, isTrue);
      expect(negRes.totalAllocated, 0);
    });

    test('FEFO Allocation Boundary: Requested stock exceeds available batches', () async {
      // Fetch seeded product (SRF-BRD-001 / SRF-HBP-001)
      final product = await (db.select(db.products)
            ..where((p) => p.sku.isIn(['SRF-BRD-001', 'SRF-HBP-001'])))
          .getSingle();
      final productId = product.id;

      await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'PB-PAR-001',
          productId: productId,
          operatorName: 'Subhani',
          quantityProduced: 20,
          manufacturingDate: DateTime.now(),
          status: const Value('completed'),
        ),
      );

      // Customer asks for 50 packs (deficit of 30)
      final res = await FefoInventoryService.instance.allocateBatches(
        db: db,
        productId: productId,
        requestedPacks: 50,
      );

      expect(res.isFullyAllocated, isFalse);
      expect(res.totalAllocated, 20);
      expect(res.unfulfilledPacks, 30);
      expect(res.batchSummaryString, contains('PB-PAR-001 (20 pk)'));
    });

    test('BOM Cost Guardrail: Selling below cost produces negative margin flag', () {
      final recipe = StandardRecipes.parotaRecipe;
      // Normal price ₹100 -> positive margin
      expect(recipe.computeGrossMargin(100.0, 100), greaterThan(50.0));

      // Heavily discounted price ₹20 (less than ₹31 BOM cost) -> negative margin
      final belowCostMargin = recipe.computeGrossMargin(20.0, 100);
      expect(belowCostMargin, lessThan(0.0));
      expect(belowCostMargin, closeTo(-55.1, 1.0));
    });

    test('Money Black Box: Exact Paise conversion prevents IEEE-754 drift', () {
      // In standard double arithmetic, 0.1 + 0.2 = 0.30000000000000004
      // In Money integer arithmetic:
      final m1 = Money.fromRupees(0.10); // 10 paise
      final m2 = Money.fromRupees(0.20); // 20 paise
      final sum = m1 + m2;
      expect(sum.paise, 30);
      expect(sum.inRupees, 0.30);
      expect(sum.formatted, '₹0.30');
    });

    test('Quantity Unit Type-Safety: Cross-category addition rejected at runtime', () {
      final flourKg = const Quantity(10, ProductUnit.kg);
      final oilLiters = const Quantity(5, ProductUnit.liter);
      final bags = const Quantity(100, ProductUnit.piece);

      // Mass + Volume -> ArgumentError
      expect(() => flourKg + oilLiters, throwsArgumentError);

      // Mass + Count -> ArgumentError
      expect(() => flourKg + bags, throwsArgumentError);
    });
  });
}
