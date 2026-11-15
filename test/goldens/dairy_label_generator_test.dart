import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/pdf/dairy_label_generator.dart';

void main() {
  const generator = DairyLabelGenerator();

  group('Dairy Label Generator PDF Tests (4 SKUs)', () {
    test('1. Pasteurised Milk Carton label renders valid PDF with FSSAI compliance', () async {
      final data = DairyLabelData(
        sku: 'DAIRY-MILK-STD-01',
        productName: 'Standardised Toned Milk 500ml',
        batchNumber: 'BATCH-MILK-202611-01',
        mfgDate: DateTime(2026, 11, 20, 6, 0),
        useByDate: DateTime(2026, 11, 22, 18, 0),
        netQuantity: '500 ml',
        fatPercent: 3.5,
        snfPercent: 8.5,
        milkType: 'Cow & Buffalo Blend',
        pasteurizationStandard: 'HTST Pasteurised (72°C for 15 sec)',
        fssaiCategoryCode: 'FCS 01.1.2',
        chillingCenter: 'Medak Chilling Center #3',
      );

      final pdfBytes = await generator.generateDairyLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('2. Fresh Malai Paneer label renders valid PDF with chilling criteria', () async {
      final data = DairyLabelData(
        sku: 'DAIRY-PAN-200G',
        productName: 'Fresh Malai Paneer Block 200g',
        batchNumber: 'BATCH-PAN-202611-05',
        mfgDate: DateTime(2026, 11, 20, 8, 30),
        useByDate: DateTime(2026, 12, 5, 23, 59),
        netQuantity: '200 g',
        fatPercent: 22.0,
        snfPercent: 70.0,
        milkType: 'Pure Buffalo Milk',
        fssaiCategoryCode: 'FCS 01.5.1 (Paneer / Chhana)',
        storageCondition: 'Keep refrigerated between 2°C and 4°C. Immerse in water after opening.',
      );

      final pdfBytes = await generator.generateDairyLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('3. Pure Desi Cow Ghee label renders valid PDF', () async {
      final data = DairyLabelData(
        sku: 'DAIRY-GHEE-1L',
        productName: 'Pure Desi Danedar Cow Ghee 1L',
        batchNumber: 'BATCH-GHEE-202611-09',
        mfgDate: DateTime(2026, 11, 15, 10, 0),
        useByDate: DateTime(2027, 8, 15, 23, 59),
        netQuantity: '1 Litre (910 g)',
        fatPercent: 99.7,
        snfPercent: 0.1,
        milkType: 'Indigenous Gir Cow Milk',
        fssaiCategoryCode: 'FCS 01.6.1 (Ghee and Butter Oil)',
        storageCondition: 'Store in cool and dry place away from direct sunlight. No refrigeration needed.',
      );

      final pdfBytes = await generator.generateDairyLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('4. Probiotic Set Curd label renders valid PDF', () async {
      final data = DairyLabelData(
        sku: 'DAIRY-CURD-400G',
        productName: 'Artisanal Probiotic Thick Curd 400g',
        batchNumber: 'BATCH-CURD-202611-12',
        mfgDate: DateTime(2026, 11, 20, 4, 0),
        useByDate: DateTime(2026, 11, 28, 23, 59),
        netQuantity: '400 g',
        fatPercent: 3.2,
        snfPercent: 8.8,
        milkType: 'Toned Milk with Live Probiotic Cultures',
        fssaiCategoryCode: 'FCS 01.2.1 (Fermented Milks)',
        storageCondition: 'Store refrigerated at 4°C or below. Consume cold.',
      );

      final pdfBytes = await generator.generateDairyLabel(data);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(3000));
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });
  });
}
