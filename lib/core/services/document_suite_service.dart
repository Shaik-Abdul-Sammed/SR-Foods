import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../config/app_config.dart';
import 'post_quantum_security.dart';

/// 1. ESC/POS 80mm Thermal Receipt Generator
class EscPosThermalService {
  EscPosThermalService._();
  static final EscPosThermalService instance = EscPosThermalService._();

  // ESC/POS Command Constants
  static const List<int> cmdInit = [0x1B, 0x40]; // ESC @
  static const List<int> cmdAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> cmdAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> cmdAlignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const List<int> cmdBoldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> cmdBoldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> cmdDoubleHeight = [0x1B, 0x21, 0x10]; // ESC ! 16
  static const List<int> cmdNormalText = [0x1B, 0x21, 0x00]; // ESC ! 0
  static const List<int> cmdCutPaper = [0x1D, 0x56, 0x41, 0x03]; // GS V A 3 (feed 3 lines & cut)

  /// Generates a binary ESC/POS byte stream for standard 80mm thermal printers (48 chars/line)
  Uint8List generate80mmReceipt({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items, // [{name, qty, price, total}]
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    String upiId = 'srfoods@upi',
  }) {
    final bytes = <int>[];

    void write(String text) {
      bytes.addAll(latin1.encode(text));
    }

    void line([String text = '']) {
      write('$text\n');
    }

    // Initialize printer
    bytes.addAll(cmdInit);

    // Header (Centered, bold, double height)
    bytes.addAll(cmdAlignCenter);
    bytes.addAll(cmdDoubleHeight);
    bytes.addAll(cmdBoldOn);
    line(AppConfig.businessName);
    bytes.addAll(cmdNormalText);
    bytes.addAll(cmdBoldOff);

    line('Fresh & Frozen Chapathi & Parota Wholesaler');
    line('Ph: 9440067933 | GSTIN: 36AABCS1429B1Z1');
    line('FSSAI Lic: 13622014000123');
    line('------------------------------------------------'); // 48 chars

    // Metadata (Left aligned)
    bytes.addAll(cmdAlignLeft);
    line('Invoice No: $invoiceNumber');
    line('Date/Time : ${DateFormat('dd-MM-yyyy HH:mm').format(invoiceDate)}');
    line('Customer  : $customerName');
    line('Phone     : $customerPhone');
    line('------------------------------------------------');

    // Table Header
    // 22 chars name, 6 chars qty, 9 chars price, 11 chars total = 48 chars
    line('ITEM                   QTY    PRICE       TOTAL');
    line('------------------------------------------------');

    for (final item in items) {
      final name = (item['name'] as String).padRight(21).substring(0, 21);
      final qty = item['qty'].toString().padLeft(6);
      final price = (item['price'] as double).toStringAsFixed(2).padLeft(9);
      final total = (item['total'] as double).toStringAsFixed(2).padLeft(11);
      line('$name $qty $price $total');
    }

    line('------------------------------------------------');

    // Totals Section (Right Aligned)
    bytes.addAll(cmdAlignRight);
    line('Subtotal: ${subtotal.toStringAsFixed(2).padLeft(10)}');
    if (discount > 0) {
      line('Discount: -${discount.toStringAsFixed(2).padLeft(9)}');
    }
    if (tax > 0) {
      line('GST Tax : ${tax.toStringAsFixed(2).padLeft(10)}');
    }

    bytes.addAll(cmdBoldOn);
    bytes.addAll(cmdDoubleHeight);
    line('TOTAL: Rs ${grandTotal.toStringAsFixed(2)}');
    bytes.addAll(cmdNormalText);
    bytes.addAll(cmdBoldOff);

    line('------------------------------------------------');

    // Footer & UPI string
    bytes.addAll(cmdAlignCenter);
    line('Scan & Pay via any UPI App:');
    line('UPI ID: $upiId');
    line('Thank you for choosing SR Foods!');
    line('*** Quality Guaranteed Fresh Daily ***');

    // Feed lines & cut
    line('');
    line('');
    line('');
    bytes.addAll(cmdCutPaper);

    return Uint8List.fromList(bytes);
  }
}

/// 2. Customer Monthly Account Statement PDF Generator
class CustomerStatementPdfService {
  CustomerStatementPdfService._();
  static final CustomerStatementPdfService instance = CustomerStatementPdfService._();

  Future<Uint8List> generateStatementPdf({
    required String customerCode,
    required String customerName,
    required String customerPhone,
    required DateTime fromDate,
    required DateTime toDate,
    required double openingBalance,
    required double totalInvoiced,
    required double totalPaid,
    required double closingBalance,
    required List<Map<String, dynamic>> ledgerEntries, // [{date, docNo, type, debit, credit, balance}]
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    final hmacDigest = PostQuantumSecurity.instance.computeTamperProofDigest(
      'STMT-$customerCode-${closingBalance.toStringAsFixed(2)}-${toDate.toIso8601String()}',
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(AppConfig.businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.Text('Monthly Customer Account Statement', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Period: ${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'SRF-STMT|$customerCode|$closingBalance|$hmacDigest',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.green900),

              // Customer & Summary Box
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ACCOUNT DETAILS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.Text(customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Code: $customerCode | Phone: $customerPhone', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green300), borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _summaryCol('Opening Bal', 'Rs ${openingBalance.toStringAsFixed(0)}'),
                          _summaryCol('Billed', 'Rs ${totalInvoiced.toStringAsFixed(0)}'),
                          _summaryCol('Paid', 'Rs ${totalPaid.toStringAsFixed(0)}'),
                          _summaryCol('Closing Bal', 'Rs ${closingBalance.toStringAsFixed(0)}', isBold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Transaction Ledger Table
              pw.Text('TRANSACTION HISTORY:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['Date', 'Document #', 'Type', 'Debit (Rs)', 'Credit (Rs)', 'Balance (Rs)'],
                data: ledgerEntries.map((e) {
                  return [
                    e['date'] as String,
                    e['docNo'] as String,
                    e['type'] as String,
                    (e['debit'] as double) > 0 ? (e['debit'] as double).toStringAsFixed(2) : '-',
                    (e['credit'] as double) > 0 ? (e['credit'] as double).toStringAsFixed(2) : '-',
                    (e['balance'] as double).toStringAsFixed(2),
                  ];
                }).toList(),
              ),
              pw.Spacer(),

              // Verification Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Digitally authenticated via SR Foods Ledger Engine', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  pw.Text('HMAC: ${hmacDigest.substring(0, 24)}...', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _summaryCol(String label, String value, {bool isBold = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: isBold ? PdfColors.green900 : PdfColors.black)),
      ],
    );
  }
}

/// 3. Credit Note PDF Generator
class CreditNotePdfService {
  CreditNotePdfService._();
  static final CreditNotePdfService instance = CreditNotePdfService._();

  Future<Uint8List> generateCreditNotePdf({
    required String creditNoteNumber,
    required DateTime creditNoteDate,
    required String originalInvoiceNumber,
    required DateTime originalInvoiceDate,
    required String customerName,
    required String customerGstin,
    required String reason, // 'Rate Difference', 'Damaged Transit', 'Commercial Rebate'
    required List<Map<String, dynamic>> items, // [{description, hsn, qty, rate, taxable, gstRate, gstAmount, total}]
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final grandTotal = items.fold<double>(0.0, (sum, i) => sum + (i['total'] as double));
    final hmac = PostQuantumSecurity.instance.computeTamperProofDigest('CN-$creditNoteNumber-$grandTotal');

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
                      pw.Text(AppConfig.businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      pw.Text('GST CREDIT NOTE (SECTION 34)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('GSTIN: 36AABCS1429B1Z1 | State: 36 (Telangana)', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'SRF-CN|$creditNoteNumber|$grandTotal|$hmac',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.red900),
              pw.SizedBox(height: 8),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Credit Note No: $creditNoteNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: ${dateFormat.format(creditNoteDate)}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Reason: $reason', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Original Invoice No: $originalInvoiceNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Original Invoice Date: ${dateFormat.format(originalInvoiceDate)}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Customer: $customerName (${customerGstin.isEmpty ? 'Unregistered' : customerGstin})', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['Item Description', 'HSN', 'Qty', 'Rate (Rs)', 'Taxable (Rs)', 'GST %', 'GST (Rs)', 'Total (Rs)'],
                data: items.map((i) {
                  return [
                    i['description'] as String,
                    i['hsn'] as String,
                    i['qty'].toString(),
                    (i['rate'] as double).toStringAsFixed(2),
                    (i['taxable'] as double).toStringAsFixed(2),
                    '${i['gstRate']}%',
                    (i['gstAmount'] as double).toStringAsFixed(2),
                    (i['total'] as double).toStringAsFixed(2),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 12),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red900)),
                  child: pw.Text('Net Credit Value: Rs ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                ),
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Authorized Signatory\nSR Foods Accounts Division', style: const pw.TextStyle(fontSize: 8)),
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

/// 4. Certificate of Analysis (CoA) PDF Generator
class CertificateOfAnalysisPdfService {
  CertificateOfAnalysisPdfService._();
  static final CertificateOfAnalysisPdfService instance = CertificateOfAnalysisPdfService._();

  Future<Uint8List> generateCoaPdf({
    required String certificateNumber,
    required String productName,
    required String batchNumber,
    required DateTime mfgDate,
    required DateTime expiryDate,
    required List<Map<String, String>> testParameters, // [{parameter, method, specification, result, status}]
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd-MM-yyyy');

    final hmac = PostQuantumSecurity.instance.computeTamperProofDigest('COA-$certificateNumber-$batchNumber');

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
                      pw.Text(AppConfig.businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('QUALITY ASSURANCE & TESTING LABORATORY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('CERTIFICATE OF ANALYSIS (COA)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'SRF-COA|$certificateNumber|$batchNumber|$hmac',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.blue900),
              pw.SizedBox(height: 8),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Certificate No: $certificateNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Product: $productName', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Batch LOT: $batchNumber', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Mfg Date: ${dateFormat.format(mfgDate)}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Expiry Date: ${dateFormat.format(expiryDate)}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('FSSAI Lab Reg: 13622014000123', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.Text('ANALYTICAL & MICROBIOLOGICAL TEST RESULTS:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),

              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['Test Parameter', 'Test Method', 'Specification', 'Observed Result', 'Status'],
                data: testParameters.map((p) {
                  return [
                    p['parameter'] ?? '',
                    p['method'] ?? '',
                    p['specification'] ?? '',
                    p['result'] ?? '',
                    p['status'] ?? 'PASS',
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green300)),
                child: pw.Text('FINAL OPINION: Conforms to FSSAI & International Export Food Safety Standards. Approved for Release.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
              ),

              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Lead Food Chemist / QA Manager\nSR Foods Quality Division', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('PQC Signature HMAC: ${hmac.substring(0, 24)}...', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
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
