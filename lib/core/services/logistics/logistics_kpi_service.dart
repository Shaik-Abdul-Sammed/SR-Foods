class LogisticsKpiReport {
  final double otifPercentage; // On-Time In-Full
  final double fleetUtilizationPercentage;
  final double coldChainCompliancePercentage;
  final double averageCostPerKmRupees;
  final double totalFleetDistanceKm;
  final double totalCo2SavedKg;

  const LogisticsKpiReport({
    required this.otifPercentage,
    required this.fleetUtilizationPercentage,
    required this.coldChainCompliancePercentage,
    required this.averageCostPerKmRupees,
    required this.totalFleetDistanceKm,
    required this.totalCo2SavedKg,
  });
}

class LogisticsKpiService {
  const LogisticsKpiService();

  LogisticsKpiReport calculateKpis({
    required int totalOrders,
    required int onTimeOrders,
    required int inFullOrders,
    required int activeVehicles,
    required int totalVehicles,
    required int totalTelemetryReadings,
    required int breachTelemetryReadings,
    required double totalDistanceKm,
    required double totalExpensesRupees,
    required double distanceSavedKm,
  }) {
    // OTIF: orders that are both on-time and in-full
    final onTimeFraction = totalOrders > 0 ? (onTimeOrders / totalOrders) : 1.0;
    final inFullFraction = totalOrders > 0 ? (inFullOrders / totalOrders) : 1.0;
    final otif = (onTimeFraction * inFullFraction * 100.0).clamp(0.0, 100.0);

    final fleetUtil = totalVehicles > 0 ? (activeVehicles / totalVehicles * 100.0).clamp(0.0, 100.0) : 0.0;

    final coldChainComp = totalTelemetryReadings > 0
        ? ((1.0 - (breachTelemetryReadings / totalTelemetryReadings)) * 100.0).clamp(0.0, 100.0)
        : 100.0;

    final costPerKm = totalDistanceKm > 0 ? (totalExpensesRupees / totalDistanceKm) : 0.0;

    // CO2 saved: distance saved / 10 km/L * 2.68 kg CO2/L
    final co2Saved = (distanceSavedKm / 10.0) * 2.68;

    return LogisticsKpiReport(
      otifPercentage: (otif * 10.0).round() / 10.0,
      fleetUtilizationPercentage: (fleetUtil * 10.0).round() / 10.0,
      coldChainCompliancePercentage: (coldChainComp * 10.0).round() / 10.0,
      averageCostPerKmRupees: (costPerKm * 100.0).round() / 100.0,
      totalFleetDistanceKm: (totalDistanceKm * 10.0).round() / 10.0,
      totalCo2SavedKg: (co2Saved * 10.0).round() / 10.0,
    );
  }
}
