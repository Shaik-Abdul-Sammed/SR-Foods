import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';

void main() {
  group('Drift Schema v4 Migration & Export Tables Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Schema version is v4 and all export tables are operational', () async {
      expect(db.schemaVersion, 4);

      // 1. Insert Entity
      final entityId = await db.into(db.entities).insert(
            EntitiesCompanion.insert(
              name: 'SR Foods India Private Limited',
              countryCode: 'IN',
              taxId: '36AAAAA0000A1Z5',
              currency: 'INR',
              address: const Value('Plot 12, Industrial Area, Hyderabad, TS, India'),
              isDefault: const Value(true),
            ),
          );
      expect(entityId, greaterThan(0));

      // 2. Insert Distributor
      final distributorId = await db.into(db.distributors).insert(
            DistributorsCompanion.insert(
              name: 'Al-Madina Foodstuff Trading LLC',
              countryCode: 'AE',
              currency: 'AED',
              creditLimitMinor: const Value(5000000), // AED 50,000.00
              creditDays: const Value(45),
              incotermsDefault: const Value('CIF'),
              taxId: const Value('TRN100234567800003'),
            ),
          );
      expect(distributorId, greaterThan(0));

      // 3. Insert Product for order lines
      final productId = await db.into(db.products).insert(
            ProductsCompanion.insert(
              sku: 'EXP-PAROTA-FROZEN',
              name: 'Frozen Malabar Parota (Export Master Pack)',
              price: 180.0,
            ),
          );

      // 4. Insert ExportOrder
      final exportOrderId = await db.into(db.exportOrders).insert(
            ExportOrdersCompanion.insert(
              orderNumber: 'EXP-2026-001',
              entityId: entityId,
              distributorId: distributorId,
              destinationCountry: 'AE',
              currency: 'AED',
              incoterm: 'CIF',
              portOfLoading: 'Nhava Sheva, India (INNSA)',
              portOfDischarge: 'Jebel Ali, UAE (AEJEA)',
              subtotalMinor: const Value(2500000), // AED 25,000
              freightMinor: const Value(200000), // AED 2,000
              insuranceMinor: const Value(50000), // AED 500
              dutyMinor: const Value(125000), // 5% GCC customs duty
              totalMinor: const Value(2875000),
            ),
          );
      expect(exportOrderId, greaterThan(0));

      // 5. Insert ExportLine
      final lineId = await db.into(db.exportLines).insert(
            ExportLinesCompanion.insert(
              exportOrderId: exportOrderId,
              productId: productId,
              sku: 'EXP-PAROTA-FROZEN',
              hsCode: '1905.90.90',
              quantityUnits: 500, // 500 cartons
              unitType: const Value('cartons'),
              unitPriceMinor: 5000, // AED 50.00/carton
              lineTotalMinor: 2500000,
            ),
          );
      expect(lineId, greaterThan(0));

      // 6. Insert ExportShipment (Cold-chain Reefer)
      final shipmentId = await db.into(db.exportShipments).insert(
            ExportShipmentsCompanion.insert(
              exportOrderId: exportOrderId,
              containerNo: 'MSCU7829104',
              sealNo: 'INNSA984120',
              blNumber: const Value('MEDU09823481'),
              vesselName: const Value('MSC AMALFI'),
              voyageNo: const Value('2644W'),
              temperatureCelsiusTarget: const Value(-18.0),
              temperatureLoggerId: const Value('TEMPLOG-4491'),
            ),
          );
      expect(shipmentId, greaterThan(0));

      // 7. Insert ComplianceProfile (GSO / Halal)
      final profileId = await db.into(db.complianceProfiles).insert(
            ComplianceProfilesCompanion.insert(
              countryCode: 'AE',
              authority: 'GSO_HALAL',
              rulesJson: '{"minShelfLifePercent": 50, "halalCertRequired": true, "arabicBilingual": true}',
              labelTemplateId: 'LABEL_GSO_AR_EN_V1',
            ),
          );
      expect(profileId, greaterThan(0));

      // 8. Insert FxRate
      final fxRateId = await db.into(db.fxRates).insert(
            FxRatesCompanion.insert(
              baseCurrency: 'AED',
              targetCurrency: 'INR',
              rate: 22.85,
              source: const Value('contract_lock'),
            ),
          );
      expect(fxRateId, greaterThan(0));

      // 9. Insert HsCode
      final hsId = await db.into(db.hsCodes).insert(
            HsCodesCompanion.insert(
              code: '1905.90',
              description: 'Bread, pastry, cakes, biscuits and other bakers wares (Parotas, Rotis)',
              chapter: '19',
              heading: '05',
              dutyRatesJson: '{"AE": 0.05, "US": 0.00, "CA": 0.00, "GB": 0.00, "AU": 0.05}',
            ),
          );
      expect(hsId, greaterThan(0));

      // Query verification
      final orders = await db.select(db.exportOrders).get();
      expect(orders.length, 1);
      expect(orders.first.orderNumber, 'EXP-2026-001');
      expect(orders.first.incoterm, 'CIF');
      expect(orders.first.portOfDischarge, 'Jebel Ali, UAE (AEJEA)');
    });
  });
}
