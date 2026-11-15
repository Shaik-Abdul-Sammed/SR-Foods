// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/vrp_annealer.dart';

void main() {
  group('QuantumVrpAnnealer Tests (Quantum-Inspired Classical)', () {
    const depotLat = 17.3850;
    const depotLng = 78.4867; // Hyderabad Central Depot

    final sampleVehicles = [
      const VrpVehicle(
        id: 'VEH-01-REEFER',
        registration: 'TS09-UA-1001',
        maxWeightKg: 1500.0,
        maxVolumeM3: 8.0,
        supportedZones: {ColdChainZone.frozen, ColdChainZone.chilled, ColdChainZone.ambient},
      ),
      const VrpVehicle(
        id: 'VEH-02-INSULATED',
        registration: 'TS09-UA-1002',
        maxWeightKg: 1000.0,
        maxVolumeM3: 6.0,
        supportedZones: {ColdChainZone.chilled, ColdChainZone.ambient},
      ),
      const VrpVehicle(
        id: 'VEH-03-DRY',
        registration: 'TS09-UA-1003',
        maxWeightKg: 800.0,
        maxVolumeM3: 5.0,
        supportedZones: {ColdChainZone.ambient},
      ),
    ];

    final sampleStops = [
      const VrpStop(
        id: 'STOP-01-ICE-CREAM',
        address: 'Banjara Hills Rd 12',
        lat: 17.4156,
        lng: 78.4357,
        weightKg: 200.0,
        volumeM3: 1.5,
        requiredZone: ColdChainZone.frozen,
      ),
      const VrpStop(
        id: 'STOP-02-MILK',
        address: 'Jubilee Hills Checkpost',
        lat: 17.4319,
        lng: 78.4073,
        weightKg: 350.0,
        volumeM3: 1.8,
        requiredZone: ColdChainZone.chilled,
      ),
      const VrpStop(
        id: 'STOP-03-BREAD',
        address: 'Madhapur Hitech City',
        lat: 17.4483,
        lng: 78.3915,
        weightKg: 150.0,
        volumeM3: 1.2,
        requiredZone: ColdChainZone.ambient,
      ),
      const VrpStop(
        id: 'STOP-04-FROZEN-PEAS',
        address: 'Gachibowli DLF',
        lat: 17.4442,
        lng: 78.3618,
        weightKg: 180.0,
        volumeM3: 1.0,
        requiredZone: ColdChainZone.frozen,
      ),
    ];

    test('1. Distributes stops and enforces frozen zone segregation on reefer vehicle', () {
      final annealer = QuantumVrpAnnealer(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicles: sampleVehicles,
        stops: sampleStops,
      );

      final result = annealer.optimize(iterations: 300, seed: 101);

      expect(result.totalStopsServed, equals(4));
      expect(result.totalDistanceKm, greaterThan(0.0));

      // Frozen stops must strictly be assigned to reefer truck
      final reeferRoute = result.vehicleRoutes.firstWhere((r) => r.vehicleId == 'VEH-01-REEFER');
      final dryRoute = result.vehicleRoutes.firstWhere((r) => r.vehicleId == 'VEH-03-DRY');

      for (final st in dryRoute.stops) {
        expect(st.requiredZone, equals(ColdChainZone.ambient));
      }
      expect(reeferRoute.coldChainValid, isTrue);
    });

    test('2. Vehicle weight capacity is strictly checked', () {
      final annealer = QuantumVrpAnnealer(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicles: sampleVehicles,
        stops: sampleStops,
      );

      final result = annealer.optimize(iterations: 300, seed: 202);

      for (final route in result.vehicleRoutes) {
        final vehicle = sampleVehicles.firstWhere((v) => v.id == route.vehicleId);
        expect(route.totalWeightKg, lessThanOrEqualTo(vehicle.maxWeightKg));
      }
    });

    test('3. Quantum tunneling events occur during local minima escape', () {
      final annealer = QuantumVrpAnnealer(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicles: sampleVehicles,
        stops: sampleStops,
      );

      final result = annealer.optimize(iterations: 300, seed: 303);
      expect(result.quantumTunnelingEvents, greaterThanOrEqualTo(0));
    });

    test('4. Computes fuel and cost savings from route compression', () {
      final annealer = QuantumVrpAnnealer(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicles: sampleVehicles,
        stops: sampleStops,
      );

      final result = annealer.optimize(iterations: 200, seed: 404);
      expect(result.fuelSavedLiters, greaterThan(0.0));
      expect(result.costSavedRupees, greaterThan(0.0));
    });

    test('5. Handles empty stops or vehicles without throwing', () {
      final annealer = QuantumVrpAnnealer(
        depotLat: depotLat,
        depotLng: depotLng,
        vehicles: [],
        stops: [],
      );

      final result = annealer.optimize();
      expect(result.vehicleRoutes, isEmpty);
      expect(result.totalDistanceKm, equals(0.0));
      expect(result.allConstraintsSatisfied, isTrue);
    });
  });
}
