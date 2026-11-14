import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportBankDetails {
  final String bankName;
  final String branchAddress;
  final String accountNo;
  final String swiftCode;
  final String adCode; // Authorized Dealer Code for DGFT / RBI EDPMS tracking
  final String iban;

  const ExportBankDetails({
    this.bankName = 'State Bank of India',
    this.branchAddress = 'Overseas Branch, Hyderabad, India',
    this.accountNo = '40912345678',
    this.swiftCode = 'SBININBB081',
    this.adCode = '0370012',
    this.iban = 'IN08SBIN000040912345678',
  });
}

class ExportInvoiceLineItem {
  final int lineNo;
  final String description;
  final String hsCode;
  final int cartonCount;
  final int unitsPerCarton;
  final int totalUnits;
  final double unitPrice;
  final double totalAmount;

  const ExportInvoiceLineItem({
    required this.lineNo,
    required this.description,
    required this.hsCode,
    required this.cartonCount,
    required this.unitsPerCarton,
    required this.totalUnits,
    required this.unitPrice,
    required this.totalAmount,
  });
}

class ExportInvoiceData {
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String lutNumber; // Letter of Undertaking for 0% IGST export
  final String iecNumber; // DGFT Importer-Exporter Code
  final String exporterGstin;
  final String exporterName;
  final String exporterAddress;
  final String consigneeName;
  final String consigneeAddress;
  final String? consigneeTaxId;
  final String incoterm; // e.g. "CIF Jebel Ali", "DDP New York"
  final String portOfLoading;
  final String portOfDischarge;
  final String countryOfFinalDestination;
  final String currency;
  final double fxRateToInr;
  final List<ExportInvoiceLineItem> items;
  final double freightCharge;
  final double insuranceCharge;
  final ExportBankDetails bankDetails;

  const ExportInvoiceData({
    required this.invoiceNumber,
    required this.invoiceDate,
    this.lutNumber = 'AD370326001234F',
    this.iecNumber = '0712034912',
    this.exporterGstin = '37AAAAA0000A1Z5',
    this.exporterName = 'SR FOODS INDIA PRIVATE LIMITED',
    this.exporterAddress = 'Plot 12, Food Processing SEZ, Hyderabad, Telangana, 500072, India',
    required this.consigneeName,
    required this.consigneeAddress,
    this.consigneeTaxId,
    required this.incoterm,
    this.portOfLoading = 'Nhava Sheva, India (INNSA)',
    required this.portOfDischarge,
    required this.countryOfFinalDestination,
    required this.currency,
    this.fxRateToInr = 1.0,
    required this.items,
    this.freightCharge = 0.0,
    this.insuranceCharge = 0.0,
    this.bankDetails = const ExportBankDetails(),
  });

  double get subtotal => items.fold(0.0, (acc, item) => acc + item.totalAmount);
  double get grandTotal => subtotal + freightCharge + insuranceCharge;
}

class ExportPackingListLineItem {
  final String cartonNumberRange;
  final String description;
  final int cartonCount;
  final double netWeightKg;
  final double grossWeightKg;
  final String dimensionsCm;
  final double cbm;

  const ExportPackingListLineItem({
    required this.cartonNumberRange,
    required this.description,
    required this.cartonCount,
    required this.netWeightKg,
    required this.grossWeightKg,
    required this.dimensionsCm,
    required this.cbm,
  });
}

class ExportPackingListData {
  final String invoiceNumber;
  final DateTime date;
  final String consigneeName;
  final String consigneeAddress;
  final List<ExportPackingListLineItem> lines;
  final int totalPallets;
  final String containerNumber;
  final String sealNumber;
  final double targetTemperatureCelsius;

  const ExportPackingListData({
    required this.invoiceNumber,
    required this.date,
    required this.consigneeName,
    required this.consigneeAddress,
    required this.lines,
    this.totalPallets = 10,
    required this.containerNumber,
    required this.sealNumber,
    this.targetTemperatureCelsius = -18.0,
  });

  int get totalCartons => lines.fold(0, (acc, l) => acc + l.cartonCount);
  double get totalNetWeightKg => lines.fold(0.0, (acc, l) => acc + l.netWeightKg);
  double get totalGrossWeightKg => lines.fold(0.0, (acc, l) => acc + l.grossWeightKg);
  double get totalCbm => lines.fold(0.0, (acc, l) => acc + l.cbm);
}

class ExportInvoicePdfService {
  const ExportInvoicePdfService();

  /// Generate comprehensive Zero-Rated Commercial Export Invoice adhering to
  /// Indian Customs, GST LUT rules, Incoterms 2020, and International Trade Banking
  Future<Uint8List> generateCommercialInvoice(ExportInvoiceData invoice) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: false);
    final df = DateFormat('dd-MMM-yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'COMMERCIAL EXPORT INVOICE',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'SUPPLY MEANT FOR EXPORT UNDER LETTER OF UNDERTAKING (LUT) WITHOUT PAYMENT OF INTEGRATED TAX (IGST)',
                        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                      ),
                      pw.Text(
                        'LUT ARN: ${invoice.lutNumber} | IEC: ${invoice.iecNumber} | GSTIN: ${invoice.exporterGstin}',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE NO: ${invoice.invoiceNumber}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('DATE: ${df.format(invoice.invoiceDate)}',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('CURRENCY: ${invoice.currency}',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, height: 10),

              // Parties Table
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Exporter Box
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('EXPORTER / MANUFACTURER:',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text(invoice.exporterName,
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoice.exporterAddress, style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('Country of Origin: India', style: const pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Consignee Box
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CONSIGNEE / BUYER:',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text(invoice.consigneeName,
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoice.consigneeAddress, style: const pw.TextStyle(fontSize: 7)),
                          if (invoice.consigneeTaxId != null)
                            pw.Text('Tax / VAT ID: ${invoice.consigneeTaxId}', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('Destination Country: ${invoice.countryOfFinalDestination}',
                              style: const pw.TextStyle(fontSize: 7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),

              // Shipment Terms Bar
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: PdfColors.grey100,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('INCOTERMS 2020: ${invoice.incoterm}',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('PORT OF LOADING: ${invoice.portOfLoading}', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('PORT OF DISCHARGE: ${invoice.portOfDischarge}', style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Itemized Table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(3.5),
                  2: const pw.FixedColumnWidth(55),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FixedColumnWidth(45),
                  5: const pw.FixedColumnWidth(55),
                  6: const pw.FixedColumnWidth(65),
                },
                headers: ['#', 'DESCRIPTION OF GOODS', 'HS CODE', 'CTNS', 'QTY (PCS)', 'RATE (${invoice.currency})', 'TOTAL (${invoice.currency})'],
                data: invoice.items.map((it) {
                  return [
                    it.lineNo.toString(),
                    it.description,
                    it.hsCode,
                    it.cartonCount.toString(),
                    it.totalUnits.toString(),
                    it.unitPrice.toStringAsFixed(2),
                    it.totalAmount.toStringAsFixed(2),
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 6),

              // Totals & Charges
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bank Details Box
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BANK DETAILS FOR INTERNATIONAL WIRE TRANSFER:',
                              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text('Bank: ${invoice.bankDetails.bankName} (${invoice.bankDetails.branchAddress})',
                              style: const pw.TextStyle(fontSize: 6.5)),
                          pw.Text('Account No: ${invoice.bankDetails.accountNo} | SWIFT: ${invoice.bankDetails.swiftCode}',
                              style: const pw.TextStyle(fontSize: 6.5)),
                          pw.Text('AD Code: ${invoice.bankDetails.adCode} | IBAN: ${invoice.bankDetails.iban}',
                              style: const pw.TextStyle(fontSize: 6.5)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Financial Total Breakdown
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.indigo900, width: 1)),
                      child: pw.Column(
                        children: [
                          _buildPriceRow('Subtotal (FOB):', invoice.subtotal, invoice.currency),
                          _buildPriceRow('Ocean Freight:', invoice.freightCharge, invoice.currency),
                          _buildPriceRow('Marine Insurance:', invoice.insuranceCharge, invoice.currency),
                          pw.Divider(thickness: 1, height: 4),
                          _buildPriceRow('GRAND TOTAL (${invoice.incoterm}):', invoice.grandTotal, invoice.currency,
                              isBold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Declaration & Signatory
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'DECLARATION: We declare that this invoice shows the actual price of the goods described '
                      'and that all particulars are true and correct.\nGoods manufactured in certified export food processing facility under FSSAI license.',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('For SR FOODS INDIA PVT. LTD.',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 24),
                      pw.Text('AUTHORIZED SIGNATORY',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate export Packing List with CBM, Gross/Net Weight, and Cold-Chain Container Specifications
  Future<Uint8List> generatePackingList(ExportPackingListData packingList) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: false);
    final df = DateFormat('dd-MMM-yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EXPORT PACKING LIST',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                      ),
                      pw.Text('SR FOODS INDIA PRIVATE LIMITED',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('REF INVOICE: ${packingList.invoiceNumber}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('DATE: ${df.format(packingList.date)}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, height: 10),

              // Cold Chain & Container Bar
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue800, width: 1)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CONTAINER NO: ${packingList.containerNumber}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('SEAL NO: ${packingList.sealNumber}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('REEFER TEMP TARGET: ${packingList.targetTemperatureCelsius.toStringAsFixed(1)}°C',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('PALLETS: ${packingList.totalPallets}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Packing List Table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal900),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['PACKAGE NOS', 'DESCRIPTION OF GOODS', 'CTNS', 'NET WT (KG)', 'GROSS WT (KG)', 'DIMENSIONS (CM)', 'CBM'],
                data: packingList.lines.map((l) {
                  return [
                    l.cartonNumberRange,
                    l.description,
                    l.cartonCount.toString(),
                    l.netWeightKg.toStringAsFixed(1),
                    l.grossWeightKg.toStringAsFixed(1),
                    l.dimensionsCm,
                    l.cbm.toStringAsFixed(3),
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 8),

              // Summary Box
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                color: PdfColors.grey100,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('TOTAL CARTONS: ${packingList.totalCartons}',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('TOTAL NET WT: ${packingList.totalNetWeightKg.toStringAsFixed(1)} KG',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('TOTAL GROSS WT: ${packingList.totalGrossWeightKg.toStringAsFixed(1)} KG',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('TOTAL VOLUME: ${packingList.totalCbm.toStringAsFixed(3)} CBM',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signatory
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Temperature-controlled cargo dispatched in intact Reefer container.',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('For SR FOODS INDIA PVT. LTD.',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 20),
                      pw.Text('EXPORT LOGISTICS MANAGER',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPriceRow(String label, double amount, String currency, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('$currency ${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 7, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
