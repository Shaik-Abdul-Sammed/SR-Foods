import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/logistics/logistics_kpi_service.dart';

void main() {
  group('LogisticsKpiService Tests', () {
    const service = LogisticsKpiService();

    test('1. Calculates high OTIF when on-time and in-full percentages are high', () {
      final kpi = service.calculateKpis(
        totalOrders: 100,
        onTimeOrders: 98,
        inFullOrders: 96,
        activeVehicles: 8,
        totalVehicles: 10,
        totalTelemetryReadings: 1000,
        breachTelemetryReadings: 5,
        totalDistanceKm: 1200.0,
        totalExpensesRupees: 12000.0,
        distanceSavedKm: 200.0,
      );

      // OTIF = (98/100) * (96/100) = 94.08% => 94.1%
      expect(kpi.otifPercentage, closeTo(94.1, 0.2));
      expect(kpi.fleetUtilizationPercentage, equals(80.0));
      expect(kpi.coldChainCompliancePercentage, equals(99.5));
      expect(kpi.averageCostPerKmRupees, equals(10.0));
      expect(kpi.totalCo2SavedKg, greaterThan(0.0));
    });

    test('2. Cold chain compliance drops with higher breach counts', () {
      final kpi = service.calculateKpis(
        totalOrders: 50,
        onTimeOrders: 50,
        inFullOrders: 50,
        activeVehicles: 5,
        totalVehicles: 5,
        totalTelemetryReadings: 100,
        breachTelemetryReadings: 10, // 10% breach rate => 90% compliance
        totalDistanceKm: 500.0,
        totalExpensesRupees: 5000.0,
        distanceSavedKm: 50.0,
      );

      expect(kpi.coldChainCompliancePercentage, equals(90.0));
    });

    test('3. Handles zero orders and vehicles without division by zero', () {
      final kpi = service.calculateKpis(
        totalOrders: 0,
        onTimeOrders: 0,
        inFullOrders: 0,
        activeVehicles: 0,
        totalVehicles: 0,
        totalTelemetryReadings: 0,
        breachTelemetryReadings: 0,
        totalDistanceKm: 0.0,
        totalExpensesRupees: 0.0,
        distanceSavedKm: 0.0,
      );

      expect(kpi.otifPercentage, equals(100.0));
      expect(kpi.fleetUtilizationPercentage, equals(0.0));
      expect(kpi.coldChainCompliancePercentage, equals(100.0));
      expect(kpi.averageCostPerKmRupees, equals(0.0));
      expect(kpi.totalCo2SavedKg, equals(0.0));
    });
  });
}
