import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';
import 'package:sr_foods/core/services/compliance_profile_engine.dart';
import 'package:sr_foods/core/services/export_invoice_pdf_service.dart';
import 'package:sr_foods/core/services/export_label_pdf_service.dart';
import 'package:sr_foods/core/services/fx_engine.dart';
import 'package:sr_foods/core/services/landed_cost_service.dart';

void main() {
  group('PHASE 2 GATE: UK Export End-to-End Acceptance Demo Test', () {
    late AppDatabase db;
    late FxEngine fxEngine;
    const complianceEngine = ComplianceProfileEngine();
    const labelPdfService = ExportLabelPdfService();
    const invoicePdfService = ExportInvoicePdfService();
    const landedCostService = LandedCostService();

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      fxEngine = FxEngine(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
        '500 Cartons Frozen Malabar Parota (CIF Felixstowe) -> Compliance Audit -> QUID Label -> Packing List -> LUT Invoice -> Landed Cost',
        () async {
      // 1. SEED DATABASE (Entity, Distributor, Product)
      final entityId = await db.into(db.entities).insert(
            EntitiesCompanion.insert(
              name: 'SR Foods India Private Limited',
              countryCode: 'IN',
              taxId: '36AAAAA0000A1Z5',
              currency: 'INR',
              address: const Value('Plot 12, Food Processing SEZ, Hyderabad, India'),
              isDefault: const Value(true),
            ),
          );

      final distributorId = await db.into(db.distributors).insert(
            DistributorsCompanion.insert(
              name: 'Taj Foods UK Limited',
              countryCode: 'GB',
              currency: 'GBP',
              creditLimitMinor: const Value(10000000), // £100,000.00
              creditDays: const Value(45),
              incotermsDefault: const Value('CIF'),
              taxId: const Value('GB892140519'),
              paymentTerms: const Value('Net 45 CAD'),
            ),
          );

      final productId = await db.into(db.products).insert(
            ProductsCompanion.insert(
              sku: 'EXP-PAROTA-UK',
              name: 'Frozen Malabar Parota (Export Master Pack)',
              price: 180.0,
            ),
          );

      // Lock contract rate: 1 GBP = 105.80 INR
      await fxEngine.lockContractRate(
        base: Currency.gbp,
        target: Currency.inr,
        rate: 105.80,
        source: 'contract_uk_001',
      );

      // 2. CREATE EXPORT ORDER IN DRIFT (500 Cartons @ £18.50/ctn CIF Felixstowe)
      // Subtotal FOB: 500 * £17.00 = £8,500.00 (850,000 pence)
      // Ocean Freight: £1,200.00 (120,000 pence)
      // Marine Insurance: £150.00 (15,000 pence)
      // Total CIF: £9,850.00 (985,000 pence)
      final orderId = await db.into(db.exportOrders).insert(
            ExportOrdersCompanion.insert(
              orderNumber: 'EXP-2026-UK001',
              entityId: entityId,
              distributorId: distributorId,
              destinationCountry: 'GB',
              currency: 'GBP',
              fxRateToInr: const Value(105.80),
              incoterm: 'CIF',
              portOfLoading: 'Nhava Sheva, India (INNSA)',
              portOfDischarge: 'Port of Felixstowe, UK (GBFXT)',
              subtotalMinor: const Value(850000),
              freightMinor: const Value(120000),
              insuranceMinor: const Value(15000),
              dutyMinor: const Value(0),
              totalMinor: const Value(985000),
            ),
          );
      expect(orderId, greaterThan(0));

      final lineId = await db.into(db.exportLines).insert(
            ExportLinesCompanion.insert(
              exportOrderId: orderId,
              productId: productId,
              sku: 'EXP-PAROTA-UK',
              hsCode: '1905.90.90',
              quantityUnits: 500,
              unitType: const Value('cartons'),
              unitPriceMinor: 1700, // £17.00/carton FOB
              lineTotalMinor: 850000,
            ),
          );
      expect(lineId, greaterThan(0));

      // 3. RUN DESTINATION COMPLIANCE AUDIT (UK FSA / DEFRA / Natasha's Law)
      final productionDate = DateTime(2026, 11, 14);
      final expiryDate = DateTime(2027, 5, 14); // 6 months frozen shelf-life
      final estimatedArrival = DateTime(2026, 12, 10); // 26 days sea transit

      final batchData = ExportBatchComplianceData(
        sku: 'EXP-PAROTA-UK',
        productName: 'Frozen Malabar Parota (Export Pack)',
        ingredients: ['Wheat Flour (62%)', 'Water', 'Vegetable Oil', 'Iodized Salt'],
        quidPercentages: {'Wheat Flour': 62.0},
        allergens: ['Wheat', 'Gluten'],
        netWeightGrams: 400.0,
        netWeightOz: 14.1,
        productionDate: productionDate,
        expiryDate: expiryDate,
        countryOfOrigin: 'India',
        destinationImporterAddress: 'Taj Foods UK Ltd, Unit 4 Wembley Park, London HA9 0HQ',
        hasNutritionFactsPanel: true,
      );

      final complianceFindings = complianceEngine.auditOrder(
        destinationCountryCode: 'GB',
        items: [batchData],
        estimatedPortArrivalDate: estimatedArrival,
      );

      // Verify zero blocking errors
      final blockingErrors = complianceFindings.where((f) => f.isError).toList();
      expect(blockingErrors.isEmpty, isTrue,
          reason: 'All UK compliance rules (QUID %, FBO address, shelf-life) must pass cleanly');

      // 4. GENERATE QUID-COMPLIANT PRINT-READY EXPORT LABEL PDF
      final labelData = ExportLabelData(
        sku: 'EXP-PAROTA-UK',
        productName: 'Frozen Malabar Parota (Export Pack)',
        batchNumber: 'BATCH-202611-UK01',
        productionDate: productionDate,
        expiryDate: expiryDate,
        netWeightGrams: 400.0,
        netWeightOz: 14.1,
        ingredients: ['Wheat Flour (62%)', 'Water', 'Vegetable Oil', 'Iodized Salt'],
        quidPercentages: {'Wheat Flour': 62.0},
        allergens: ['Wheat', 'Gluten'],
        destinationCountry: 'GB',
        destinationImporterAddress: 'Taj Foods UK Ltd, Unit 4 Wembley Park, London HA9 0HQ',
      );

      final labelPdfBytes = await labelPdfService.generateExportLabel(labelData);
      expect(labelPdfBytes.length, greaterThan(5120), reason: 'Label PDF must be > 5KB');
      expect(ascii.decode(labelPdfBytes.take(5).toList()), '%PDF-');

      // 5. GENERATE COMMERCIAL EXPORT INVOICE (LUT Zero-Rated GST under Section 16 IGST Act)
      final invoiceData = ExportInvoiceData(
        invoiceNumber: 'EXP-INV-2026-UK001',
        invoiceDate: DateTime(2026, 11, 14),
        lutNumber: 'AD370326001234F',
        iecNumber: '0712034912',
        consigneeName: 'Taj Foods UK Limited',
        consigneeAddress: 'Unit 4, Wembley Commercial Park, London HA9 0HQ, United Kingdom',
        consigneeTaxId: 'GB892140519',
        incoterm: 'CIF Felixstowe',
        portOfLoading: 'Nhava Sheva, India (INNSA)',
        portOfDischarge: 'Port of Felixstowe, UK (GBFXT)',
        countryOfFinalDestination: 'United Kingdom',
        currency: 'GBP',
        fxRateToInr: 105.80,
        freightCharge: 1200.0,
        insuranceCharge: 150.0,
        items: [
          const ExportInvoiceLineItem(
            lineNo: 1,
            description: 'Frozen Malabar Parota (Export Master Carton of 24 Pkts x 400g)',
            hsCode: '1905.90.90',
            cartonCount: 500,
            unitsPerCarton: 24,
            totalUnits: 12000,
            unitPrice: 17.00,
            totalAmount: 8500.0,
          ),
        ],
      );

      final invoicePdfBytes = await invoicePdfService.generateCommercialInvoice(invoiceData);
      expect(invoicePdfBytes.length, greaterThan(10240), reason: 'Commercial invoice PDF must be > 10KB');
      expect(ascii.decode(invoicePdfBytes.take(5).toList()), '%PDF-');

      // 6. GENERATE PACKING LIST (500 Cartons in -18°C Reefer Container)
      final packingListData = ExportPackingListData(
        invoiceNumber: 'EXP-INV-2026-UK001',
        date: DateTime(2026, 11, 14),
        consigneeName: 'Taj Foods UK Limited',
        consigneeAddress: 'Unit 4, Wembley Park, London HA9 0HQ',
        containerNumber: 'MSCU-9081234',
        sealNumber: 'INNSA-882103',
        targetTemperatureCelsius: -18.0,
        totalPallets: 10,
        lines: [
          const ExportPackingListLineItem(
            cartonNumberRange: 'CTN 001 - CTN 500',
            description: 'Frozen Malabar Parota (24 Pkts/Carton)',
            cartonCount: 500,
            netWeightKg: 4800.0,
            grossWeightKg: 5250.0,
            dimensionsCm: '42 x 32 x 26 cm',
            cbm: 17.472,
          ),
        ],
      );

      final packingPdfBytes = await invoicePdfService.generatePackingList(packingListData);
      expect(packingPdfBytes.length, greaterThan(10240), reason: 'Packing list PDF must be > 10KB');
      expect(ascii.decode(packingPdfBytes.take(5).toList()), '%PDF-');

      // 7. VERIFY LANDED COST CALCULATION (UK Global Tariff 0% + 0% VAT)
      final landedCostInput = LandedCostInput(
        fobPrice: Money.fromMajor(8500.0, currency: Currency.gbp),
        freight: Money.fromMajor(1200.0, currency: Currency.gbp),
        insurance: Money.fromMajor(150.0, currency: Currency.gbp),
        destinationCountry: 'GB',
        hsCode: '1905.90.90',
        cartonCount: 500,
        unitsPerCarton: 24,
      );

      final landedResult = landedCostService.computeLandedCost(landedCostInput);

      // CIF Value: £8,500 + £1,200 + £150 = £9,850.00 (985,000 pence)
      expect(landedResult.cifValue.amountMinor, 985000);
      expect(landedResult.customsDutyAmount.amountMinor, 0); // 0% UK duty for basic food
      expect(landedResult.importVatAmount.amountMinor, 0); // 0% UK VAT zero-rated
      expect(landedResult.totalLandedCost.amountMinor, 985000);

      // Landed cost per carton: 985,000 / 500 = 1,970 pence = £19.70
      expect(landedResult.costPerCarton.amountMinor, 1970);
      expect(landedResult.costPerCarton.inMajor, 19.70);

      // Landed cost per consumer pack (12,000 packs): 985,000 / 12,000 = 82 pence = £0.82
      expect(landedResult.costPerConsumerPack.amountMinor, 82);
      expect(landedResult.costPerConsumerPack.inMajor, 0.82);

      // Assert foreign exchange valuation back to INR for factory accounts
      final landedCostInInr = fxEngine.convert(landedResult.totalLandedCost, Currency.inr);
      // £9,850.00 * 105.80 = ₹10,42,130.00
      expect(landedCostInInr.currency, Currency.inr);
      expect(landedCostInInr.inRupees, 1042130.0);
    });
  });
}
