import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/logistics/fleet_service.dart';

void main() {
  late AppDatabase db;
  late FleetService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = FleetService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('FleetService Tests', () {
    test('1. Registers vehicle and retrieves by reefer filter', () async {
      await service.registerVehicle(
        vehicleNumber: 'TS09-REEFER-1',
        vehicleType: 'reefer_truck',
        capacityKg: 2000.0,
        hasReefer: true,
        minTemperatureC: -20.0,
        maxTemperatureC: 4.0,
      );

      await service.registerVehicle(
        vehicleNumber: 'TS09-VAN-2',
        vehicleType: 'van',
        capacityKg: 800.0,
        hasReefer: false,
      );

      final reeferVehicles = await service.getVehicles(reeferOnly: true);
      expect(reeferVehicles.length, 1);
      expect(reeferVehicles.first.vehicleNumber, 'TS09-REEFER-1');

      final allVehicles = await service.getVehicles();
      expect(allVehicles.length, 2);
    });

    test('2. Registers driver and lists active drivers', () async {
      final driverId = await service.registerDriver(
        name: 'Ramesh Kumar',
        phone: '9876543210',
        licenseNumber: 'TS-DL-2026-001',
      );

      expect(driverId, greaterThan(0));

      final active = await service.getActiveDrivers();
      expect(active.length, 1);
      expect(active.first.name, 'Ramesh Kumar');
    });

    test('3. Assigns driver to vehicle and updates driver status', () async {
      final vId = await service.registerVehicle(
        vehicleNumber: 'TS09-VAN-3',
        vehicleType: 'van',
        capacityKg: 1000.0,
      );

      final dId = await service.registerDriver(
        name: 'Suresh Rao',
        phone: '9876543211',
        licenseNumber: 'TS-DL-2026-002',
      );

      await service.assignDriverToVehicle(dId, vId);

      final driver = await (db.select(db.drivers)..where((tbl) => tbl.id.equals(dId))).getSingle();
      expect(driver.assignedVehicleId, vId);
      expect(driver.status, 'on_trip');
    });

    test('4. Updates vehicle operational status', () async {
      final vId = await service.registerVehicle(
        vehicleNumber: 'TS09-VAN-4',
        vehicleType: 'van',
        capacityKg: 900.0,
      );

      await service.updateVehicleStatus(vId, 'maintenance');

      final vehicle = await (db.select(db.vehicles)..where((tbl) => tbl.id.equals(vId))).getSingle();
      expect(vehicle.status, 'maintenance');
    });
  });
}
