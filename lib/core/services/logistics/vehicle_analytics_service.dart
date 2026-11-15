import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class FleetEfficiencyMetrics {
  final int vehicleId;
  final double totalDistanceKm;
  final double totalFuelLiters;
  final double fuelEfficiencyKmPerLiter;
  final double totalFuelCostRupees;
  final double costPerKmRupees;
  final double estimatedCo2EmissionsKg;

  const FleetEfficiencyMetrics({
    required this.vehicleId,
    required this.totalDistanceKm,
    required this.totalFuelLiters,
    required this.fuelEfficiencyKmPerLiter,
    required this.totalFuelCostRupees,
    required this.costPerKmRupees,
    required this.estimatedCo2EmissionsKg,
  });
}

class VehicleAnalyticsService {
  final AppDatabase db;

  VehicleAnalyticsService(this.db);

  /// Records an odometer reading and fuel expenditure log.
  Future<int> recordVehicleLog({
    required int vehicleId,
    int? driverId,
    required DateTime logDate,
    required double odometerStartKm,
    required double odometerEndKm,
    double? fuelLiters,
    int fuelCostMinor = 0,
    String? notes,
  }) async {
    return db.into(db.vehicleLogs).insert(
          VehicleLogsCompanion.insert(
            vehicleId: vehicleId,
            driverId: Value(driverId),
            logDate: logDate,
            odometerStartKm: odometerStartKm,
            odometerEndKm: odometerEndKm,
            fuelLiters: Value(fuelLiters),
            fuelCostMinor: Value(fuelCostMinor),
            notes: Value(notes),
          ),
        );
  }

  /// Evaluates efficiency, fuel economy, and emissions for a vehicle.
  Future<FleetEfficiencyMetrics> getVehicleMetrics(int vehicleId) async {
    final logs = await (db.select(db.vehicleLogs)..where((tbl) => tbl.vehicleId.equals(vehicleId))).get();
    if (logs.isEmpty) {
      return FleetEfficiencyMetrics(
        vehicleId: vehicleId,
        totalDistanceKm: 0.0,
        totalFuelLiters: 0.0,
        fuelEfficiencyKmPerLiter: 0.0,
        totalFuelCostRupees: 0.0,
        costPerKmRupees: 0.0,
        estimatedCo2EmissionsKg: 0.0,
      );
    }

    double totalDist = 0.0;
    double totalFuel = 0.0;
    int totalCostMinor = 0;

    for (final l in logs) {
      final tripDist = l.odometerEndKm - l.odometerStartKm;
      if (tripDist > 0) totalDist += tripDist;
      if (l.fuelLiters != null) totalFuel += l.fuelLiters!;
      totalCostMinor += l.fuelCostMinor;
    }

    final kmPerL = totalFuel > 0 ? totalDist / totalFuel : 0.0;
    final totalCostRs = totalCostMinor / 100.0;
    final costPerKm = totalDist > 0 ? totalCostRs / totalDist : 0.0;
    // Standard diesel emission factor: ~2.68 kg CO2 per liter burned
    final co2Kg = totalFuel * 2.68;

    return FleetEfficiencyMetrics(
      vehicleId: vehicleId,
      totalDistanceKm: (totalDist * 10.0).round() / 10.0,
      totalFuelLiters: (totalFuel * 10.0).round() / 10.0,
      fuelEfficiencyKmPerLiter: (kmPerL * 10.0).round() / 10.0,
      totalFuelCostRupees: (totalCostRs * 100.0).round() / 100.0,
      costPerKmRupees: (costPerKm * 100.0).round() / 100.0,
      estimatedCo2EmissionsKg: (co2Kg * 10.0).round() / 10.0,
    );
  }
}
