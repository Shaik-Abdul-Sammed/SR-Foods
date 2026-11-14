import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../config/app_config.dart';
import 'post_quantum_security.dart';

/// Service generating official export regulatory certificates
class ExportCertificateService {
  ExportCertificateService._();
  static final ExportCertificateService instance = ExportCertificateService._();

  /// 1. Health / Sanitary Export Certificate (EIC / FSSAI format)
  Future<Uint8List> generateHealthCertificatePdf({
    required String certificateNumber,
    required String consigneeName,
    required String destinationCountry,
    required String commodityDescription,
    required String batchLotNumber,
    required int cartonCount,
    required double netWeightKg,
    required double grossWeightKg,
    required DateTime mfgDate,
    required DateTime expiryDate,
    String portOfLoading = 'JNPT / Chennai, India',
    String containerNumber = 'MSCU-902144-8 (Reefer -18°C)',
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final hmac = PostQuantumSecurity.instance.computeTamperProofDigest('HEALTH-$certificateNumber-$batchLotNumber');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GOVERNMENT OF INDIA / FSSAI', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      pw.Text('EXPORT SANITARY & HEALTH CERTIFICATE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('For Export of Cereal & Wheat Flour Ready-to-Cook Flatbreads', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'SRF-HEALTH|$certificateNumber|$batchLotNumber|$hmac',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.blue900),
              pw.SizedBox(height: 8),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Certificate No: $certificateNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Exporter: ${AppConfig.businessName}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('FSSAI Central Export Lic: 13622014000123', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Port of Loading: $portOfLoading', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Consignee: $consigneeName', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Destination Country: $destinationCountry', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Container: $containerNumber', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Date of Issue: ${dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              pw.Text('CONSIGNMENT IDENTIFICATION:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['Commodity', 'HS Code', 'Batch LOT', 'Cartons', 'Net Wt (Kg)', 'Gross Wt (Kg)'],
                data: [
                  [commodityDescription, '1905.90.90', batchLotNumber, '$cartonCount ctns', '${netWeightKg.toStringAsFixed(1)} kg', '${grossWeightKg.toStringAsFixed(1)} kg'],
                ],
              ),
              pw.SizedBox(height: 14),

              pw.Text('SANITARY DECLARATION:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('1. The goods were prepared in an FSSAI & ISO 22000 certified facility under strict GMP hygiene standards.', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('2. Free from harmful pesticide residues, artificial aflatoxins, mycotoxins, and heavy metals.', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('3. Blast frozen at -35°C and preserved at -18°C or colder throughout storage and shipping.', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('4. Fit for human consumption in all respects according to $destinationCountry food safety regulations.', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Competent Authority / Authorized Export Inspector\nFood Safety and Standards Authority of India (FSSAI)', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Verified Seal HMAC: ${hmac.substring(0, 24)}...', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// 2. Certificate of Origin (Chamber of Commerce Format)
  Future<Uint8List> generateCertificateOfOriginPdf({
    required String certificateNumber,
    required String consigneeName,
    required String destinationCountry,
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<Map<String, dynamic>> items, // [{marks, description, hsCode, qty, grossWeight}]
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final hmac = PostQuantumSecurity.instance.computeTamperProofDigest('COO-$certificateNumber-$invoiceNumber');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FEDERATION OF INDIAN EXPORT ORGANISATIONS (FIEO)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.brown800)),
                      pw.Text('CERTIFICATE OF ORIGIN (NON-PREFERENTIAL)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)),
                      pw.Text('Country of Origin: REPUBLIC OF INDIA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'SRF-COO|$certificateNumber|$invoiceNumber|$hmac',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.brown900),
              pw.SizedBox(height: 8),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Certificate No: $certificateNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Shipper: ${AppConfig.businessName}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('IEC Code: 0912048591 (DGFT)', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Consignee: $consigneeName', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Invoice Ref: $invoiceNumber dt. ${dateFormat.format(invoiceDate)}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Final Destination: $destinationCountry', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.brown800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['Marks & Nos', 'Description of Goods', 'HS Tariff Code', 'Quantity', 'Gross Wt (Kg)'],
                data: items.map((i) {
                  return [
                    i['marks'] as String,
                    i['description'] as String,
                    i['hsCode'] as String,
                    i['qty'] as String,
                    i['grossWeight'] as String,
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey400)),
                child: pw.Text('DECLARATION BY THE EXPORTER: The undersigned hereby declares that the above-mentioned goods were produced and manufactured wholly in the Republic of India.', style: const pw.TextStyle(fontSize: 8)),
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Authorized Chamber of Commerce Signatory\nHyderabad, India', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Verified HMAC: ${hmac.substring(0, 24)}...', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// 3. Halal Compliance Certificate
  Future<Uint8List> generateHalalCertificatePdf({
    required String certificateNumber,
    required String productName,
    required String batchLotNumber,
    required DateTime mfgDate,
    required DateTime expiryDate,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final hmac = PostQuantumSecurity.instance.computeTamperProofDigest('HALAL-$certificateNumber-$batchLotNumber');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('HALAL INDIA / GSO 2055-1 ACCREDITED', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      pw.Text('HALAL COMPLIANCE CERTIFICATE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.Text('CERTIFIED HALAL - GSO 2055-1', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'SRF-HALAL|$certificateNumber|$batchLotNumber|$hmac',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.green900),
              pw.SizedBox(height: 12),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green300), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CERTIFICATE NO: $certificateNumber', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.SizedBox(height: 6),
                    pw.Text('Certified Product: $productName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Manufacturer: ${AppConfig.businessName}, Hyderabad, Telangana, India', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Batch LOT: $batchLotNumber', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Production Date: ${dateFormat.format(mfgDate)} | Expiry Date: ${dateFormat.format(expiryDate)}', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              pw.Text('STANDARDS COMPLIANCE & VERIFICATION:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('This is to certify that the above mentioned food product has been audited and verified to comply with Islamic Dietary Laws and GSO 2055-1 / UAE.S 2055-1 / MS 1500 standards.', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Text('- 100% Vegetarian cereal ingredients (Wheat flour, refined oil, salt, potable water).', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('- Free from porcine derivatives, alcohol, animal shortening, or non-halal processing aids.', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('- Dedicated vegetarian production lines with automated CIP sanitation.', style: const pw.TextStyle(fontSize: 8)),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Chairman, Shariah Supervisory Board\nHalal Certification Authority', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Verified HMAC: ${hmac.substring(0, 24)}...', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
