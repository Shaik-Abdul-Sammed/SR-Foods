enum ComplianceFindingSeverity { error, warning, info }

class ComplianceFinding {
  final ComplianceFindingSeverity severity;
  final String ruleId;
  final String message;
  final String fieldPath;
  final String suggestedFix;

  const ComplianceFinding({
    required this.severity,
    required this.ruleId,
    required this.message,
    required this.fieldPath,
    required this.suggestedFix,
  });

  bool get isError => severity == ComplianceFindingSeverity.error;
  bool get isWarning => severity == ComplianceFindingSeverity.warning;

  @override
  String toString() => '[${severity.name.toUpperCase()}] $ruleId ($fieldPath): $message';
}

/// Regulatory metadata for an export product batch
class ExportBatchComplianceData {
  final String sku;
  final String productName;
  final String? productNameArabic;
  final String? productNameFrench;
  final List<String> ingredients;
  final Map<String, double> quidPercentages; // e.g. {'Wheat Flour': 62.5}
  final List<String> allergens;
  final double netWeightGrams;
  final double? netWeightOz;
  final DateTime productionDate;
  final DateTime expiryDate;
  final String? halalCertificateNumber;
  final String? countryOfOrigin; // e.g. "India"
  final String? destinationImporterAddress;
  final bool hasNutritionFactsPanel;
  final bool isBilingualEnAr;
  final bool isBilingualEnFr;
  final bool hasPealAllergenFormatting; // Plain English Allergen Labelling (Australia)
  final bool hasCountryOfOriginBarChart; // Australia CoOL requirement

  const ExportBatchComplianceData({
    required this.sku,
    required this.productName,
    this.productNameArabic,
    this.productNameFrench,
    required this.ingredients,
    this.quidPercentages = const {},
    this.allergens = const [],
    required this.netWeightGrams,
    this.netWeightOz,
    required this.productionDate,
    required this.expiryDate,
    this.halalCertificateNumber,
    this.countryOfOrigin = 'India',
    this.destinationImporterAddress,
    this.hasNutritionFactsPanel = true,
    this.isBilingualEnAr = false,
    this.isBilingualEnFr = false,
    this.hasPealAllergenFormatting = false,
    this.hasCountryOfOriginBarChart = false,
  });
}

/// Pure Dart, offline-first food regulatory compliance engine
class ComplianceProfileEngine {
  const ComplianceProfileEngine();

  // Top 9 US FDA Major Food Allergens (FALCPA & FASTER Act of 2021)
  static const Set<String> usFdaAllergens = {
    'milk',
    'eggs',
    'fish',
    'crustacean shellfish',
    'tree nuts',
    'peanuts',
    'wheat',
    'soybeans',
    'sesame',
  };

  /// Run comprehensive destination country regulatory audit on export order lines
  List<ComplianceFinding> auditOrder({
    required String destinationCountryCode,
    required List<ExportBatchComplianceData> items,
    required DateTime estimatedPortArrivalDate,
  }) {
    final findings = <ComplianceFinding>[];
    final country = destinationCountryCode.toUpperCase().trim();

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final prefix = 'items[$i] (${item.sku})';

      // 1. Expiry & Shelf-Life Radar check (Universal & Country-specific)
      _auditShelfLifeRadar(country, item, estimatedPortArrivalDate, prefix, findings);

      // 2. Country-Specific Regulatory Regimes
      switch (country) {
        case 'US':
          _auditUsFda(item, prefix, findings);
          break;
        case 'AE':
        case 'SA':
        case 'QA':
        case 'KW':
        case 'OM':
        case 'BH':
          _auditGsoHalal(item, prefix, findings);
          break;
        case 'CA':
          _auditCanadaCfia(item, prefix, findings);
          break;
        case 'GB':
        case 'UK':
          _auditUkFsa(item, prefix, findings);
          break;
        case 'AU':
        case 'NZ':
          _auditAustraliaFsanz(item, prefix, findings);
          break;
        case 'IN':
          _auditIndiaFssai(item, prefix, findings);
          break;
        default:
          findings.add(
            ComplianceFinding(
              severity: ComplianceFindingSeverity.warning,
              ruleId: 'GEN_UNKNOWN_COUNTRY',
              message: 'No specialized regulatory profile configured for $country. Applied universal Codex Alimentarius baselines.',
              fieldPath: 'destinationCountry',
              suggestedFix: 'Configure country compliance profile in settings.',
            ),
          );
      }
    }

    return findings;
  }

  void _auditShelfLifeRadar(
    String country,
    ExportBatchComplianceData item,
    DateTime arrivalDate,
    String prefix,
    List<ComplianceFinding> findings,
  ) {
    if (arrivalDate.isAfter(item.expiryDate)) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'EXP_BATCH_EXPIRED_ON_ARRIVAL',
          message: 'Product batch will arrive expired at destination port (Arrival: $arrivalDate > Expiry: ${item.expiryDate}).',
          fieldPath: '$prefix.expiryDate',
          suggestedFix: 'Assign a fresh manufacturing batch with later expiry.',
        ),
      );
      return;
    }

    final totalShelfLifeDays = item.expiryDate.difference(item.productionDate).inDays;
    final remainingDaysOnArrival = item.expiryDate.difference(arrivalDate).inDays;

    if (totalShelfLifeDays <= 0) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'EXP_INVALID_DATES',
          message: 'Production date cannot be equal to or after expiry date.',
          fieldPath: '$prefix.productionDate',
          suggestedFix: 'Correct manufacturing or expiry timestamp.',
        ),
      );
      return;
    }

    final remainingPercentage = (remainingDaysOnArrival / totalShelfLifeDays) * 100.0;

    // US 60-day buffer rule for dry/frozen packaged bakery items
    if (country == 'US' && remainingDaysOnArrival < 60) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'US_FDA_MIN_SHELF_LIFE',
          message: 'US customs entry requires minimum 60 days remaining shelf-life at port of entry. Only $remainingDaysOnArrival days remaining.',
          fieldPath: '$prefix.expiryDate',
          suggestedFix: 'Replace batch with minimum 60+ days remaining shelf life.',
        ),
      );
    }

    // GCC / GSO standard: Minimum 50% remaining shelf life on port clearance
    if (['AE', 'SA', 'QA', 'KW', 'OM', 'BH'].contains(country) && remainingPercentage < 50.0) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'GSO_SHELF_LIFE_50PCT',
          message: 'GSO standard requires >= 50% shelf-life remaining on port arrival. Batch has only ${remainingPercentage.toStringAsFixed(1)}% remaining.',
          fieldPath: '$prefix.expiryDate',
          suggestedFix: 'Ship newly produced batches manufactured within 30 days of bill of lading date.',
        ),
      );
    }
  }

  void _auditUsFda(ExportBatchComplianceData item, String prefix, List<ComplianceFinding> findings) {
    // 1. Dual metric + US customary units
    if (item.netWeightOz == null || item.netWeightOz! <= 0) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'US_FDA_NET_WEIGHT_OZ',
          message: 'FDA 21 CFR 101.105 requires dual net weight declaration in both ounces (oz) and grams (g).',
          fieldPath: '$prefix.netWeightOz',
          suggestedFix: 'Add net weight in oz (e.g. Net Wt. 14.1 oz / 400g).',
        ),
      );
    }

    // 2. Nutrition facts panel
    if (!item.hasNutritionFactsPanel) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'US_FDA_NUTRITION_FACTS',
          message: 'FDA compliant Nutrition Facts panel is mandatory on consumer packaging.',
          fieldPath: '$prefix.hasNutritionFactsPanel',
          suggestedFix: 'Enable FDA dual-column Nutrition Facts panel on label.',
        ),
      );
    }

    // 3. Allergen check (FALCPA / FASTER sesame)
    final lowerIngredients = item.ingredients.map((e) => e.toLowerCase()).toList();
    final lowerAllergens = item.allergens.map((e) => e.toLowerCase()).toList();

    for (final allergen in usFdaAllergens) {
      final presentInIngredients = lowerIngredients.any((ing) => ing.contains(allergen));
      final declaredInAllergens = lowerAllergens.any((all) => all.contains(allergen));

      if (presentInIngredients && !declaredInAllergens) {
        findings.add(
          ComplianceFinding(
            severity: ComplianceFindingSeverity.error,
            ruleId: 'US_FDA_ALLERGEN_UNDECLARED',
            message: 'Allergen "$allergen" detected in ingredient list but missing in "Contains" statement.',
            fieldPath: '$prefix.allergens',
            suggestedFix: 'Add "$allergen" to the "Contains:" allergen warning box.',
          ),
        );
      }
    }
  }

  void _auditGsoHalal(ExportBatchComplianceData item, String prefix, List<ComplianceFinding> findings) {
    // 1. Halal Certificate Reference
    if (item.halalCertificateNumber == null || item.halalCertificateNumber!.trim().isEmpty) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'GSO_HALAL_CERT_MISSING',
          message: 'GSO/ESMA UAE entry requires valid accredited Halal certification number.',
          fieldPath: '$prefix.halalCertificateNumber',
          suggestedFix: 'Attach Halal certification registry number on label and manifest.',
        ),
      );
    }

    // 2. Bilingual Arabic + English
    if (!item.isBilingualEnAr || item.productNameArabic == null || item.productNameArabic!.isEmpty) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'GSO_BILINGUAL_ARABIC',
          message: 'GSO 9/2013 standard mandates bilingual Arabic and English labelling for product name and ingredients.',
          fieldPath: '$prefix.isBilingualEnAr',
          suggestedFix: 'Provide Arabic translation of product name and ingredients.',
        ),
      );
    }

    // 3. Country of origin
    if (item.countryOfOrigin == null || item.countryOfOrigin!.isEmpty) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'GSO_COUNTRY_OF_ORIGIN',
          message: 'Country of Origin statement (e.g. "Product of India / صُنِعَ في الهند") is mandatory.',
          fieldPath: '$prefix.countryOfOrigin',
          suggestedFix: 'Add "Product of India" in both English and Arabic.',
        ),
      );
    }
  }

  void _auditCanadaCfia(ExportBatchComplianceData item, String prefix, List<ComplianceFinding> findings) {
    // 1. Bilingual English + French
    if (!item.isBilingualEnFr || item.productNameFrench == null || item.productNameFrench!.isEmpty) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'CFIA_BILINGUAL_FRENCH',
          message: 'Canadian Food Inspection Agency (CFIA) requires bilingual English and French labelling.',
          fieldPath: '$prefix.isBilingualEnFr',
          suggestedFix: 'Provide French product name and bilingual nutrition table (Valeur nutritive).',
        ),
      );
    }

    // 2. Net quantity in metric
    if (item.netWeightGrams <= 0) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'CFIA_NET_QUANTITY_METRIC',
          message: 'CFIA requires metric net quantity declaration (g or kg).',
          fieldPath: '$prefix.netWeightGrams',
          suggestedFix: 'Set net weight in grams or kilograms.',
        ),
      );
    }
  }

  void _auditUkFsa(ExportBatchComplianceData item, String prefix, List<ComplianceFinding> findings) {
    // 1. QUID (Quantitative Ingredient Declaration)
    if (item.quidPercentages.isEmpty) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'UK_FSA_QUID_MISSING',
          message: "UK Food Standards Agency & Natasha's Law require QUID percentage for characterising star ingredients (e.g. Wheat Flour %).",
          fieldPath: '$prefix.quidPercentages',
          suggestedFix: 'Specify QUID percentage for flour, whole wheat, or key oils.',
        ),
      );
    }

    // 2. UK Importer Address
    if (item.destinationImporterAddress == null || item.destinationImporterAddress!.isEmpty) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'UK_FSA_IMPORTER_ADDRESS',
          message: 'UK regulations mandate a Food Business Operator (FBO) or UK importer registered address on the label.',
          fieldPath: '$prefix.destinationImporterAddress',
          suggestedFix: 'Add UK distributor or importer company name and address.',
        ),
      );
    }
  }

  void _auditAustraliaFsanz(ExportBatchComplianceData item, String prefix, List<ComplianceFinding> findings) {
    // 1. Plain English Allergen Labelling (PEAL)
    if (!item.hasPealAllergenFormatting) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'FSANZ_PEAL_FORMATTING',
          message: 'FSANZ Standard 1.2.3 requires Plain English Allergen Labelling (PEAL) with bolding in both ingredient list and summary statement.',
          fieldPath: '$prefix.hasPealAllergenFormatting',
          suggestedFix: 'Format allergens with bold font weight in ingredients and summary box.',
        ),
      );
    }

    // 2. Country of origin bar chart statement
    if (!item.hasCountryOfOriginBarChart) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.error,
          ruleId: 'FSANZ_COOL_BAR_CHART',
          message: 'Australian Country of Origin Labelling (CoOL) requires the standard bar chart and text statement.',
          fieldPath: '$prefix.hasCountryOfOriginBarChart',
          suggestedFix: 'Include Australian CoOL bar statement: "Made in India from at least 95% Indian ingredients".',
        ),
      );
    }
  }

  void _auditIndiaFssai(ExportBatchComplianceData item, String prefix, List<ComplianceFinding> findings) {
    if (item.countryOfOrigin == null || item.countryOfOrigin!.isEmpty) {
      findings.add(
        ComplianceFinding(
          severity: ComplianceFindingSeverity.warning,
          ruleId: 'FSSAI_ORIGIN',
          message: 'FSSAI requires manufacturing origin and licensee address.',
          fieldPath: '$prefix.countryOfOrigin',
          suggestedFix: 'Ensure FSSAI 14-digit license number and factory address are present.',
        ),
      );
    }
  }
}
