import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../domain/money.dart';
import '../utils/formatters.dart';

class GstInvoiceService {
  GstInvoiceService._();
  static final GstInvoiceService instance = GstInvoiceService._();

  // Indian Food & FMCG Compliance Constants
  static const String fssaiLicenseNumber = '10123999000123';
  static const String gstinNumber = '37AAAAA0000A1Z5';
  static const String stateName = 'Andhra Pradesh';
  static const String stateCode = '37';
  static const String defaultHsnCode = '1905'; // Bakery & Ready-to-cook wheat products
  static const String defaultUpiId = '9440067933@ybl';

  /// Generate standard A4 Tax Invoice with GST breakdown & UPI QR
  Future<Uint8List> generateA4TaxInvoice({
    required Invoice invoice,
    required Customer? customer,
    required List<OrderItem> items,
    String? eWayBillNumber,
    String upiId = defaultUpiId,
  }) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    final grandTotalMoney = Money.fromRupees(invoice.grandTotal);
    final upiUri = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(AppConfig.businessName)}&am=${grandTotalMoney.inRupees.toStringAsFixed(2)}&cu=INR&tn=Invoice%20${invoice.invoiceNumber}';

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
                      pw.Text(
                        AppConfig.businessName,
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                      ),
                      pw.Text('Smart Food Manufacturing & Wholesale Distribution', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 3),
                      pw.Text('GSTIN: $gstinNumber • FSSAI: $fssaiLicenseNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('State: $stateName (Code: $stateCode)', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(color: PdfColors.green800, borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Text('TAX INVOICE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice No: ${invoice.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Date: ${DateFormatter.toInvoiceDate(invoice.invoiceDate)}', style: const pw.TextStyle(fontSize: 10)),
                      if (eWayBillNumber != null && eWayBillNumber.isNotEmpty)
                        pw.Text('E-Way Bill: $eWayBillNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.green800),
              pw.SizedBox(height: 8),

              // Billed To Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO (RECIPIENT):', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                        pw.Text(customer?.shopName ?? 'Retail Customer', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if (customer != null && customer.ownerName.isNotEmpty)
                          pw.Text('Proprietor: ${customer.ownerName}', style: const pw.TextStyle(fontSize: 9)),
                        if (customer != null)
                          pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 9)),
                        if (customer?.address != null)
                          pw.Text('Address: ${customer!.address}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Place of Supply: $stateName ($stateCode)', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Reverse Charge: NO', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Payment Terms: Net Due', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Itemized Table with HSN & GST
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
                data: [
                  ['Item Description', 'HSN', 'Qty', 'Rate', 'Total'],
                  ...items.map((i) => [
                        i.productName,
                        defaultHsnCode,
                        '${i.quantity} pkts',
                        CurrencyFormatter.format(i.price),
                        CurrencyFormatter.format(i.total),
                      ]),
                ],
              ),
              pw.SizedBox(height: 12),

              // Bottom Section: Summary & UPI QR Code
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // UPI QR Code
                  pw.Container(
                    width: 140,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('SCAN TO PAY VIA UPI', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.BarcodeWidget(
                          data: upiUri,
                          barcode: pw.Barcode.qrCode(),
                          width: 80,
                          height: 80,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(upiId, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Spacer(),

                  // Financial Totals Box
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        _pdfRow('Subtotal', CurrencyFormatter.format(invoice.subtotal)),
                        if (invoice.discount > 0)
                          _pdfRow('Discount', '-${CurrencyFormatter.format(invoice.discount)}', color: PdfColors.red700),
                        _pdfRow('CGST (2.5%)', CurrencyFormatter.format(invoice.subtotal * 0.025)),
                        _pdfRow('SGST (2.5%)', CurrencyFormatter.format(invoice.subtotal * 0.025)),
                        pw.Divider(thickness: 0.5),
                        _pdfRow('Grand Total', CurrencyFormatter.format(invoice.grandTotal), bold: true),
                        _pdfRow('Amount Paid', CurrencyFormatter.format(invoice.paidAmount)),
                        _pdfRow('Balance Due', CurrencyFormatter.format(invoice.pendingAmount), bold: true, color: PdfColors.red800),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('FSSAI Lic. No: $fssaiLicenseNumber • Quality You Can Trust', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('Authorized Signatory for SR Foods', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate 58mm / 80mm ESC/POS Thermal Receipt Layout for portable van printers
  Future<Uint8List> generateThermalReceipt({
    required Invoice invoice,
    required Customer? customer,
    required List<OrderItem> items,
    bool is80mm = false,
  }) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final width = is80mm ? 80 * PdfPageFormat.mm : 58 * PdfPageFormat.mm;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, double.infinity, marginAll: 3 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(AppConfig.businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Wholesale Food ERP', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('FSSAI: $fssaiLicenseNumber', style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Phone: 9440067933', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Inv: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateFormatter.toInvoiceDate(invoice.invoiceDate)}', style: const pw.TextStyle(fontSize: 8)),
                    if (customer != null) ...[
                      pw.Text('Shop: ${customer.shopName}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Tel: ${customer.phone}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ],
                ),
              ),
              pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(children: [
                    pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.Text('Total', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                  ]),
                  ...items.map((i) => pw.TableRow(children: [
                        pw.Text(i.productName, style: const pw.TextStyle(fontSize: 7.5)),
                        pw.Text('${i.quantity}', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center),
                        pw.Text(CurrencyFormatter.format(i.total), style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.right),
                      ])),
                ],
              ),
              pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Amount:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(CurrencyFormatter.format(invoice.grandTotal), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Paid Amount:', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(CurrencyFormatter.format(invoice.paidAmount), style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Balance Due:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(CurrencyFormatter.format(invoice.pendingAmount), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                data: 'upi://pay?pa=$defaultUpiId&am=${invoice.grandTotal}&pn=SRFoods',
                barcode: pw.Barcode.qrCode(),
                width: 60,
                height: 60,
              ),
              pw.SizedBox(height: 4),
              pw.Text('Scan to Pay via UPI', style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Thank You! Visit Again.', style: const pw.TextStyle(fontSize: 7)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Food Safety Batch Sticker / Label for packaging
  Future<Uint8List> generateBatchLabel({
    required Product product,
    required String batchNumber,
    required DateTime mfgDate,
    required DateTime expiryDate,
    required int piecesPerPack,
    required double weightGrams,
  }) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(70 * PdfPageFormat.mm, 50 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              border: pw.TableBorder.all(width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SR FOODS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('FSSAI: $fssaiLicenseNumber', style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.Divider(thickness: 0.5),
                pw.Text(product.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Net Wt: ${weightGrams.toStringAsFixed(0)}g • Pcs: $piecesPerPack', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Batch: $batchNumber', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('Mfg Date: ${DateFormatter.toDate(mfgDate)}', style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('Best Before: ${DateFormatter.toDate(expiryDate)}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                pw.Spacer(),
                pw.Text('Allergen: Contains Wheat / Gluten. Store below 25°C.', style: const pw.TextStyle(fontSize: 6)),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
