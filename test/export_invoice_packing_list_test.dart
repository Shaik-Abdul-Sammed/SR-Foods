import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/export_invoice_pdf_service.dart';

void main() {
  const service = ExportInvoicePdfService();

  group('Export Invoice & Packing List PDF Generator Tests', () {
    test('1. UAE CIF Jebel Ali Invoice generates valid PDF > 10KB', () async {
      final uaeInvoice = ExportInvoiceData(
        invoiceNumber: 'EXP-INV-2026-AE01',
        invoiceDate: DateTime(2026, 11, 14),
        consigneeName: 'Al-Madina Foodstuff Trading LLC',
        consigneeAddress: 'Warehouse 14, Al Quoz Industrial 3, Dubai, UAE',
        consigneeTaxId: 'TRN100234567800003',
        incoterm: 'CIF Jebel Ali',
        portOfLoading: 'Nhava Sheva, India (INNSA)',
        portOfDischarge: 'Jebel Ali, UAE (AEJEA)',
        countryOfFinalDestination: 'United Arab Emirates',
        currency: 'AED',
        fxRateToInr: 22.85,
        freightCharge: 2500.0,
        insuranceCharge: 350.0,
        items: [
          const ExportInvoiceLineItem(
            lineNo: 1,
            description: 'Frozen Malabar Parota (Master Carton of 24 Pkts)',
            hsCode: '1905.90.90',
            cartonCount: 500,
            unitsPerCarton: 24,
            totalUnits: 12000,
            unitPrice: 55.0,
            totalAmount: 27500.0,
          ),
          const ExportInvoiceLineItem(
            lineNo: 2,
            description: 'Whole Wheat Chapathi (Master Carton of 24 Pkts)',
            hsCode: '1905.90.90',
            cartonCount: 300,
            unitsPerCarton: 24,
            totalUnits: 7200,
            unitPrice: 48.0,
            totalAmount: 14400.0,
          ),
        ],
      );

      final pdfBytes = await service.generateCommercialInvoice(uaeInvoice);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(10240), reason: 'Commercial invoice PDF must be > 10KB');
      expect(ascii.decode(pdfBytes.take(5).toList()), '%PDF-');
    });

    test('2. US DDP New York Invoice generates valid PDF > 10KB', () async {
      final usInvoice = ExportInvoiceData(
        invoiceNumber: 'EXP-INV-2026-US01',
        invoiceDate: DateTime(2026, 11, 14),
        consigneeName: 'Patel Brothers Import & Distribution Inc.',
        consigneeAddress: '2020 West Devon Avenue, Chicago, IL 60659, USA',
        consigneeTaxId: 'EIN-36-8912345',
        incoterm: 'DDP New York',
        portOfLoading: 'Nhava Sheva, India (INNSA)',
        portOfDischarge: 'New York Container Terminal, USA (USNYC)',
        countryOfFinalDestination: 'United States',
        currency: 'USD',
        fxRateToInr: 83.50,
        freightCharge: 4200.0,
        insuranceCharge: 600.0,
        items: [
          const ExportInvoiceLineItem(
            lineNo: 1,
            description: 'Frozen Malabar Parota (Export Retail Packs - Master Carton)',
            hsCode: '1905.90.90',
            cartonCount: 800,
            unitsPerCarton: 24,
            totalUnits: 19200,
            unitPrice: 16.50,
            totalAmount: 13200.0,
          ),
          const ExportInvoiceLineItem(
            lineNo: 2,
            description: 'Oil-Free Pulka Roti (Frozen Retail Packs - Master Carton)',
            hsCode: '1905.90.90',
            cartonCount: 400,
            unitsPerCarton: 24,
            totalUnits: 9600,
            unitPrice: 14.00,
            totalAmount: 5600.0,
          ),
        ],
      );

      final pdfBytes = await service.generateCommercialInvoice(usInvoice);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(10240), reason: 'Commercial invoice PDF must be > 10KB');
      expect(ascii.decode(pdfBytes.take(5).toList()), '%PDF-');
    });

    test('3. Export Packing List generates valid PDF > 10KB', () async {
      final packingList = ExportPackingListData(
        invoiceNumber: 'EXP-INV-2026-AE01',
        date: DateTime(2026, 11, 14),
        consigneeName: 'Al-Madina Foodstuff Trading LLC',
        consigneeAddress: 'Warehouse 14, Al Quoz 3, Dubai, UAE',
        containerNumber: 'MSCU7829104',
        sealNumber: 'INNSA984120',
        targetTemperatureCelsius: -18.0,
        totalPallets: 12,
        lines: [
          const ExportPackingListLineItem(
            cartonNumberRange: 'CTN 001 - CTN 500',
            description: 'Frozen Malabar Parota (24 Pkts/Ctn)',
            cartonCount: 500,
            netWeightKg: 4800.0,
            grossWeightKg: 5250.0,
            dimensionsCm: '42 x 32 x 26 cm',
            cbm: 17.472,
          ),
          const ExportPackingListLineItem(
            cartonNumberRange: 'CTN 501 - CTN 800',
            description: 'Whole Wheat Chapathi (24 Pkts/Ctn)',
            cartonCount: 300,
            netWeightKg: 2520.0,
            grossWeightKg: 2820.0,
            dimensionsCm: '40 x 30 x 24 cm',
            cbm: 8.640,
          ),
        ],
      );

      final pdfBytes = await service.generatePackingList(packingList);

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(10240), reason: 'Export packing list PDF must be > 10KB');
      expect(ascii.decode(pdfBytes.take(5).toList()), '%PDF-');
    });
  });
}
