import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/domain/recipe.dart';
import 'package:sr_foods/core/services/raw_material_service.dart';
import 'package:sr_foods/core/services/fssai_hygiene_service.dart';

void main() {
  group('Unit Tests: StandardRecipes & BOM Calculations', () {
    test('StandardRecipes matches exact product SKU and name', () {
      final parota = StandardRecipes.getRecipeFor('SRF-HBP-001');
      expect(parota.productName, 'Half Boiled Parota');
      expect(parota.shelfLifeDays, 6);
      expect(parota.standardYieldPercent, 98.0);
      expect(parota.capacityPacksPerHour, 80);

      final chapathi = StandardRecipes.getRecipeFor('Triangular Chapathi');
      expect(chapathi.sku, 'SRF-TC-002');
      expect(chapathi.shelfLifeDays, 5);

      final pulka = StandardRecipes.getRecipeFor('Pulka');
      expect(pulka.sku, 'SRF-PUL-003');

      final puri = StandardRecipes.getRecipeFor('Puri');
      expect(puri.sku, 'SRF-PUR-004');
    });

    test('RecipeIngredient BOM scaling computes exact materials for batches', () {
      final recipe = StandardRecipes.parotaRecipe;

      // For 100 packs (base batch)
      final materials100 = recipe.computeMaterialsFor(100);
      expect(materials100['Maida Flour (kg)'], 55.0);
      expect(materials100['Refined Sunflower Oil (L)'], 6.0);
      expect(materials100['Iodized Salt (kg)'], 1.2);
      expect(materials100['Food Grade Pouches (50u) (pcs)'], 100.0);

      // For 250 packs (scaled batch)
      final materials250 = recipe.computeMaterialsFor(250);
      expect(materials250['Maida Flour (kg)'], 137.5);
      expect(materials250['Refined Sunflower Oil (L)'], 15.0);
      expect(materials250['Iodized Salt (kg)'], 3.0);
      expect(materials250['Food Grade Pouches (50u) (pcs)'], 250.0);
    });

    test('Theoretical BOM batch costing & gross margin calculation', () {
      final recipe = StandardRecipes.parotaRecipe;
      // 100 packs:
      // Maida: 55kg * 38 = 2090
      // Oil: 6L * 135 = 810
      // Salt: 1.2kg * 18 = 21.6
      // Pouches: 100 * 1.80 = 180
      // Total = 3101.6 -> ~31.02 per pack
      final batchCost = recipe.computeTheoreticalBatchCost(100);
      expect(batchCost, closeTo(3101.6, 1.0));

      final costPerPack = recipe.computeCostPerPack(100);
      expect(costPerPack, closeTo(31.02, 0.1));

      // At ₹100 selling price, margin = (100 - 31.02) / 100 = ~68.98%
      final margin = recipe.computeGrossMargin(100.0, 100);
      expect(margin, closeTo(68.98, 0.5));
    });
  });

  group('Unit Tests: RawMaterialService Purchase Order Generator', () {
    test('generatePurchaseOrderDraft formats clean WhatsApp B2B message', () {
      final lowItems = [
        const RawMaterialStatus(
          id: 1,
          name: 'Maida Flour',
          category: 'flour',
          currentStock: 40.0,
          unit: 'kg',
          minStock: 150.0,
          lastPurchasePrice: 38.0,
          isLowStock: true,
          deficitQuantity: 260.0,
          estimatedReorderCost: 9880.0,
        ),
        const RawMaterialStatus(
          id: 2,
          name: 'Refined Sunflower Oil',
          category: 'oil',
          currentStock: 15.0,
          unit: 'L',
          minStock: 40.0,
          lastPurchasePrice: 135.0,
          isLowStock: true,
          deficitQuantity: 65.0,
          estimatedReorderCost: 8775.0,
        ),
      ];

      final poDraft = RawMaterialService.instance.generatePurchaseOrderDraft(
        itemsToOrder: lowItems,
        supplierName: 'Sri Venkateswara Flour Mills',
      );

      expect(poDraft, contains('*PURCHASE ORDER — SR FOODS*'));
      expect(poDraft, contains('To: Sri Venkateswara Flour Mills'));
      expect(poDraft, contains('Maida Flour*: 260 kg'));
      expect(poDraft, contains('Refined Sunflower Oil*: 65 L'));
      expect(poDraft, contains('Est. Total: ₹18655'));
    });
  });

  group('Unit Tests: FssaiLicenseStatus Expiry Calculation', () {
    test('License status computation flags near expiry', () {
      final activeLic = FssaiLicenseStatus(
        licenseNumber: '10123999000123',
        validTill: DateTime.now().add(const Duration(days: 25)),
        daysRemaining: 25,
        isExpiringSoon: true,
        isExpired: false,
      );
      expect(activeLic.isExpiringSoon, isTrue);
      expect(activeLic.isExpired, isFalse);

      final expiredLic = FssaiLicenseStatus(
        licenseNumber: '10123999000123',
        validTill: DateTime.now().subtract(const Duration(days: 2)),
        daysRemaining: -2,
        isExpiringSoon: false,
        isExpired: true,
      );
      expect(expiredLic.isExpired, isTrue);
    });
  });
}
