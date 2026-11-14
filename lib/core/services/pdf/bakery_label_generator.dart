import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Data model representing a compliant bakery packaging label
class BakeryLabelData {
  final String sku;
  final String productName;
  final String batchNumber;
  final DateTime bakedAt;
  final DateTime freshnessUntil;
  final String netWeight;
  final bool containsEgg;
  final List<String> allergens;
  final String ovenId;
  final String fssaiCategoryCode;
  final String fssaiLicense;
  final String storageAdvice;
  final String manufacturerAddress;
  final List<String> ingredients;

  const BakeryLabelData({
    required this.sku,
    required this.productName,
    required this.batchNumber,
    required this.bakedAt,
    required this.freshnessUntil,
    required this.netWeight,
    this.containsEgg = false,
    this.allergens = const ['Wheat / Gluten', 'Dairy'],
    this.ovenId = 'OVEN-ROTARY-1',
    this.fssaiCategoryCode = 'FCS 07.1 (Breads and Rolls)',
    this.fssaiLicense = '10123999000123',
    this.storageAdvice = 'Store in a cool, dry place away from direct sunlight. Do not refrigerate bread loaves.',
    this.manufacturerAddress = 'SR Foods Artisanal Bakery, Unit 4, Cherlapally Industrial Area, Hyderabad - 500051',
    this.ingredients = const ['Refined Wheat Flour (Maida)', 'Water', 'Yeast', 'Butter', 'Salt', 'Sugar'],
  });
}

/// Service generating FSSAI FCS 07.x compliant bakery and pastry labels
class BakeryLabelGenerator {
  const BakeryLabelGenerator();

  Future<Uint8List> generateBakeryLabel(BakeryLabelData data) async {
    final pdf = pw.Document();
    final timeFormat = DateFormat('dd/MM/yyyy • hh:mm a');
    final freshnessFormat = DateFormat('hh:mm a, dd MMM');

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm, marginAll: 6 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.brown800, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with Veg / Non-Veg Mark & Bakery Brand
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SR FOODS BAKERY',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.brown900,
                          ),
                        ),
                        pw.Text(
                          'DAILY ARTISANAL BAKE',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.brown600, letterSpacing: 1),
                        ),
                      ],
                    ),
                    // Veg (green) vs Non-Veg/Egg (brown) symbol
                    _buildDietaryMark(data.containsEgg),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.grey400),

                // Product Title & Net Weight
                pw.SizedBox(height: 2),
                pw.Text(
                  data.productName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  data.containsEgg ? 'Contains Egg • Freshly Baked' : '100% Eggless • Freshly Baked',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontStyle: pw.FontStyle.italic,
                    color: data.containsEgg ? PdfColors.brown800 : PdfColors.green900,
                  ),
                ),
                pw.SizedBox(height: 6),

                // Freshness Callout Box
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.amber300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'FRESHNESS WINDOW',
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
                          ),
                          pw.Text('Net Wt: ${data.netWeight}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'BAKED AT: ${timeFormat.format(data.bakedAt)}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
                      ),
                      pw.Text(
                        'BEST BEFORE: ${freshnessFormat.format(data.freshnessUntil)}',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // Batch & Oven Traceability
                _infoRow('Batch Code:', data.batchNumber),
                _infoRow('SKU Code:', data.sku),
                _infoRow('Oven ID:', data.ovenId),
                pw.SizedBox(height: 4),

                // Ingredients List
                pw.Text('Ingredients:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  data.ingredients.join(', '),
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 4),

                // Allergen Advice Box
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange200),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    'ALLERGEN ADVICE: Contains ${data.allergens.join(", ")}.',
                    style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange900),
                  ),
                ),
                pw.SizedBox(height: 4),

                // Storage Advisory
                pw.Text(
                  'Storage: ${data.storageAdvice}',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                ),

                // Footer & Barcode
                pw.Spacer(),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('fssai Lic. No: ${data.fssaiLicense}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Category: ${data.fssaiCategoryCode}', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: data.sku,
                      width: 70,
                      height: 22,
                      drawText: false,
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Mfd by: ${data.manufacturerAddress}',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildDietaryMark(bool hasEgg) {
    final color = hasEgg ? PdfColors.brown800 : PdfColors.green800;
    return pw.Container(
      width: 16,
      height: 16,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
      ),
      padding: const pw.EdgeInsets.all(2.5),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          color: color,
          shape: pw.BoxShape.circle,
        ),
      ),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
