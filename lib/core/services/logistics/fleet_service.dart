import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class FleetService {
  final AppDatabase db;

  FleetService(this.db);

  /// Registers a new vehicle into the fleet.
  Future<int> registerVehicle({
    required String vehicleNumber,
    required String vehicleType,
    required double capacityKg,
    double? capacityVolumeCbm,
    bool hasReefer = false,
    double? minTemperatureC,
    double? maxTemperatureC,
    String status = 'available',
  }) async {
    return db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            vehicleNumber: vehicleNumber,
            vehicleType: vehicleType,
            capacityKg: capacityKg,
            capacityVolumeCbm: Value(capacityVolumeCbm),
            hasReefer: Value(hasReefer),
            minTemperatureC: Value(minTemperatureC),
            maxTemperatureC: Value(maxTemperatureC),
            status: Value(status),
          ),
        );
  }

  /// Registers a driver in the fleet.
  Future<int> registerDriver({
    required String name,
    required String phone,
    required String licenseNumber,
    String status = 'active',
  }) async {
    return db.into(db.drivers).insert(
          DriversCompanion.insert(
            name: name,
            phone: phone,
            licenseNumber: licenseNumber,
            status: Value(status),
          ),
        );
  }

  /// Assigns a driver to a vehicle.
  Future<void> assignDriverToVehicle(int driverId, int? vehicleId) async {
    await (db.update(db.drivers)..where((tbl) => tbl.id.equals(driverId))).write(
      DriversCompanion(
        assignedVehicleId: Value(vehicleId),
        status: Value(vehicleId != null ? 'on_trip' : 'active'),
      ),
    );
  }

  /// Updates vehicle operational status (e.g. available, in_transit, maintenance).
  Future<void> updateVehicleStatus(int vehicleId, String status) async {
    await (db.update(db.vehicles)..where((tbl) => tbl.id.equals(vehicleId))).write(
      VehiclesCompanion(status: Value(status)),
    );
  }

  /// Lists vehicles, optionally filtering by reefer capability and status.
  Future<List<Vehicle>> getVehicles({bool? reeferOnly, String? status}) async {
    final query = db.select(db.vehicles);
    if (reeferOnly == true) {
      query.where((tbl) => tbl.hasReefer.equals(true));
    }
    if (status != null) {
      query.where((tbl) => tbl.status.equals(status));
    }
    return query.get();
  }

  /// Lists all active drivers.
  Future<List<Driver>> getActiveDrivers() async {
    return (db.select(db.drivers)..where((tbl) => tbl.status.isNotValue('off_duty'))).get();
  }
}
