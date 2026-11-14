import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/features/orders/presentation/widgets/export_shipment_tracker_card.dart';

void main() {
  group('ExportShipmentTrackerCard Widget Tests', () {
    testWidgets('Normal temperature renders secure cold-chain badge and milestones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportShipmentTrackerCard(
              orderNumber: 'EXP-2026-UK01',
              containerNumber: 'MSCU-8921045',
              sealNumber: 'INNSA-981240',
              vesselName: 'MSC AMALFI',
              voyageNumber: '2644W',
              portOfLoading: 'Nhava Sheva, India (INNSA)',
              portOfDischarge: 'Felixstowe, UK (GBFXT)',
              targetTemperatureCelsius: -18.0,
              actualTemperatureCelsius: -18.4, // Secure temperature
              currentMilestone: ExportMilestone.onVessel,
              etd: DateTime(2026, 11, 20),
              eta: DateTime(2026, 12, 12),
            ),
          ),
        ),
      );

      expect(find.text('CONTAINER: MSCU-8921045'), findsOneWidget);
      expect(find.text('-18.4°C'), findsOneWidget);
      expect(find.text('Felixstowe, UK (GBFXT)'), findsOneWidget);
      expect(find.text('On Vessel / In Transit'), findsOneWidget);

      // No breach alert
      expect(find.text('TEMPERATURE BREACH DETECTED!'), findsNothing);
    });

    testWidgets('Temperature breach (-11.0°C vs -18.0°C target) triggers alert container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportShipmentTrackerCard(
              orderNumber: 'EXP-2026-AE02',
              containerNumber: 'CMAU-4819201',
              sealNumber: 'INNSA-330192',
              portOfLoading: 'Nhava Sheva, India',
              portOfDischarge: 'Jebel Ali, UAE',
              targetTemperatureCelsius: -18.0,
              actualTemperatureCelsius: -11.2, // Critical breach (> -15°C)
              currentMilestone: ExportMilestone.customsCleared,
            ),
          ),
        ),
      );

      expect(find.text('CONTAINER: CMAU-4819201'), findsOneWidget);
      expect(find.text('-11.2°C'), findsOneWidget);
      expect(find.text('TEMPERATURE BREACH DETECTED!'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
