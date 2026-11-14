import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sr_foods/core/config/app_config.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/qr_service.dart';

/// Generates laminated A5 landscape counter placards for hotels and restaurants
/// Features customer-specific signed QR code for instant 10-second reorders
class ReorderPlacardPdfService {
  ReorderPlacardPdfService._();
  static final ReorderPlacardPdfService instance = ReorderPlacardPdfService._();

  Future<Uint8List> generateA5ReorderPlacard({
    required Customer customer,
    required List<Product> favoriteProducts,
    DateTime? validUntil,
  }) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final expiry = validUntil ?? DateTime.now().add(const Duration(days: 365));

    final reorderQrUrl = QrService.instance.generateReorderQr(
      customerId: customer.id,
      customerCode: customer.code,
      validUntil: expiry,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.TableBorder.all(color: PdfColors.green800, width: 3),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            padding: const pw.EdgeInsets.all(20),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Left Column: Branding, Customer Name, Instructions
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            AppConfig.businessName,
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                          pw.Text(
                            'Fresh & Frozen Chapathi, Parota, Pulka Manufacturer',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.green50,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'DEDICATED WHOLESALE ACCOUNT:',
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                                ),
                                pw.Text(
                                  customer.shopName,
                                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text(
                                  'Customer Code: ${customer.code} | Contact: ${customer.ownerName} (${customer.phone})',
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'HOW TO REORDER IN 10 SECONDS:',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('1. Open your smartphone camera or any QR scanner.', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('2. Point camera at the QR code on the right.', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('3. Review your standard daily basket and tap Confirm Delivery.', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.SizedBox(height: 6),
                          pw.Text('Direct Dispatch Helpline: 9440067933 / 9494949494', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 16),

                // Right Column: Big Scannable QR Code
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: reorderQrUrl,
                          width: 130,
                          height: 130,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'SCAN TO REORDER',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                      pw.Text(
                        'Secured with Quantum-Resistant HMAC',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
