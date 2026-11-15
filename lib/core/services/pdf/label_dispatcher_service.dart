import 'dart:typed_data';
import '../../database/app_database.dart';
import '../export_label_pdf_service.dart';
import 'dairy_label_generator.dart';
import 'bakery_label_generator.dart';

/// Central dispatcher that selects the appropriate vertical-specific PDF label generator
/// based on product classification and compliance requirements.
class LabelDispatcherService {
  final ExportLabelPdfService exportLabelService;
  final DairyLabelGenerator dairyLabelService;
  final BakeryLabelGenerator bakeryLabelService;

  const LabelDispatcherService({
    this.exportLabelService = const ExportLabelPdfService(),
    this.dairyLabelService = const DairyLabelGenerator(),
    this.bakeryLabelService = const BakeryLabelGenerator(),
  });

  /// Identifies the product vertical
  String resolveVertical(Product product) {
    final cat = product.category.toLowerCase().trim();
    if (cat.contains('dairy') || cat.contains('milk') || cat.contains('cheese') || cat.contains('paneer')) {
      return 'dairy';
    }
    if (cat.contains('bakery') || cat.contains('bread') || cat.contains('cake') || cat.contains('pastry') || cat.contains('bun')) {
      return 'bakery';
    }
    return 'frozen';
  }

  /// Dispatches to the appropriate label generator and returns PDF document bytes
  Future<Uint8List> generateProductLabel({
    required Product product,
    ProductionBatch? batch,
    String destinationCountry = 'IN',
  }) async {
    final vertical = resolveVertical(product);
    final now = DateTime.now();

    switch (vertical) {
      case 'dairy':
        return dairyLabelService.generateDairyLabel(
          DairyLabelData(
            sku: product.sku,
            productName: product.name,
            batchNumber: batch?.batchNumber ?? 'BAT-${now.millisecondsSinceEpoch.toString().substring(7)}',
            mfgDate: batch?.manufacturingDate ?? now,
            useByDate: batch?.expiryDate ?? now.add(Duration(days: product.shelfLifeDays)),
            netQuantity: '${product.weightGrams.toInt()} ${product.unit}',
            fatPercent: product.fatPercentExpected ?? 4.5,
            snfPercent: product.snfPercentExpected ?? 8.5,
            milkType: product.milkType ?? 'Cow Milk',
            pasteurizationStandard: product.isPasteurized == true
                ? 'HTST Pasteurised (72°C / 15s)'
                : 'Raw Chilled Certified',
            fssaiCategoryCode: product.fssaiCategoryCode ?? 'FCS 01.1.2',
            chillingCenter: batch?.chillingCenterId ?? 'Chilling Unit Central',
          ),
        );

      case 'bakery':
        final bakedTime = batch?.bakedAt ?? now;
        final shelfHours = product.freshnessWindowHours ?? 24;
        return bakeryLabelService.generateBakeryLabel(
          BakeryLabelData(
            sku: product.sku,
            productName: product.name,
            batchNumber: batch?.batchNumber ?? 'BKB-${now.millisecondsSinceEpoch.toString().substring(7)}',
            bakedAt: bakedTime,
            freshnessUntil: batch?.freshnessUntil ?? bakedTime.add(Duration(hours: shelfHours)),
            netWeight: '${product.weightGrams.toInt()} ${product.unit}',
            containsEgg: product.allergens.toLowerCase().contains('egg'),
            allergens: product.allergens.isNotEmpty
                ? product.allergens.split(',').map((e) => e.trim()).toList()
                : ['Wheat / Gluten'],
            ovenId: batch?.ovenId ?? 'OVEN-ROTARY-1',
            fssaiCategoryCode: product.fssaiCategoryCode ?? 'FCS 07.1',
          ),
        );

      case 'frozen':
      default:
        return exportLabelService.generateExportLabel(
          ExportLabelData(
            sku: product.sku,
            productName: product.name,
            batchNumber: batch?.batchNumber ?? 'FZN-${now.millisecondsSinceEpoch.toString().substring(7)}',
            productionDate: batch?.manufacturingDate ?? now,
            expiryDate: batch?.expiryDate ?? now.add(Duration(days: product.shelfLifeDays)),
            netWeightGrams: product.weightGrams,
            ingredients: [product.description ?? product.name],
            allergens: product.allergens.isNotEmpty
                ? product.allergens.split(',').map((e) => e.trim()).toList()
                : const [],
            destinationCountry: destinationCountry,
            storageCondition: product.storageType == 'ambient'
                ? 'Store in a cool dry place'
                : 'Keep Frozen at -18°C (0°F) or below.',
          ),
        );
    }
  }
}
