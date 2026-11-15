import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/pdf/bakery_label_generator.dart';

void main() {
  const generator = BakeryLabelGenerator();

  group('Bakery Label Generator PDF Tests (4 SKUs)', () {
    test('1. Sourdough Artisan Bread label renders valid PDF', () async {
      final now = DateTime(2026, 11, 20, 6, 0);
      final data = BakeryLabelData(
        sku: 'BAKE-BRD-SOUR-01',
        productName: 'San Francisco Sourdough Loaf 400g',
        batchNumber: 'BATCH-SOUR-202611-01',
        bakedAt: now,
        freshnessUntil: now.add(const Duration(hours: 36)),
        netWeight: '400 g',
        containsEgg: false,
        allergens: const ['Wheat / Gluten'],
        ovenId: 'DECK-OVEN-01',
        fssaiCategoryCode: 'FCS 07.1 (Breads and Rolls)',
        ingredients: const ['Unbleached Wheat Flour', 'Wild Yeast Culture', 'Purified Water', 'Sea Salt'],
      );

      final pdfBytes = await generator.generateBakeryLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('2. Belgian Chocolate Layer Cake label renders valid PDF with allergens', () async {
      final now = DateTime(2026, 11, 20, 10, 0);
      final data = BakeryLabelData(
        sku: 'BAKE-CAKE-CHOC-02',
        productName: 'Belgian Dark Truffle Cake 500g',
        batchNumber: 'BATCH-CHOC-202611-04',
        bakedAt: now,
        freshnessUntil: now.add(const Duration(hours: 48)),
        netWeight: '500 g',
        containsEgg: true,
        allergens: const ['Wheat / Gluten', 'Dairy', 'Eggs', 'Soy (Lecithin)'],
        ovenId: 'ROTARY-02',
        fssaiCategoryCode: 'FCS 07.2 (Fine Bakery Wares)',
        storageAdvice: 'Refrigerate at 2°C to 8°C. Serve at room temperature.',
        ingredients: const [
          'Dark Chocolate (55% Cocoa)',
          'Wheat Flour',
          'Fresh Farm Eggs',
          'Dairy Cream',
          'Cane Sugar',
          'Butter',
        ],
      );

      final pdfBytes = await generator.generateBakeryLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('3. Custom Birthday Celebration Cake label renders valid PDF with custom notes', () async {
      final now = DateTime(2026, 11, 20, 14, 0);
      final data = BakeryLabelData(
        sku: 'BAKE-CUST-CK-03',
        productName: 'Celebration Fondant Designer Cake 1kg',
        batchNumber: 'BATCH-CUST-202611-07',
        bakedAt: now,
        freshnessUntil: now.add(const Duration(hours: 24)),
        netWeight: '1.0 kg',
        containsEgg: true,
        allergens: const ['Wheat / Gluten', 'Dairy', 'Eggs', 'Tree Nuts (Almond Marzipan)'],
        ovenId: 'DECK-OVEN-02',
        fssaiCategoryCode: 'FCS 07.2.1 (Cakes and Pastries)',
        storageAdvice: 'Keep in an air-conditioned room or refrigerated until cutting.',
        ingredients: const ['Vanilla Sponge', 'Buttercream Frosting', 'Sugar Fondant', 'Edible Colors'],
      );

      final pdfBytes = await generator.generateBakeryLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('4. Eggless Multigrain Toast Bread label renders valid PDF with green veg emblem', () async {
      final now = DateTime(2026, 11, 20, 5, 30);
      final data = BakeryLabelData(
        sku: 'BAKE-EGGLESS-04',
        productName: '100% Eggless 7-Grain Toast Loaf 350g',
        batchNumber: 'BATCH-MULTI-202611-10',
        bakedAt: now,
        freshnessUntil: now.add(const Duration(hours: 72)),
        netWeight: '350 g',
        containsEgg: false, // 100% Eggless Vegetarian
        allergens: const ['Wheat / Gluten', 'Sesame Seeds', 'Oats'],
        ovenId: 'ROTARY-01',
        fssaiCategoryCode: 'FCS 07.1 (Breads and Rolls)',
        storageAdvice: 'Store in a dry airtight container. Toast slices before serving.',
        ingredients: const ['Whole Wheat', 'Oats', 'Barley', 'Flax Seeds', 'Sesame', 'Yeast', 'Sunflower Oil'],
      );

      final pdfBytes = await generator.generateBakeryLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });
  });
}
