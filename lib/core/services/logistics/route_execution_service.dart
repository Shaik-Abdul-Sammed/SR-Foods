import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class RouteExecutionSummary {
  final String routeId;
  final int totalStops;
  final int completedStops;
  final int skippedStops;
  final int pendingStops;
  final double completionPercentage;

  const RouteExecutionSummary({
    required this.routeId,
    required this.totalStops,
    required this.completedStops,
    required this.skippedStops,
    required this.pendingStops,
    required this.completionPercentage,
  });
}

class RouteExecutionService {
  final AppDatabase db;

  RouteExecutionService(this.db);

  /// Schedules a delivery stop on a designated route.
  Future<int> addRouteStop({
    required String routeId,
    int? vehicleId,
    int? driverId,
    required int stopSequence,
    required int customerId,
    int? orderId,
    required DateTime plannedArrivalTime,
  }) async {
    return db.into(db.routeStops).insert(
          RouteStopsCompanion.insert(
            routeId: routeId,
            vehicleId: Value(vehicleId),
            driverId: Value(driverId),
            stopSequence: stopSequence,
            customerId: customerId,
            orderId: Value(orderId),
            plannedArrivalTime: plannedArrivalTime,
            status: const Value('pending'),
          ),
        );
  }

  /// Updates status of a stop (e.g. arrived, completed, skipped) with POD proof.
  Future<void> updateStopStatus(
    int stopId,
    String status, {
    String? proofOfDeliveryRef,
    String? notes,
    DateTime? actualArrivalTime,
  }) async {
    await (db.update(db.routeStops)..where((tbl) => tbl.id.equals(stopId))).write(
      RouteStopsCompanion(
        status: Value(status),
        proofOfDeliveryRef: Value(proofOfDeliveryRef),
        notes: Value(notes),
        actualArrivalTime: Value(actualArrivalTime ?? DateTime.now()),
      ),
    );
  }

  /// Retrieves ordered stops for a route.
  Future<List<RouteStop>> getRouteStops(String routeId) async {
    return (db.select(db.routeStops)
          ..where((tbl) => tbl.routeId.equals(routeId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.stopSequence)]))
        .get();
  }

  /// Computes operational execution summary for a route.
  Future<RouteExecutionSummary> getRouteSummary(String routeId) async {
    final stops = await getRouteStops(routeId);
    if (stops.isEmpty) {
      return RouteExecutionSummary(
        routeId: routeId,
        totalStops: 0,
        completedStops: 0,
        skippedStops: 0,
        pendingStops: 0,
        completionPercentage: 0.0,
      );
    }

    final completed = stops.where((s) => s.status == 'completed').length;
    final skipped = stops.where((s) => s.status == 'skipped').length;
    final pending = stops.where((s) => s.status == 'pending' || s.status == 'arrived').length;

    return RouteExecutionSummary(
      routeId: routeId,
      totalStops: stops.length,
      completedStops: completed,
      skippedStops: skipped,
      pendingStops: pending,
      completionPercentage: ((completed / stops.length) * 100.0 * 10.0).round() / 10.0,
    );
  }
}
