import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';
import 'package:sr_foods/features/customers/presentation/screens/distributor_portal_screen.dart';
import 'package:sr_foods/features/orders/presentation/widgets/export_shipment_tracker_card.dart';

void main() {
  group('PHASE 3 GATE: DistributorPortalScreen Widget Tests', () {
    testWidgets('UAE Distributor profile renders AED credit limit, AED pricing, AR aging, and shipment tracking card',
        (tester) async {
      final creditLimitAed = Money.fromMajor(50000.0, currency: Currency.aed); // AED 50,000.00
      final currentAr = Money.fromMajor(12000.0, currency: Currency.aed);
      final days30Ar = Money.fromMajor(6500.0, currency: Currency.aed);
      final days60Ar = Money.fromMajor(1500.0, currency: Currency.aed);
      final days90Ar = Money.fromMajor(0.0, currency: Currency.aed);

      final arAging = ArAgingBuckets(
        current: currentAr,
        days30: days30Ar,
        days60: days60Ar,
        days90Plus: days90Ar,
      );

      final priceOverrides = [
        DistributorPriceOverride(
          sku: 'PAROTA-FRZ-01',
          productName: 'Frozen Malabar Parota (24 Pkts)',
          masterPrice: Money.fromMajor(55.0, currency: Currency.aed),
          contractPrice: Money.fromMajor(50.0, currency: Currency.aed),
        ),
        DistributorPriceOverride(
          sku: 'CHAPATHI-WHT-01',
          productName: 'Whole Wheat Chapathi (24 Pkts)',
          masterPrice: Money.fromMajor(48.0, currency: Currency.aed),
          contractPrice: Money.fromMajor(44.0, currency: Currency.aed),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DistributorPortalScreen(
            distributorName: 'Al-Madina Foodstuff Trading LLC',
            countryCode: 'AE',
            currency: Currency.aed,
            taxId: 'TRN100234567800003',
            creditDays: 45,
            incotermsDefault: 'CIF',
            creditLimit: creditLimitAed,
            arAging: arAging,
            priceOverrides: priceOverrides,
            activeContainerNumber: 'MSCU-7829104',
            activeSealNumber: 'INNSA-984120',
            activeReeferTemp: -18.2,
            activeShipmentMilestone: ExportMilestone.onVessel,
          ),
        ),
      );

      await tester.pump();

      // 1. Assert Distributor Profile & Country Code
      expect(find.text('Al-Madina Foodstuff Trading LLC (AE)'), findsOneWidget);
      expect(find.text('AE • AED'), findsOneWidget);
      expect(find.text('Tax / TRN ID: TRN100234567800003 | Terms: Net 45 Days (CIF)'), findsOneWidget);

      // 2. Assert AED Credit Limit & Metric Tiles
      expect(find.text('CREDIT LIMIT'), findsOneWidget);
      expect(find.text(creditLimitAed.formatted), findsOneWidget);
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.text(arAging.totalOutstanding.formatted), findsOneWidget);
      expect(find.text('AVAILABLE CREDIT'), findsOneWidget);

      // 3. Assert AR Aging Table
      expect(find.text('ACCOUNTS RECEIVABLE (AR) AGING'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('1-30 Days'), findsOneWidget);
      expect(find.text('31-60 Days'), findsOneWidget);
      expect(find.text('61-90+ Days'), findsOneWidget);
      expect(find.text(currentAr.formatted), findsOneWidget);
      expect(find.text(days30Ar.formatted), findsOneWidget);
      expect(find.text(days60Ar.formatted), findsOneWidget);
      expect(find.text(days90Ar.formatted), findsOneWidget);

      // 4. Assert Contract Pricing & Export Discounts
      expect(find.text('CONTRACT PRICE LIST & EXPORT DISCOUNTS'), findsOneWidget);
      expect(find.text('Frozen Malabar Parota (24 Pkts)'), findsOneWidget);
      expect(find.text(priceOverrides[0].contractPrice.formatted), findsOneWidget);
      expect(find.text('Whole Wheat Chapathi (24 Pkts)'), findsOneWidget);
      expect(find.text(priceOverrides[1].contractPrice.formatted), findsOneWidget);

      // 5. Assert Export Shipment Tracker Card
      expect(find.text('ACTIVE EXPORT SHIPMENT TRACKING'), findsOneWidget);
      expect(find.text('CONTAINER: MSCU-7829104'), findsOneWidget);
      expect(find.text('-18.2°C'), findsOneWidget);
      expect(find.text('On Vessel / In Transit'), findsOneWidget);
    });
  });
}
