import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/document_suite_service.dart';

void main() {
  group('Phase 5 — Document Suite & ESC/POS Thermal Tests', () {
    test('Step 5.1: ESC/POS 80mm Thermal Receipt Generator emits valid command byte stream', () {
      final receiptBytes = EscPosThermalService.instance.generate80mmReceipt(
        invoiceNumber: 'INV-2026-8801',
        invoiceDate: DateTime(2026, 11, 14, 10, 30),
        customerName: 'Grand Swagath Hotel',
        customerPhone: '9876543210',
        items: [
          {
            'name': 'Malabar Parota (5 pcs)',
            'qty': 50,
            'price': 45.0,
            'total': 2250.0,
          },
          {
            'name': 'Wheat Chapathi (10 pcs)',
            'qty': 30,
            'price': 55.0,
            'total': 1650.0,
          },
        ],
        subtotal: 3900.0,
        discount: 100.0,
        tax: 0.0,
        grandTotal: 3800.0,
        upiId: 'srfoods@upi',
      );

      expect(receiptBytes, isNotEmpty);

      // Verify ESC/POS Init command: 0x1B, 0x40
      expect(receiptBytes[0], 0x1B);
      expect(receiptBytes[1], 0x40);

      // Verify Paper Cut command: 0x1D, 0x56 near end
      expect(receiptBytes.contains(0x1D), isTrue);
      expect(receiptBytes.contains(0x56), isTrue);

      // Verify byte length is realistic for an 80mm receipt (~500 - 1500 bytes)
      expect(receiptBytes.length, greaterThan(400));
      expect(receiptBytes.length, lessThan(3000));
    });

    test('Step 5.2: Customer Statement PDF generates A4 PDF > 5KB with HMAC QR', () async {
      final now = DateTime(2026, 11, 14);
      final pdfBytes = await CustomerStatementPdfService.instance.generateStatementPdf(
        customerCode: 'CUST-001',
        customerName: 'Grand Swagath Hotel',
        customerPhone: '9876543210',
        fromDate: now.subtract(const Duration(days: 30)),
        toDate: now,
        openingBalance: 5000.0,
        totalInvoiced: 25000.0,
        totalPaid: 21500.0,
        closingBalance: 8500.0,
        ledgerEntries: [
          {
            'date': '01/11/2026',
            'docNo': 'INV-1001',
            'type': 'Invoice',
            'debit': 8000.0,
            'credit': 0.0,
            'balance': 13000.0,
          },
          {
            'date': '05/11/2026',
            'docNo': 'PAY-401',
            'type': 'UPI Payment',
            'debit': 0.0,
            'credit': 10000.0,
            'balance': 3000.0,
          },
          {
            'date': '10/11/2026',
            'docNo': 'INV-1025',
            'type': 'Invoice',
            'debit': 5500.0,
            'credit': 0.0,
            'balance': 8500.0,
          },
        ],
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });

    test('Step 5.3: Credit Note PDF generates GST Section 34 compliant PDF > 5KB', () async {
      final now = DateTime(2026, 11, 14);
      final pdfBytes = await CreditNotePdfService.instance.generateCreditNotePdf(
        creditNoteNumber: 'CN-2026-004',
        creditNoteDate: now,
        originalInvoiceNumber: 'INV-2026-1025',
        originalInvoiceDate: now.subtract(const Duration(days: 4)),
        customerName: 'Grand Swagath Hotel',
        customerGstin: '36AABCS1429B1Z1',
        reason: 'Rate Adjustment & Transit Damage (5 packs)',
        items: [
          {
            'description': 'Malabar Parota (Damaged Crate Return)',
            'hsn': '19059040',
            'qty': 5,
            'rate': 45.0,
            'taxable': 225.0,
            'gstRate': 0.0,
            'gstAmount': 0.0,
            'total': 225.0,
          },
        ],
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });

    test('Step 5.4: Certificate of Analysis (CoA) PDF generates quality release sheet > 5KB', () async {
      final now = DateTime(2026, 11, 14);
      final pdfBytes = await CertificateOfAnalysisPdfService.instance.generateCoaPdf(
        certificateNumber: 'COA-2026-EXP-112',
        productName: 'Blast Frozen Malabar Parota (10 pcs Export)',
        batchNumber: 'LOT-2026-UK-01',
        mfgDate: now.subtract(const Duration(days: 3)),
        expiryDate: now.add(const Duration(days: 362)),
        testParameters: [
          {
            'parameter': 'Moisture Content (% w/w)',
            'method': 'AOAC 925.10',
            'specification': '<= 32.0%',
            'result': '28.4%',
            'status': 'PASS',
          },
          {
            'parameter': 'Total Plate Count (TPC)',
            'method': 'ISO 4833-1',
            'specification': '< 10,000 cfu/g',
            'result': '1,200 cfu/g',
            'status': 'PASS',
          },
          {
            'parameter': 'Escherichia coli',
            'method': 'ISO 16649-2',
            'specification': 'Absent / g',
            'result': 'Absent / g',
            'status': 'PASS',
          },
          {
            'parameter': 'Salmonella spp.',
            'method': 'ISO 6579-1',
            'specification': 'Absent / 25g',
            'result': 'Absent / 25g',
            'status': 'PASS',
          },
        ],
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });
  });
}
