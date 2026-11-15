import 'dart:math' as math;

class DeliveryCustomer {
  final int customerId;
  final String name;
  final double lat;
  final double lng;
  final double demandKg;
  final String temperatureRequirement; // 'ambient', 'chilled', 'frozen'

  const DeliveryCustomer({
    required this.customerId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.demandKg,
    this.temperatureRequirement = 'ambient',
  });
}

class PlannedRoute {
  final int vehicleId;
  final List<DeliveryCustomer> customers;
  final double totalDistanceKm;
  final double totalDemandKg;

  const PlannedRoute({
    required this.vehicleId,
    required this.customers,
    required this.totalDistanceKm,
    required this.totalDemandKg,
  });
}

class VrpSavingsSolver {
  final double depotLat;
  final double depotLng;
  final double vehicleCapacityKg;

  const VrpSavingsSolver({
    required this.depotLat,
    required this.depotLng,
    required this.vehicleCapacityKg,
  });

  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Solves VRP using Clarke-Wright Savings algorithm with capacity constraints and 2-opt local search.
  List<PlannedRoute> solve(List<DeliveryCustomer> customers, {int availableVehicles = 5}) {
    if (customers.isEmpty) return [];

    // 1. Initial individual round-trip routes for each customer: Depot -> i -> Depot
    var routes = customers.map((c) => [c]).toList();

    // 2. Compute savings S_ij = d(0, i) + d(0, j) - d(i, j)
    final savingsList = <_Saving>[];
    for (int i = 0; i < customers.length; i++) {
      for (int j = i + 1; j < customers.length; j++) {
        final c1 = customers[i];
        final c2 = customers[j];
        final d01 = haversineDistance(depotLat, depotLng, c1.lat, c1.lng);
        final d02 = haversineDistance(depotLat, depotLng, c2.lat, c2.lng);
        final d12 = haversineDistance(c1.lat, c1.lng, c2.lat, c2.lng);
        final s = d01 + d02 - d12;
        if (s > 0) {
          savingsList.add(_Saving(i, j, s));
        }
      }
    }

    // Sort savings descending
    savingsList.sort((a, b) => b.saving.compareTo(a.saving));

    // 3. Merge routes greedily while respecting vehicle capacity
    for (final s in savingsList) {
      final c1 = customers[s.i];
      final c2 = customers[s.j];

      // Find routes containing c1 and c2
      final route1 = routes.firstWhere((r) => r.contains(c1));
      final route2 = routes.firstWhere((r) => r.contains(c2));

      if (identical(route1, route2)) continue; // Already in same route

      final combinedDemand =
          route1.fold<double>(0.0, (acc, c) => acc + c.demandKg) +
          route2.fold<double>(0.0, (acc, c) => acc + c.demandKg);

      if (combinedDemand > vehicleCapacityKg) continue;

      // Merge only if c1 and c2 are at exterior ends of their routes
      if (route1.last == c1 && route2.first == c2) {
        routes.remove(route2);
        route1.addAll(route2);
      } else if (route2.last == c2 && route1.first == c1) {
        routes.remove(route1);
        route2.addAll(route1);
      }
    }

    // 4. Apply 2-opt local search optimization to each route
    final optimizedPlans = <PlannedRoute>[];
    int vehicleIdx = 1;

    for (final r in routes) {
      final optRoute = _twoOpt(r);
      double dist = 0.0;
      double demand = 0.0;
      double pLat = depotLat;
      double pLng = depotLng;

      for (final c in optRoute) {
        dist += haversineDistance(pLat, pLng, c.lat, c.lng);
        demand += c.demandKg;
        pLat = c.lat;
        pLng = c.lng;
      }
      dist += haversineDistance(pLat, pLng, depotLat, depotLng);

      optimizedPlans.add(PlannedRoute(
        vehicleId: vehicleIdx++,
        customers: List.unmodifiable(optRoute),
        totalDistanceKm: (dist * 10.0).round() / 10.0,
        totalDemandKg: (demand * 10.0).round() / 10.0,
      ));
    }

    return optimizedPlans;
  }

  List<DeliveryCustomer> _twoOpt(List<DeliveryCustomer> route) {
    if (route.length <= 2) return route;
    final r = List<DeliveryCustomer>.from(route);
    bool improved = true;
    while (improved) {
      improved = false;
      for (int i = 0; i < r.length - 1; i++) {
        for (int j = i + 1; j < r.length; j++) {
          final oldDist = _segmentDistance(r);
          final reversed = r.sublist(i, j + 1).reversed.toList();
          final candidate = List<DeliveryCustomer>.from(r)..replaceRange(i, j + 1, reversed);
          if (_segmentDistance(candidate) < oldDist - 0.01) {
            r.replaceRange(i, j + 1, reversed);
            improved = true;
          }
        }
      }
    }
    return r;
  }

  double _segmentDistance(List<DeliveryCustomer> list) {
    double d = 0.0;
    double pLat = depotLat;
    double pLng = depotLng;
    for (final c in list) {
      d += haversineDistance(pLat, pLng, c.lat, c.lng);
      pLat = c.lat;
      pLng = c.lng;
    }
    d += haversineDistance(pLat, pLng, depotLat, depotLng);
    return d;
  }
}

class _Saving {
  final int i;
  final int j;
  final double saving;
  _Saving(this.i, this.j, this.saving);
}
