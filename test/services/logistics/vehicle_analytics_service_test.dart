import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/logistics/vehicle_analytics_service.dart';

void main() {
  late AppDatabase db;
  late VehicleAnalyticsService service;
  int testVehicleId = 1;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = VehicleAnalyticsService(db);

    testVehicleId = await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            vehicleNumber: 'TS09-LOG-01',
            vehicleType: 'van',
            capacityKg: 1000.0,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('VehicleAnalyticsService Tests', () {
    test('1. Records vehicle trip log and evaluates efficiency metrics', () async {
      final now = DateTime.now();

      await service.recordVehicleLog(
        vehicleId: testVehicleId,
        logDate: now,
        odometerStartKm: 10000.0,
        odometerEndKm: 10120.0, // 120 km
        fuelLiters: 12.0, // 10 km/L
        fuelCostMinor: 110400, // ₹1,104.00
      );

      final metrics = await service.getVehicleMetrics(testVehicleId);
      expect(metrics.totalDistanceKm, 120.0);
      expect(metrics.totalFuelLiters, 12.0);
      expect(metrics.fuelEfficiencyKmPerLiter, 10.0);
      expect(metrics.totalFuelCostRupees, 1104.0);
      expect(metrics.costPerKmRupees, closeTo(9.2, 0.1));
      expect(metrics.estimatedCo2EmissionsKg, closeTo(32.16, 0.5));
    });

    test('2. Multiple trips accumulate correctly', () async {
      final now = DateTime.now();

      await service.recordVehicleLog(
        vehicleId: testVehicleId,
        logDate: now,
        odometerStartKm: 10000.0,
        odometerEndKm: 10050.0, // 50 km
        fuelLiters: 5.0,
        fuelCostMinor: 46000,
      );

      await service.recordVehicleLog(
        vehicleId: testVehicleId,
        logDate: now.add(const Duration(days: 1)),
        odometerStartKm: 10050.0,
        odometerEndKm: 10150.0, // 100 km
        fuelLiters: 10.0,
        fuelCostMinor: 92000,
      );

      final metrics = await service.getVehicleMetrics(testVehicleId);
      expect(metrics.totalDistanceKm, 150.0);
      expect(metrics.totalFuelLiters, 15.0);
      expect(metrics.fuelEfficiencyKmPerLiter, 10.0);
      expect(metrics.totalFuelCostRupees, 1380.0);
    });

    test('3. Vehicle with no logs returns zeroed metrics', () async {
      final metrics = await service.getVehicleMetrics(999);
      expect(metrics.totalDistanceKm, 0.0);
      expect(metrics.fuelEfficiencyKmPerLiter, 0.0);
    });
  });
}
