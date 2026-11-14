import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/compliance_profile_engine.dart';

void main() {
  const engine = ComplianceProfileEngine();
  final arrivalDate = DateTime(2026, 12, 1);

  group('ComplianceProfileEngine: 5-Country & Expiry Radar Tests', () {
    test('1. US FDA Profile: flags missing oz net weight and undeclared wheat allergen, passes valid', () {
      // Invalid US order
      final invalidUs = ExportBatchComplianceData(
        sku: 'PAROTA-US-01',
        productName: 'Malabar Parota',
        ingredients: ['Refined Wheat Flour', 'Water', 'Vegetable Oil', 'Salt'],
        allergens: [], // Missing Wheat!
        netWeightGrams: 400.0,
        netWeightOz: null, // Missing Oz!
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
      );

      final findings = engine.auditOrder(
        destinationCountryCode: 'US',
        items: [invalidUs],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(findings.any((f) => f.ruleId == 'US_FDA_NET_WEIGHT_OZ'), isTrue);
      expect(findings.any((f) => f.ruleId == 'US_FDA_ALLERGEN_UNDECLARED'), isTrue);

      // Valid US order
      final validUs = ExportBatchComplianceData(
        sku: 'PAROTA-US-02',
        productName: 'Malabar Parota',
        ingredients: ['Refined Wheat Flour', 'Water', 'Vegetable Oil', 'Salt'],
        allergens: ['Wheat'],
        netWeightGrams: 400.0,
        netWeightOz: 14.1,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
        hasNutritionFactsPanel: true,
      );

      final validFindings = engine.auditOrder(
        destinationCountryCode: 'US',
        items: [validUs],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(validFindings.where((f) => f.isError).isEmpty, isTrue);
    });

    test('2. UAE / GCC (GSO/ESMA): flags missing Halal cert and missing Arabic translation, passes valid', () {
      final invalidGcc = ExportBatchComplianceData(
        sku: 'PAROTA-GCC-01',
        productName: 'Plain Chapathi',
        ingredients: ['Whole Wheat Flour', 'Water', 'Salt'],
        netWeightGrams: 350.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
        halalCertificateNumber: null, // Missing Halal
        isBilingualEnAr: false, // Missing Arabic
      );

      final findings = engine.auditOrder(
        destinationCountryCode: 'AE',
        items: [invalidGcc],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(findings.any((f) => f.ruleId == 'GSO_HALAL_CERT_MISSING'), isTrue);
      expect(findings.any((f) => f.ruleId == 'GSO_BILINGUAL_ARABIC'), isTrue);

      final validGcc = ExportBatchComplianceData(
        sku: 'PAROTA-GCC-02',
        productName: 'Plain Chapathi',
        productNameArabic: 'خبز الشباتي العادي',
        ingredients: ['Whole Wheat Flour', 'Water', 'Salt'],
        netWeightGrams: 350.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
        halalCertificateNumber: 'HALAL-IND-2026-9812',
        isBilingualEnAr: true,
        countryOfOrigin: 'India',
      );

      final validFindings = engine.auditOrder(
        destinationCountryCode: 'AE',
        items: [validGcc],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(validFindings.where((f) => f.isError).isEmpty, isTrue);
    });

    test('3. Canada (CFIA): flags missing bilingual French, passes valid', () {
      final invalidCa = ExportBatchComplianceData(
        sku: 'PAROTA-CA-01',
        productName: 'Puri Ready-to-Fry',
        ingredients: ['Wheat Flour', 'Oil'],
        netWeightGrams: 300.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
        isBilingualEnFr: false,
      );

      final findings = engine.auditOrder(
        destinationCountryCode: 'CA',
        items: [invalidCa],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(findings.any((f) => f.ruleId == 'CFIA_BILINGUAL_FRENCH'), isTrue);

      final validCa = ExportBatchComplianceData(
        sku: 'PAROTA-CA-02',
        productName: 'Puri Ready-to-Fry',
        productNameFrench: 'Puri Prêt à Frire',
        ingredients: ['Wheat Flour', 'Oil'],
        netWeightGrams: 300.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
        isBilingualEnFr: true,
      );

      final validFindings = engine.auditOrder(
        destinationCountryCode: 'CA',
        items: [validCa],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(validFindings.where((f) => f.isError).isEmpty, isTrue);
    });

    test('4. UK (FSA/DEFRA): flags missing QUID and missing UK importer address, passes valid', () {
      final invalidUk = ExportBatchComplianceData(
        sku: 'PAROTA-UK-01',
        productName: 'Flaky Parota',
        ingredients: ['Wheat Flour', 'Water', 'Oil', 'Salt'],
        quidPercentages: {}, // Missing QUID!
        destinationImporterAddress: null, // Missing UK address!
        netWeightGrams: 400.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
      );

      final findings = engine.auditOrder(
        destinationCountryCode: 'GB',
        items: [invalidUk],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(findings.any((f) => f.ruleId == 'UK_FSA_QUID_MISSING'), isTrue);
      expect(findings.any((f) => f.ruleId == 'UK_FSA_IMPORTER_ADDRESS'), isTrue);

      final validUk = ExportBatchComplianceData(
        sku: 'PAROTA-UK-02',
        productName: 'Flaky Parota',
        ingredients: ['Wheat Flour (62%)', 'Water', 'Oil', 'Salt'],
        quidPercentages: {'Wheat Flour': 62.0},
        destinationImporterAddress: 'Taj Foods UK Ltd, Unit 4 Wembley Park, London HA9 0HQ',
        netWeightGrams: 400.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
      );

      final validFindings = engine.auditOrder(
        destinationCountryCode: 'GB',
        items: [validUk],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(validFindings.where((f) => f.isError).isEmpty, isTrue);
    });

    test('5. Australia (FSANZ): flags missing PEAL formatting and CoOL bar chart, passes valid', () {
      final invalidAu = ExportBatchComplianceData(
        sku: 'PAROTA-AU-01',
        productName: 'Pulka Soft Roti',
        ingredients: ['Wheat Flour', 'Water'],
        netWeightGrams: 300.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
        hasPealAllergenFormatting: false,
        hasCountryOfOriginBarChart: false,
      );

      final findings = engine.auditOrder(
        destinationCountryCode: 'AU',
        items: [invalidAu],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(findings.any((f) => f.ruleId == 'FSANZ_PEAL_FORMATTING'), isTrue);
      expect(findings.any((f) => f.ruleId == 'FSANZ_COOL_BAR_CHART'), isTrue);

      final validAu = ExportBatchComplianceData(
        sku: 'PAROTA-AU-02',
        productName: 'Pulka Soft Roti',
        ingredients: ['Wheat Flour', 'Water'],
        netWeightGrams: 300.0,
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 5, 1),
        hasPealAllergenFormatting: true,
        hasCountryOfOriginBarChart: true,
      );

      final validFindings = engine.auditOrder(
        destinationCountryCode: 'AU',
        items: [validAu],
        estimatedPortArrivalDate: arrivalDate,
      );

      expect(validFindings.where((f) => f.isError).isEmpty, isTrue);
    });

    test('6. 60-day and 50% Expiry Radar triggers for tight shelf-life', () {
      // Production: 2026-06-01, Expiry: 2026-12-15 (197 days total shelf life)
      // Port arrival: 2026-11-20 (remaining: 25 days)
      // US requires >= 60 days. GCC requires >= 50% (~98 days).
      final nearExpiryItem = ExportBatchComplianceData(
        sku: 'NEAR-EXP-01',
        productName: 'Frozen Parota',
        ingredients: ['Wheat Flour'],
        netWeightGrams: 400.0,
        netWeightOz: 14.1,
        productionDate: DateTime(2026, 6, 1),
        expiryDate: DateTime(2026, 12, 15),
        halalCertificateNumber: 'HALAL-123',
        isBilingualEnAr: true,
        productNameArabic: 'بروتا',
      );

      final usFindings = engine.auditOrder(
        destinationCountryCode: 'US',
        items: [nearExpiryItem],
        estimatedPortArrivalDate: DateTime(2026, 11, 20),
      );
      expect(usFindings.any((f) => f.ruleId == 'US_FDA_MIN_SHELF_LIFE'), isTrue);

      final gccFindings = engine.auditOrder(
        destinationCountryCode: 'AE',
        items: [nearExpiryItem],
        estimatedPortArrivalDate: DateTime(2026, 11, 20),
      );
      expect(gccFindings.any((f) => f.ruleId == 'GSO_SHELF_LIFE_50PCT'), isTrue);
    });
  });
}
