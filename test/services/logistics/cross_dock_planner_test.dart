import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/logistics/cross_dock_planner.dart';

void main() {
  group('CrossDockPlanner Tests', () {
    const planner = CrossDockPlanner();
    final now = DateTime(2026, 11, 15, 6, 0);

    test('1. Direct transfer scheduled from inbound milk tanker to outbound delivery van', () {
      final inbounds = [
        InboundShipment(
          shipmentId: 'IN-01',
          originHubCode: 'HUB-MEDCHAL',
          productCode: 'RAW-MILK',
          quantityUnits: 500.0,
          temperatureZone: 'chilled',
          expectedArrival: now,
        ),
      ];

      final outboundVans = [
        OutboundDeliveryVan(
          vanId: 'VAN-01',
          destinationRoute: 'ROUTE-SECUNDERABAD',
          availableCapacityUnits: 600.0,
          supportedZone: 'chilled',
          plannedDeparture: now.add(const Duration(minutes: 45)), // 45 min dwell
        ),
      ];

      final result = planner.planTransfers(
        inbounds: inbounds,
        outboundVans: outboundVans,
      );

      expect(result.scheduledTransfers.length, 1);
      expect(result.totalTransferredUnits, 500.0);
      expect(result.unassignedInboundUnits, 0.0);
      expect(result.hasTemperatureViolations, isFalse);
    });

    test('2. Rejects transfers exceeding maximum allowable cross-dock dwell time', () {
      final inbounds = [
        InboundShipment(
          shipmentId: 'IN-02',
          originHubCode: 'HUB-MEDCHAL',
          productCode: 'RAW-MILK',
          quantityUnits: 400.0,
          temperatureZone: 'chilled',
          expectedArrival: now,
        ),
      ];

      final outboundVans = [
        OutboundDeliveryVan(
          vanId: 'VAN-02',
          destinationRoute: 'ROUTE-CYBERABAD',
          availableCapacityUnits: 500.0,
          supportedZone: 'chilled',
          plannedDeparture: now.add(const Duration(minutes: 180)), // 3 hours exceeds 2 hr limit
        ),
      ];

      final result = planner.planTransfers(
        inbounds: inbounds,
        outboundVans: outboundVans,
        maxDwellMinutes: 120,
      );

      expect(result.scheduledTransfers, isEmpty);
      expect(result.unassignedInboundUnits, 400.0);
    });

    test('3. Prevents temperature incompatibility transfers', () {
      final inbounds = [
        InboundShipment(
          shipmentId: 'IN-03',
          originHubCode: 'HUB-FROZEN',
          productCode: 'ICE-CREAM',
          quantityUnits: 200.0,
          temperatureZone: 'frozen',
          expectedArrival: now,
        ),
      ];

      final outboundVans = [
        OutboundDeliveryVan(
          vanId: 'VAN-DRY',
          destinationRoute: 'ROUTE-OLD-CITY',
          availableCapacityUnits: 500.0,
          supportedZone: 'ambient', // Ambient van cannot take frozen items
          plannedDeparture: now.add(const Duration(minutes: 30)),
        ),
      ];

      final result = planner.planTransfers(
        inbounds: inbounds,
        outboundVans: outboundVans,
      );

      expect(result.scheduledTransfers, isEmpty);
      expect(result.hasTemperatureViolations, isTrue);
    });
  });
}
