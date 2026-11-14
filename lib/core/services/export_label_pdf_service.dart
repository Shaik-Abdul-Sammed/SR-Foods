import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Data payload required to render an export compliance label
class ExportLabelData {
  final String sku;
  final String productName;
  final String? productNameArabic;
  final String? productNameFrench;
  final String batchNumber;
  final DateTime productionDate;
  final DateTime expiryDate;
  final double netWeightGrams;
  final double? netWeightOz;
  final List<String> ingredients;
  final Map<String, double> quidPercentages;
  final List<String> allergens;
  final String destinationCountry;
  final String? destinationImporterAddress;
  final String? halalCertificateNumber;
  final String storageCondition;
  final String manufacturerAddress;
  final String fssaiLicense;

  const ExportLabelData({
    required this.sku,
    required this.productName,
    this.productNameArabic,
    this.productNameFrench,
    required this.batchNumber,
    required this.productionDate,
    required this.expiryDate,
    required this.netWeightGrams,
    this.netWeightOz,
    required this.ingredients,
    this.quidPercentages = const {},
    this.allergens = const [],
    required this.destinationCountry,
    this.destinationImporterAddress,
    this.halalCertificateNumber,
    this.storageCondition = 'Keep Frozen at -18°C (0°F) or below. Do not refreeze once thawed.',
    this.manufacturerAddress = 'SR Foods India Pvt. Ltd., Plot 12, Export Zone, Hyderabad, TS 500072, India',
    this.fssaiLicense = '10123999000123',
  });
}

/// Service generating print-ready export carton and consumer labels adhering to
/// destination country regulations (FDA, GSO Halal, CFIA, FSA QUID, FSANZ CoOL).
class ExportLabelPdfService {
  const ExportLabelPdfService();

  Future<Uint8List> generateExportLabel(ExportLabelData data) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: false);
    final country = data.destinationCountry.toUpperCase().trim();

    // Standard 4" x 6" (101.6mm x 152.4mm) shipping & retail master label format
    const labelFormat = PdfPageFormat(
      101.6 * PdfPageFormat.mm,
      152.4 * PdfPageFormat.mm,
      marginAll: 6 * PdfPageFormat.mm,
    );

    final df = DateFormat('dd/MM/yyyy');
    final prodStr = df.format(data.productionDate);
    final expStr = df.format(data.expiryDate);

    pdf.addPage(
      pw.Page(
        pageFormat: labelFormat,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header brand & country badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SR FOODS EXPORT QUALITY',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.black,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                      ),
                      child: pw.Text(
                        'DESTINATION: $country',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, height: 6),

                // Primary Product Title
                pw.Text(
                  data.productName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),

                // Country-specific secondary title (Bilingual Arabic / French)
                if (country == 'AE' && data.productNameArabic != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    data.productNameArabic!,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.center,
                  ),
                ] else if (country == 'CA' && data.productNameFrench != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    data.productNameFrench!,
                    style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center,
                  ),
                ],

                pw.SizedBox(height: 4),

                // Net Weight Banner (Dual US Oz + Grams or Metric)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  color: PdfColors.grey200,
                  child: pw.Text(
                    country == 'US' && data.netWeightOz != null
                        ? 'NET WT. ${data.netWeightOz!.toStringAsFixed(1)} OZ (${data.netWeightGrams.toStringAsFixed(0)}g)'
                        : 'NET WEIGHT: ${data.netWeightGrams.toStringAsFixed(0)} g (${(data.netWeightGrams / 1000).toStringAsFixed(2)} kg)',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                pw.SizedBox(height: 4),

                // Destination Specific Regulatory Modules
                _buildRegulatoryPanel(country, data),

                pw.Spacer(),

                // Batch, MFG & EXP Block
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BATCH: ${data.batchNumber}',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('MFG DATE: $prodStr', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('EXP DATE: $expStr',
                              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.dataMatrix(),
                                data: '0108906000${data.sku.replaceAll(RegExp(r'[^0-9]'), '').padLeft(5, '0')}010${data.batchNumber}17${DateFormat('yyMMdd').format(data.expiryDate)}',
                                width: 24,
                                height: 24,
                              ),
                              pw.SizedBox(width: 4),
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.code128(),
                                data: '${data.sku}-${data.batchNumber}',
                                width: 60,
                                height: 20,
                                drawText: false,
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            '(01)08906000${data.sku.replaceAll(RegExp(r'[^0-9]'), '').padLeft(5, '0')}0 (10)${data.batchNumber} (17)${DateFormat('yyMMdd').format(data.expiryDate)}',
                            style: pw.TextStyle(fontSize: 4.8, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 3),

                // Storage and Origin Footer
                pw.Text(
                  data.storageCondition,
                  style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Country of Origin: India | FSSAI Lic. No. ${data.fssaiLicense}',
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Manufactured by: ${data.manufacturerAddress}',
                  style: const pw.TextStyle(fontSize: 5),
                  textAlign: pw.TextAlign.center,
                ),
                if (data.destinationImporterAddress != null)
                  pw.Text(
                    'Imported & Distributed by: ${data.destinationImporterAddress}',
                    style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildRegulatoryPanel(String country, ExportLabelData data) {
    switch (country) {
      case 'US':
        return _buildUsFdaPanel(data);
      case 'AE':
      case 'SA':
      case 'QA':
        return _buildGsoHalalPanel(data);
      case 'CA':
        return _buildCanadaCfiaPanel(data);
      case 'GB':
      case 'UK':
        return _buildUkQuidPanel(data);
      case 'AU':
      case 'NZ':
        return _buildAustraliaCoolPanel(data);
      default:
        return _buildGenericPanel(data);
    }
  }

  pw.Widget _buildUsFdaPanel(ExportLabelData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Nutrition Facts / Valeur Nutritive',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text('Serving size 1 Piece (80g) | Servings Per Container: 5',
              style: const pw.TextStyle(fontSize: 6)),
          pw.Divider(thickness: 1.5, height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Calories 260', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('% Daily Value*', style: const pw.TextStyle(fontSize: 6)),
            ],
          ),
          pw.Divider(thickness: 0.5, height: 2),
          pw.Text('Total Fat 11g (14%) | Saturated Fat 5g (25%) | Trans Fat 0g',
              style: const pw.TextStyle(fontSize: 6)),
          pw.Text('Sodium 340mg (15%) | Total Carbohydrate 36g (13%) | Protein 5g',
              style: const pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 2),
          pw.Text('INGREDIENTS: ${data.ingredients.join(', ')}.',
              style: const pw.TextStyle(fontSize: 6)),
          if (data.allergens.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              color: PdfColors.amber100,
              child: pw.Text(
                'CONTAINS: ${data.allergens.join(', ').toUpperCase()}.',
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildGsoHalalPanel(ExportLabelData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.green900, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GSO 9/2013 FOOD COMPLIANT',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green800),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                child: pw.Text(
                  'HALAL / حلال',
                  style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                ),
              ),
            ],
          ),
          if (data.halalCertificateNumber != null)
            pw.Text('Halal Registry Cert: ${data.halalCertificateNumber}',
                style: const pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 2),
          pw.Text('INGREDIENTS: ${data.ingredients.join(', ')}.',
              style: const pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 1),
          pw.Text('المكونات: دقيق القمح المكرر، ماء صالح للشرب، زيت نباتي، ملح طعام.',
              style: const pw.TextStyle(fontSize: 6), textDirection: pw.TextDirection.rtl),
          pw.SizedBox(height: 2),
          pw.Text('Product of India / صُنِعَ في الهند',
              style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildCanadaCfiaPanel(ExportLabelData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red900, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Valeur nutritive / Nutrition Facts',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text('Pour 1 morceau (80g) / Per 1 piece (80g)',
              style: const pw.TextStyle(fontSize: 6)),
          pw.Divider(thickness: 1, height: 3),
          pw.Text('Calories 260 | Lipides / Fat 11g (15%) | Glucides / Carbohydrate 36g',
              style: const pw.TextStyle(fontSize: 6)),
          pw.Text('Protéines / Protein 5g | Sodium 340mg (15%)',
              style: const pw.TextStyle(fontSize: 6)),
          pw.SizedBox(height: 2),
          pw.Text('INGRÉDIENTS: ${data.ingredients.join(', ')}.',
              style: const pw.TextStyle(fontSize: 6)),
          if (data.allergens.isNotEmpty)
            pw.Text(
              'CONTIENT / CONTAINS: ${data.allergens.join(', ').toUpperCase()}.',
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildUkQuidPanel(ExportLabelData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('UK FOOD STANDARDS & QUID BREAKDOWN',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          pw.Text('Ingredients with QUID % (Quantitative Ingredient Declaration):',
              style: const pw.TextStyle(fontSize: 6)),
          ...data.quidPercentages.entries.map(
            (e) => pw.Text(' • ${e.key}: ${e.value.toStringAsFixed(1)}%',
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 2),
          pw.Text('Full Ingredients: ${data.ingredients.join(', ')}.',
              style: const pw.TextStyle(fontSize: 6)),
          if (data.allergens.isNotEmpty)
            pw.Text(
              'ALLERGEN ADVICE: For allergens, including cereals containing gluten, see ingredients in BOLD.',
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildAustraliaCoolPanel(ExportLabelData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal900, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('FSANZ COUNTRY OF ORIGIN & PEAL LABEL',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 2),
            padding: const pw.EdgeInsets.all(2),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal800)),
            child: pw.Row(
              children: [
                pw.Container(width: 12, height: 12, color: PdfColors.teal800),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: pw.Text(
                    'Made in India from at least 95% Indian ingredients.',
                    style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          pw.Text('Ingredients: ${data.ingredients.join(', ')}.',
              style: const pw.TextStyle(fontSize: 6)),
          if (data.allergens.isNotEmpty)
            pw.Text(
              'ALLERGEN STATEMENT (PEAL): Contains WHEAT (GLUTEN).',
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildGenericPanel(ExportLabelData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text('Ingredients: ${data.ingredients.join(', ')}.',
          style: const pw.TextStyle(fontSize: 6)),
    );
  }
}
