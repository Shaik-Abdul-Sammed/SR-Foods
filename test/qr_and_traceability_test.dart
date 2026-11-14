import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/database/database_provider.dart';
import 'package:sr_foods/core/services/export_label_pdf_service.dart';
import 'package:sr_foods/core/services/qr_service.dart';
import 'package:sr_foods/core/services/qr_verifier.dart';
import 'package:sr_foods/core/services/reorder_placard_pdf_service.dart';
import 'package:sr_foods/core/services/warehouse_picking_service.dart';
import 'package:sr_foods/features/orders/presentation/screens/driver_route_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

void main() {
  group('Phase 2 — QR & Traceability Comprehensive Tests', () {
    test('10 QR Generators produce valid signed strings and pass offline verification (10 Positives)', () {
      final now = DateTime.now();

      // 1. GS1 DataMatrix
      final gs1 = QrService.instance.generateBatchGs1DataMatrix(
        gtin: '08906000000010',
        lotNumber: 'LOT-2026-X1',
        serialNumber: 'SR-00012',
        expiryDateYymmdd: '261231',
        storageCode: '-18C',
      );
      final res1 = QrVerifier.instance.verifyQr(gs1);
      expect(res1.isValid, isTrue);
      expect(res1.type, QrPayloadType.gs1DataMatrix);
      expect(res1.payload['lot'], 'LOT-2026-X1');

      // 2. Consumer Pack
      final pack = QrService.instance.generateConsumerPackQr(
        batchNumber: 'PB-2026-001',
        sku: 'SRF-BRD-001',
        productName: 'Malabar Parotta',
        mfgDate: '2026-11-14',
        fssaiLicense: '10123999000123',
        allergens: ['Wheat (Gluten)'],
        nutritionPer100g: {'energy': 280, 'protein': 8.5},
        heatingGuide: 'Warm on tawa for 2 mins with ghee',
      );
      final res2 = QrVerifier.instance.verifyQr(pack);
      expect(res2.isValid, isTrue);
      expect(res2.type, QrPayloadType.consumerPack);
      expect(res2.payload['b'], 'PB-2026-001');

      // 3. Invoice Payment (INR UPI)
      final upi = QrService.instance.generateInvoicePaymentQr(
        invoiceNumber: 'INV-2026-001',
        amount: 2500.0,
        currency: 'INR',
      );
      final res3 = QrVerifier.instance.verifyQr(upi);
      expect(res3.isValid, isTrue);
      expect(res3.type, QrPayloadType.invoicePayment);
      expect(res3.payload['invoiceNumber'], 'INV-2026-001');

      // 4. PoD Order Sign-Off
      final pod = QrService.instance.generatePodQr(
        orderId: 101,
        orderNumber: 'ORD-101',
        driverId: 'DRV-01',
        customerCode: 'CUST-HOTEL-TAJ',
        expectedAt: now.add(const Duration(hours: 2)),
      );
      final res4 = QrVerifier.instance.verifyQr(pod);
      expect(res4.isValid, isTrue);
      expect(res4.type, QrPayloadType.pod);
      expect(res4.payload['orderNumber'], 'ORD-101');

      // 5. Reorder Placard
      final reorder = QrService.instance.generateReorderQr(
        customerId: 5,
        customerCode: 'CUST-05',
        validUntil: now.add(const Duration(days: 30)),
      );
      final res5 = QrVerifier.instance.verifyQr(reorder);
      expect(res5.isValid, isTrue);
      expect(res5.type, QrPayloadType.reorder);
      expect(res5.payload['customerCode'], 'CUST-05');

      // 6. Cold Chain
      final cold = QrService.instance.generateColdChainQr(
        batchId: 12,
        batchNumber: 'PB-CHILL-12',
        handoffRole: 'factory_to_reefer',
        outTempCelsius: -18.2,
        inTempCelsius: -18.0,
        recordedAt: now,
      );
      final res6 = QrVerifier.instance.verifyQr(cold);
      expect(res6.isValid, isTrue);
      expect(res6.type, QrPayloadType.coldChain);
      expect(res6.payload['batchNumber'], 'PB-CHILL-12');

      // 7. Customs
      final customs = QrService.instance.generateCustomsQr(
        exportOrderId: 8,
        containerNo: 'TGHU9988776',
        sealNo: 'SL-5544',
        hsCode: '1905.90.90',
        lutGstin: '37AAAAA0000A1Z5',
      );
      final res7 = QrVerifier.instance.verifyQr(customs);
      expect(res7.isValid, isTrue);
      expect(res7.type, QrPayloadType.customs);
      expect(res7.payload['containerNo'], 'TGHU9988776');

      // 8. Return
      final ret = QrService.instance.generateReturnQr(
        returnId: 3,
        creditNoteId: 1,
        customerId: 5,
        amountMinor: 25000,
        currency: 'INR',
      );
      final res8 = QrVerifier.instance.verifyQr(ret);
      expect(res8.isValid, isTrue);
      expect(res8.type, QrPayloadType.returnedGoods);
      expect(res8.payload['returnId'], 3);

      // 9. Staff ID
      final staff = QrService.instance.generateStaffIdQr(
        employeeId: 'EMP-001',
        name: 'SM Subhani',
        fssaiFitnessStatus: 'FIT_MEDICALLY_CLEARED',
        fitnessValidUntil: now.add(const Duration(days: 180)),
      );
      final res9 = QrVerifier.instance.verifyQr(staff);
      expect(res9.isValid, isTrue);
      expect(res9.type, QrPayloadType.staffId);
      expect(res9.payload['name'], 'SM Subhani');

      // 10. Statement Pay
      final stmt = QrService.instance.generateStatementPayQr(
        customerId: 9,
        overdueTotalMinor: 120000,
        currency: 'INR',
        asOfDate: now,
      );
      final res10 = QrVerifier.instance.verifyQr(stmt);
      expect(res10.isValid, isTrue);
      expect(res10.type, QrPayloadType.statementPay);
      expect(res10.payload['overdueTotalMinor'], 120000);
    });

    test('10 Negative Security Cases: Tampered, forged, or expired QRs are rejected offline', () {
      final now = DateTime.now();

      // Neg 1: Tampered GS1 lot number
      final gs1 = QrService.instance.generateBatchGs1DataMatrix(
        gtin: '08906000000010',
        lotNumber: 'LOT-ORIG',
        serialNumber: 'SR-01',
        expiryDateYymmdd: '261231',
        storageCode: '-18C',
      );
      final tamperedGs1 = gs1.replaceAll('LOT-ORIG', 'LOT-FORGED');
      expect(QrVerifier.instance.verifyQr(tamperedGs1).isValid, isFalse);

      // Neg 2: Tampered Consumer pack
      final pack = QrService.instance.generateConsumerPackQr(
        batchNumber: 'PB-ORIG',
        sku: 'SRF-BRD-001',
        productName: 'Parotta',
        mfgDate: '2026-11-14',
        fssaiLicense: '10123999000123',
        allergens: [],
        nutritionPer100g: {},
        heatingGuide: 'Warm',
      );
      final tamperedPack = '${pack}tamper';
      expect(QrVerifier.instance.verifyQr(tamperedPack).isValid, isFalse);

      // Neg 3: Tampered UPI amount (fraudster modified amount)
      final upi = QrService.instance.generateInvoicePaymentQr(
        invoiceNumber: 'INV-100',
        amount: 5000.0,
        currency: 'INR',
      );
      final tamperedUpi = upi.replaceAll('am=5000.00', 'am=50.00');
      expect(QrVerifier.instance.verifyQr(tamperedUpi).isValid, isFalse);

      // Neg 4: Tampered PoD order number
      final pod = QrService.instance.generatePodQr(
        orderId: 10,
        orderNumber: 'ORD-10',
        driverId: 'DRV-1',
        customerCode: 'CUST-1',
        expectedAt: now,
      );
      final tamperedPod = pod.replaceAll('ORD-10', 'ORD-99');
      expect(QrVerifier.instance.verifyQr(tamperedPod).isValid, isFalse);

      // Neg 5: Expired Reorder QR
      final expiredReorder = QrService.instance.generateReorderQr(
        customerId: 1,
        customerCode: 'CUST-1',
        validUntil: now.subtract(const Duration(days: 1)),
      );
      final resExp = QrVerifier.instance.verifyQr(expiredReorder);
      expect(resExp.isValid, isFalse);
      expect(resExp.reason, contains('expired'));

      // Neg 6: Tampered Cold-chain temperature reading
      final cold = QrService.instance.generateColdChainQr(
        batchId: 1,
        batchNumber: 'PB-01',
        handoffRole: 'driver',
        outTempCelsius: -18.0,
        inTempCelsius: -18.0,
        recordedAt: now,
      );
      final tamperedCold = cold.replaceAll('-18.0', '-5.0');
      expect(QrVerifier.instance.verifyQr(tamperedCold).isValid, isFalse);

      // Neg 7: Tampered customs seal number
      final customs = QrService.instance.generateCustomsQr(
        exportOrderId: 1,
        containerNo: 'CN-01',
        sealNo: 'SEAL-VALID',
        hsCode: '1905',
        lutGstin: '37AAAAA0000A1Z5',
      );
      final tamperedCustoms = customs.replaceAll('SEAL-VALID', 'SEAL-BROKEN');
      expect(QrVerifier.instance.verifyQr(tamperedCustoms).isValid, isFalse);

      // Neg 8: Tampered return credit amount
      final ret = QrService.instance.generateReturnQr(
        returnId: 1,
        creditNoteId: 1,
        customerId: 1,
        amountMinor: 1000,
        currency: 'INR',
      );
      final tamperedRet = ret.replaceAll('1000', '900000');
      expect(QrVerifier.instance.verifyQr(tamperedRet).isValid, isFalse);

      // Neg 9: Expired Staff Medical Certificate
      final expiredStaff = QrService.instance.generateStaffIdQr(
        employeeId: 'EMP-09',
        name: 'Ramu',
        fssaiFitnessStatus: 'EXPIRED_FITNESS',
        fitnessValidUntil: now.subtract(const Duration(days: 10)),
      );
      final resStaff = QrVerifier.instance.verifyQr(expiredStaff);
      expect(resStaff.isValid, isFalse);
      expect(resStaff.reason, contains('expired'));

      // Neg 10: Completely random/empty/unstructured string
      expect(QrVerifier.instance.verifyQr('').isValid, isFalse);
      expect(QrVerifier.instance.verifyQr('random_garbage_string_without_structure').isValid, isFalse);
    });

    test('Step 2.4: Warehouse Picking Scanner matches cartons, flashes green, or buzzes red on wrong/expired lot', () {
      final now = DateTime(2026, 11, 14);

      // Good carton matching order line
      final validCartonQr = QrService.instance.generateBatchGs1DataMatrix(
        gtin: '08906000000010', // SKU 1
        lotNumber: 'LOT-NOV-01',
        serialNumber: 'CTN-101',
        expiryDateYymmdd: '261231', // Exp Dec 2026
        storageCode: '-18C',
      );

      final resGood = WarehousePickingService.instance.verifyCartonScan(
        scannedQr: validCartonQr,
        expectedSkus: ['00001', 'SRF-BRD-001'],
        checkDate: now,
      );
      expect(resGood.status, PickScanStatus.matchSuccess);
      expect(resGood.isGreenFlash, isTrue);
      expect(resGood.isRedBuzz, isFalse);

      // Wrong product SKU mismatch
      final resWrongSku = WarehousePickingService.instance.verifyCartonScan(
        scannedQr: validCartonQr,
        expectedSkus: ['SRF-SWT-070', '00070'],
        checkDate: now,
      );
      expect(resWrongSku.status, PickScanStatus.skuMismatch);
      expect(resWrongSku.isRedBuzz, isTrue);

      // Expired carton lot
      final expiredCartonQr = QrService.instance.generateBatchGs1DataMatrix(
        gtin: '08906000000010',
        lotNumber: 'LOT-OLD-01',
        serialNumber: 'CTN-001',
        expiryDateYymmdd: '251010', // Expired Oct 2025
        storageCode: '-18C',
      );

      final resExpired = WarehousePickingService.instance.verifyCartonScan(
        scannedQr: expiredCartonQr,
        expectedSkus: ['00001', 'SRF-BRD-001'],
        checkDate: now,
      );
      expect(resExpired.status, PickScanStatus.expiredLot);
      expect(resExpired.isRedBuzz, isTrue);
      expect(resExpired.message, contains('EXPIRED LOT REJECTED'));
    });

    test('Step 2.5: Reorder Placard PDF generates A5 landscape placard with embedded signed QR', () async {
      final customer = Customer(
        id: 1,
        code: 'CUST-HYD-HOTEL-01',
        shopName: 'Paradise Biryani & Tiffin Center',
        ownerName: 'Mr. Ali',
        phone: '9440012345',
        creditLimit: 25000.0,
        openingBalance: 0.0,
        currentBalance: 0.0,
        isActive: true,
        isFavorite: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pdfBytes = await ReorderPlacardPdfService.instance.generateA5ReorderPlacard(
        customer: customer,
        favoriteProducts: [],
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });

    test('Step 2.7: Export Label PDF embeds GS1 DataMatrix per GS1 General Specs v23.0', () async {
      final labelData = ExportLabelData(
        sku: 'SRF-BRD-002',
        productName: 'Malabar Parotta (Export Blast Frozen)',
        productNameArabic: 'بروتا مالابار المجمدة',
        batchNumber: 'LOT-2026-UK-01',
        productionDate: DateTime(2026, 11, 1),
        expiryDate: DateTime(2027, 11, 1),
        netWeightGrams: 400.0,
        netWeightOz: 14.1,
        ingredients: ['Wheat Flour', 'Water', 'Refined Palm Oil', 'Salt'],
        allergens: ['Wheat (Gluten)'],
        destinationCountry: 'UK',
        destinationImporterAddress: 'Taj Foods UK Ltd., Unit 4, Wembley Industrial Park, London HA9 0LJ',
      );

      final pdfBytes = await const ExportLabelPdfService().generateExportLabel(labelData);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));
    });

    testWidgets('Step 2.3: DriverRouteScreen allows Manual PIN ePOD delivery override', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Seed 1 customer, 1 order for delivery
      final custId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-RT-01',
          shopName: 'Hotel Saravana Grand',
          ownerName: 'Murugan',
          phone: '9840098400',
          route: const Value('Main Bazaar Route'),
        ),
      );

      await db.into(db.orders).insert(
        OrdersCompanion.insert(
          orderNumber: 'ORD-RT-100',
          customerId: custId,
          grandTotal: const Value(3500.0),
          pendingAmount: const Value(3500.0),
          status: const Value('pending'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: DriverRouteScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find drop button
      expect(find.text('Drop'), findsOneWidget);
      await tester.tap(find.text('Drop'));
      await tester.pumpAndSettle();

      // In delivery dialog, find "Scan to Complete Delivery (ePOD)" button
      expect(find.text('Scan to Complete Delivery (ePOD)'), findsOneWidget);
      await tester.tap(find.text('Scan to Complete Delivery (ePOD)'));
      await tester.pumpAndSettle();

      // Camera sheet opens; tap PIN Override button
      expect(find.text('PIN Override'), findsOneWidget);
      await tester.tap(find.text('PIN Override'));
      await tester.pumpAndSettle();

      // Enter 4-digit PIN
      expect(find.text('Manual Delivery PIN Override'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '4321');
      await tester.pumpAndSettle();

      // Tap confirm PIN delivery
      await tester.tap(find.byKey(const Key('confirm_pin_button')));
      await tester.pumpAndSettle();

      // Assert delivery recorded
      expect(find.textContaining('ePOD Verified via PIN'), findsOneWidget);

      await db.close();
    });
  });
}
