import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/logistics/vrp_solver.dart';

void main() {
  group('VrpSavingsSolver Tests', () {
    const depotLat = 17.3850;
    const depotLng = 78.4867; // Hyderabad Depot

    final customers = [
      const DeliveryCustomer(
        customerId: 1,
        name: 'Supermarket A',
        lat: 17.4156,
        lng: 78.4357,
        demandKg: 200.0,
      ),
      const DeliveryCustomer(
        customerId: 2,
        name: 'Store B',
        lat: 17.4200,
        lng: 78.4400,
        demandKg: 300.0,
      ),
      const DeliveryCustomer(
        customerId: 3,
        name: 'Outlet C',
        lat: 17.4483,
        lng: 78.3915,
        demandKg: 400.0,
      ),
      const DeliveryCustomer(
        customerId: 4,
        name: 'Retailer D',
        lat: 17.4442,
        lng: 78.3618,
        demandKg: 250.0,
      ),
    ];

    test('1. Merges nearby customers into single route within vehicle capacity', () {
      final solver = const VrpSavingsSolver(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicleCapacityKg: 1000.0,
      );

      final routes = solver.solve(customers);
      expect(routes.isNotEmpty, isTrue);

      for (final r in routes) {
        expect(r.totalDemandKg, lessThanOrEqualTo(1000.0));
        expect(r.totalDistanceKm, greaterThan(0.0));
      }
    });

    test('2. Splits routes when cumulative demand exceeds vehicle capacity', () {
      final solver = const VrpSavingsSolver(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicleCapacityKg: 500.0, // Smaller capacity requires multiple vehicles
      );

      final routes = solver.solve(customers);
      expect(routes.length, greaterThanOrEqualTo(2));

      for (final r in routes) {
        expect(r.totalDemandKg, lessThanOrEqualTo(500.0));
      }
    });

    test('3. Empty customer list returns empty route list', () {
      final solver = const VrpSavingsSolver(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicleCapacityKg: 1000.0,
      );

      final routes = solver.solve([]);
      expect(routes, isEmpty);
    });

    test('4. Haversine distance correctly computes zero distance for identical coordinates', () {
      final d = VrpSavingsSolver.haversineDistance(17.3850, 78.4867, 17.3850, 78.4867);
      expect(d, closeTo(0.0, 1e-4));
    });
  });
}
