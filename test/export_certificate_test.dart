import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/export_certificate_service.dart';

void main() {
  group('Phase 8 — Export, Regulatory Compliance & Multi-Country Tests', () {
    final now = DateTime(2026, 11, 14);

    test('Step 8.1: Health / Sanitary Export Certificate PDF generates compliant document > 5KB', () async {
      final pdfBytes = await ExportCertificateService.instance.generateHealthCertificatePdf(
        certificateNumber: 'EIC-IN-2026-9021',
        consigneeName: 'Gulf Hypermarkets LLC, Dubai, UAE',
        destinationCountry: 'United Arab Emirates',
        commodityDescription: 'Frozen Malabar Parota (400g x 20 packs/carton)',
        batchLotNumber: 'LOT-2026-DXB-01',
        cartonCount: 500,
        netWeightKg: 4000.0,
        grossWeightKg: 4350.0,
        mfgDate: now.subtract(const Duration(days: 5)),
        expiryDate: now.add(const Duration(days: 360)),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });

    test('Step 8.2: Certificate of Origin PDF generates Chamber of Commerce format > 5KB', () async {
      final pdfBytes = await ExportCertificateService.instance.generateCertificateOfOriginPdf(
        certificateNumber: 'COO-IN-2026-4402',
        consigneeName: 'Empire Food Importers Ltd, London, UK',
        destinationCountry: 'United Kingdom',
        invoiceNumber: 'EXP-INV-2026-088',
        invoiceDate: now.subtract(const Duration(days: 2)),
        items: [
          {
            'marks': 'SRF/UK/01-500',
            'description': 'Frozen Malabar Parota (Blast Frozen)',
            'hsCode': '1905.90.90',
            'qty': '500 ctns (10,000 pk)',
            'grossWeight': '4,350 kg',
          },
        ],
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });

    test('Step 8.3: Halal Compliance Certificate PDF generates GSO 2055-1 format > 5KB', () async {
      final pdfBytes = await ExportCertificateService.instance.generateHalalCertificatePdf(
        certificateNumber: 'HALAL-IN-2026-781',
        productName: 'Blast Frozen Malabar Parota (Export Grade)',
        batchLotNumber: 'LOT-2026-DXB-01',
        mfgDate: now.subtract(const Duration(days: 5)),
        expiryDate: now.add(const Duration(days: 360)),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });
  });
}
