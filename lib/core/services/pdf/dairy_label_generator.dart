import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Data model representing a compliant dairy packaging label
class DairyLabelData {
  final String sku;
  final String productName;
  final String batchNumber;
  final DateTime mfgDate;
  final DateTime useByDate;
  final String netQuantity;
  final double fatPercent;
  final double snfPercent;
  final String milkType; // Cow, Buffalo, Mixed
  final String pasteurizationStandard;
  final String fssaiCategoryCode;
  final String fssaiLicense;
  final String storageCondition;
  final String manufacturerAddress;
  final String chillingCenter;

  const DairyLabelData({
    required this.sku,
    required this.productName,
    required this.batchNumber,
    required this.mfgDate,
    required this.useByDate,
    required this.netQuantity,
    this.fatPercent = 4.5,
    this.snfPercent = 8.5,
    this.milkType = 'Cow Milk',
    this.pasteurizationStandard = 'HTST Pasteurised (72°C for 15 sec)',
    this.fssaiCategoryCode = 'FCS 01.1.2 (Pasteurised Milk)',
    this.fssaiLicense = '10123999000123',
    this.storageCondition = 'Store refrigerated at 4°C or below. Consume within 48h of opening.',
    this.manufacturerAddress = 'SR Foods Dairy Division, Plot 14, Chilled Hub, Shamshabad, Hyderabad - 501218',
    this.chillingCenter = 'SR Chilling Unit 2 - Medak',
  });
}

/// Service generating FSSAI FCS 01.x compliant dairy product labels
class DairyLabelGenerator {
  const DairyLabelGenerator();

  Future<Uint8List> generateDairyLabel(DairyLabelData data) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnly = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm, marginAll: 6 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with Green Veg Mark & Brand
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SR FOODS DAIRY',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          'COLD CHAIN FRESH',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.blue700, letterSpacing: 1),
                        ),
                      ],
                    ),
                    // FSSAI Green Veg Dot
                    _buildVegMark(),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.grey400),

                // Product Title
                pw.SizedBox(height: 2),
                pw.Text(
                  data.productName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${data.milkType} • Standardized & Homogenized',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 6),

                // Dairy Composition Box (Fat & SNF)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _specColumn('MILK FAT', '${data.fatPercent.toStringAsFixed(1)}% Min'),
                      _specColumn('SNF', '${data.snfPercent.toStringAsFixed(1)}% Min'),
                      _specColumn('NET QTY', data.netQuantity),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // Pasteurization & Safety
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 8,
                        height: 8,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.green700,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Expanded(
                        child: pw.Text(
                          '${data.pasteurizationStandard} - Phosphatase Negative',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // Traceability & Dates Table
                _infoRow('Batch No:', data.batchNumber),
                _infoRow('SKU Code:', data.sku),
                _infoRow('Packed At:', dateFormat.format(data.mfgDate)),
                _infoRow('USE BY DATE:', dateOnly.format(data.useByDate), isBold: true, valueColor: PdfColors.red900),
                _infoRow('Chilling Center:', data.chillingCenter),
                pw.SizedBox(height: 4),

                // Storage Alert
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(4),
                  color: PdfColors.blueGrey50,
                  child: pw.Text(
                    'STORAGE: ${data.storageCondition}',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                ),
                pw.SizedBox(height: 6),

                // Regulatory FSSAI & Manufacturer
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

  pw.Widget _buildVegMark() {
    return pw.Container(
      width: 16,
      height: 16,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green800, width: 1.5),
      ),
      padding: const pw.EdgeInsets.all(2.5),
      child: pw.Container(
        decoration: const pw.BoxDecoration(
          color: PdfColors.green800,
          shape: pw.BoxShape.circle,
        ),
      ),
    );
  }

  pw.Widget _specColumn(String title, String val) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
        pw.SizedBox(height: 1),
        pw.Text(val, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
      ],
    );
  }

  pw.Widget _infoRow(String label, String value, {bool isBold = false, PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
