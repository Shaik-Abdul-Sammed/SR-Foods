import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/export_label_pdf_service.dart';

void main() {
  const service = ExportLabelPdfService();

  final skus = [
    {
      'sku': 'EXP-PAROTA-FRZ',
      'name': 'Frozen Malabar Parota (5-Pack)',
      'nameAr': 'بروتا ملبار المجمدة (٥ قطع)',
      'nameFr': 'Parota Malabar Surgelé (5 Pièces)',
      'netGrams': 400.0,
      'netOz': 14.1,
      'ingredients': ['Refined Wheat Flour (Maida)', 'Water', 'Vegetable Oil', 'Salt'],
      'quid': {'Wheat Flour': 62.0},
      'allergens': ['Wheat', 'Gluten'],
    },
    {
      'sku': 'EXP-CHAPATHI-WHT',
      'name': 'Whole Wheat Chapathi (10-Pack)',
      'nameAr': 'خبز الشباتي بالقمح الكامل (١٠ قطع)',
      'nameFr': 'Chapathi au Blé Entier (10 Pièces)',
      'netGrams': 350.0,
      'netOz': 12.35,
      'ingredients': ['100% Whole Wheat Atta', 'Water', 'Vegetable Oil', 'Iodized Salt'],
      'quid': {'Whole Wheat Atta': 68.0},
      'allergens': ['Wheat'],
    },
    {
      'sku': 'EXP-PULKA-ROTI',
      'name': 'Oil-Free Pulka Roti (12-Pack)',
      'nameAr': 'خبز بولكا الخفيف خالي من الزيت (١٢ قطعة)',
      'nameFr': 'Roti Pulka Sans Huile (12 Pièces)',
      'netGrams': 300.0,
      'netOz': 10.58,
      'ingredients': ['Stone-Ground Whole Wheat', 'Purified Water', 'Salt'],
      'quid': {'Stone-Ground Wheat': 72.0},
      'allergens': ['Wheat'],
    },
  ];

  final countries = ['US', 'AE', 'CA', 'GB', 'AU'];

  group('Multi-Country Export Label PDF Golden Tests (15 test matrix)', () {
    for (final skuInfo in skus) {
      for (final country in countries) {
        test('Label PDF for ${skuInfo['sku']} -> $country generates valid PDF > 5KB', () async {
          final data = ExportLabelData(
            sku: skuInfo['sku'] as String,
            productName: skuInfo['name'] as String,
            productNameArabic: skuInfo['nameAr'] as String?,
            productNameFrench: skuInfo['nameFr'] as String?,
            batchNumber: 'BATCH-202611-001',
            productionDate: DateTime(2026, 11, 14),
            expiryDate: DateTime(2027, 5, 14),
            netWeightGrams: skuInfo['netGrams'] as double,
            netWeightOz: skuInfo['netOz'] as double?,
            ingredients: skuInfo['ingredients'] as List<String>,
            quidPercentages: skuInfo['quid'] as Map<String, double>,
            allergens: skuInfo['allergens'] as List<String>,
            destinationCountry: country,
            halalCertificateNumber: 'HALAL-IND-2026-9812',
            destinationImporterAddress: country == 'GB'
                ? 'Taj Foods UK Ltd, London HA9 0HQ'
                : country == 'US'
                    ? 'Patel Brothers Import LLC, Hanover Park, IL 60133'
                    : 'Global Asian Food Distributors, Dubai, UAE',
          );

          final pdfBytes = await service.generateExportLabel(data);

          // Assertions
          expect(pdfBytes.isNotEmpty, isTrue);
          expect(pdfBytes.length, greaterThan(5120),
              reason: 'Output PDF should be > 5KB to accommodate barcode, nutrition and regulatory panels');

          // Verify PDF magic header bytes "%PDF-"
          final header = ascii.decode(pdfBytes.take(5).toList());
          expect(header, '%PDF-');
        });
      }
    }
  });
}
