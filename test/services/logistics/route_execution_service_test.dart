import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/logistics/route_execution_service.dart';

void main() {
  late AppDatabase db;
  late RouteExecutionService service;
  int testCustomerId = 1;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = RouteExecutionService(db);

    // Insert prerequisite Customer
    testCustomerId = await db.into(db.customers).insert(
          CustomersCompanion.insert(
            code: 'CUST-ROUTE-01',
            shopName: 'Super Fresh Mart',
            ownerName: 'Retail Customer 1',
            phone: '9876500001',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('RouteExecutionService Tests', () {
    test('1. Adds route stops and retrieves them in sequence order', () async {
      final now = DateTime.now();
      await service.addRouteStop(
        routeId: 'ROUTE-101',
        stopSequence: 2,
        customerId: testCustomerId,
        plannedArrivalTime: now.add(const Duration(minutes: 60)),
      );

      await service.addRouteStop(
        routeId: 'ROUTE-101',
        stopSequence: 1,
        customerId: testCustomerId,
        plannedArrivalTime: now.add(const Duration(minutes: 30)),
      );

      final stops = await service.getRouteStops('ROUTE-101');
      expect(stops.length, 2);
      expect(stops[0].stopSequence, 1);
      expect(stops[1].stopSequence, 2);
    });

    test('2. Updates stop status to completed with proof of delivery', () async {
      final now = DateTime.now();
      final stopId = await service.addRouteStop(
        routeId: 'ROUTE-102',
        stopSequence: 1,
        customerId: testCustomerId,
        plannedArrivalTime: now,
      );

      await service.updateStopStatus(
        stopId,
        'completed',
        proofOfDeliveryRef: 'POD-SIGNATURE-BASE64-OR-URL',
        notes: 'Delivered 5 crates of toned milk',
      );

      final stops = await service.getRouteStops('ROUTE-102');
      expect(stops.first.status, 'completed');
      expect(stops.first.proofOfDeliveryRef, 'POD-SIGNATURE-BASE64-OR-URL');
      expect(stops.first.actualArrivalTime, isNotNull);
    });

    test('3. Computes route summary metrics accurately', () async {
      final now = DateTime.now();
      final s1 = await service.addRouteStop(
        routeId: 'ROUTE-103',
        stopSequence: 1,
        customerId: testCustomerId,
        plannedArrivalTime: now,
      );
      final s2 = await service.addRouteStop(
        routeId: 'ROUTE-103',
        stopSequence: 2,
        customerId: testCustomerId,
        plannedArrivalTime: now,
      );
      await service.addRouteStop(
        routeId: 'ROUTE-103',
        stopSequence: 3,
        customerId: testCustomerId,
        plannedArrivalTime: now,
      );

      await service.updateStopStatus(s1, 'completed');
      await service.updateStopStatus(s2, 'skipped', notes: 'Shop closed');

      final summary = await service.getRouteSummary('ROUTE-103');
      expect(summary.totalStops, 3);
      expect(summary.completedStops, 1);
      expect(summary.skippedStops, 1);
      expect(summary.pendingStops, 1);
      expect(summary.completionPercentage, closeTo(33.3, 0.5));
    });
  });
}
