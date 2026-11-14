import 'dart:math' as math;

/// Delivery record used for On-Time In-Full (OTIF) and Fill-Rate calculation.
class DeliveryRecord {
  final String orderId;
  final int orderedQuantity;
  final int deliveredQuantity;
  final DateTime scheduledDeliveryTime;
  final DateTime actualDeliveryTime;

  const DeliveryRecord({
    required this.orderId,
    required this.orderedQuantity,
    required this.deliveredQuantity,
    required this.scheduledDeliveryTime,
    required this.actualDeliveryTime,
  });

  bool get isInFull => deliveredQuantity >= orderedQuantity;
  bool get isOnTime => !actualDeliveryTime.isAfter(scheduledDeliveryTime);
  bool get isOtif => isInFull && isOnTime;
}

class OtifMetric {
  final int totalOrders;
  final int inFullCount;
  final int onTimeCount;
  final int otifCount;
  final double otifPercentage;
  final double fillRatePercentage;

  const OtifMetric({
    required this.totalOrders,
    required this.inFullCount,
    required this.onTimeCount,
    required this.otifCount,
    required this.otifPercentage,
    required this.fillRatePercentage,
  });
}

class DsoMetric {
  final double dsoDays;
  final double overdueRatio;
  final double accountsReceivable;
  final double overdueReceivables;
  final Map<String, double> agingBuckets;

  const DsoMetric({
    required this.dsoDays,
    required this.overdueRatio,
    required this.accountsReceivable,
    required this.overdueReceivables,
    required this.agingBuckets,
  });
}

class MarginMetric {
  final double revenue;
  final double costOfGoodsSold;
  final double grossProfit;
  final double grossMarginPercentage;

  const MarginMetric({
    required this.revenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.grossMarginPercentage,
  });
}

class CadenceMetric {
  final double averageIntervalDays;
  final double standardDeviationDays;
  final double regularityIndex; // 0.0 to 1.0 (1.0 = like clockwork)

  const CadenceMetric({
    required this.averageIntervalDays,
    required this.standardDeviationDays,
    required this.regularityIndex,
  });
}

class ChurnRiskMetric {
  final double churnProbability; // 0.0 to 1.0
  final String riskTier; // 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
  final String recommendation;

  const ChurnRiskMetric({
    required this.churnProbability,
    required this.riskTier,
    required this.recommendation,
  });
}

class MachineRulMetric {
  final double remainingUsefulLifeHours;
  final double wearRateMmSPerHour;
  final String healthGrade;

  const MachineRulMetric({
    required this.remainingUsefulLifeHours,
    required this.wearRateMmSPerHour,
    required this.healthGrade,
  });
}

class ScrapRateMetric {
  final int totalUnitsProduced;
  final int scrappedUnits;
  final double scrapRatePerThousand;
  final double yieldPercentage;

  const ScrapRateMetric({
    required this.totalUnitsProduced,
    required this.scrappedUnits,
    required this.scrapRatePerThousand,
    required this.yieldPercentage,
  });
}

class TemperatureLogPoint {
  final DateTime timestamp;
  final double temperatureCelsius;
  final double durationHours;

  const TemperatureLogPoint({
    required this.timestamp,
    required this.temperatureCelsius,
    required this.durationHours,
  });
}

class ThermalBreachMetric {
  final double totalDegreeHours;
  final bool isHaccpCompliant;
  final String status;

  const ThermalBreachMetric({
    required this.totalDegreeHours,
    required this.isHaccpCompliant,
    required this.status,
  });
}

class ExportMarginMetric {
  final double sellingPriceForeign;
  final double fxRate;
  final double realizedRevenueInr;
  final double totalLandedCostInr;
  final double grossProfitInr;
  final double netExportMarginPercentage;

  const ExportMarginMetric({
    required this.sellingPriceForeign,
    required this.fxRate,
    required this.realizedRevenueInr,
    required this.totalLandedCostInr,
    required this.grossProfitInr,
    required this.netExportMarginPercentage,
  });
}

class StandingOrderMetric {
  final int totalScheduledOrders;
  final int autoDispatchedOrders;
  final int manualInterventions;
  final double autoFulfillmentRate;
  final double manualInterventionRate;

  const StandingOrderMetric({
    required this.totalScheduledOrders,
    required this.autoDispatchedOrders,
    required this.manualInterventions,
    required this.autoFulfillmentRate,
    required this.manualInterventionRate,
  });
}

class ExecutiveKpiReport {
  final OtifMetric otif;
  final DsoMetric dso;
  final MarginMetric margin;
  final CadenceMetric cadence;
  final ChurnRiskMetric churn;
  final MachineRulMetric machineRul;
  final ScrapRateMetric scrapRate;
  final ThermalBreachMetric thermalBreach;
  final ExportMarginMetric exportMargin;
  final StandingOrderMetric standingOrders;
  final double corporateHealthScore; // 0 to 100

  const ExecutiveKpiReport({
    required this.otif,
    required this.dso,
    required this.margin,
    required this.cadence,
    required this.churn,
    required this.machineRul,
    required this.scrapRate,
    required this.thermalBreach,
    required this.exportMargin,
    required this.standingOrders,
    required this.corporateHealthScore,
  });
}

/// Core KPI Engine providing end-to-end mathematical rigor for factory & distribution analytics.
class ExecutiveKpiService {
  const ExecutiveKpiService();

  // 1. OTIF & Fill Rate
  OtifMetric computeOtif(List<DeliveryRecord> deliveries) {
    if (deliveries.isEmpty) {
      return const OtifMetric(
        totalOrders: 0,
        inFullCount: 0,
        onTimeCount: 0,
        otifCount: 0,
        otifPercentage: 100.0,
        fillRatePercentage: 100.0,
      );
    }

    int inFull = 0;
    int onTime = 0;
    int otif = 0;
    int totalOrderedQty = 0;
    int totalDeliveredQty = 0;

    for (final d in deliveries) {
      totalOrderedQty += d.orderedQuantity;
      totalDeliveredQty += d.deliveredQuantity;
      if (d.isInFull) inFull++;
      if (d.isOnTime) onTime++;
      if (d.isOtif) otif++;
    }

    final otifPct = (otif / deliveries.length) * 100.0;
    final fillRatePct = totalOrderedQty > 0
        ? math.min(100.0, (totalDeliveredQty / totalOrderedQty) * 100.0)
        : 100.0;

    return OtifMetric(
      totalOrders: deliveries.length,
      inFullCount: inFull,
      onTimeCount: onTime,
      otifCount: otif,
      otifPercentage: double.parse(otifPct.toStringAsFixed(2)),
      fillRatePercentage: double.parse(fillRatePct.toStringAsFixed(2)),
    );
  }

  // 2. DSO & Overdue Ratio
  DsoMetric computeDsoAndOverdue({
    required double accountsReceivable,
    required double periodGrossRevenue,
    required int periodDays,
    required double overdueReceivables,
    Map<String, double>? agingBuckets,
  }) {
    final dso = periodGrossRevenue > 0
        ? (accountsReceivable / periodGrossRevenue) * periodDays
        : 0.0;
    final overdueRatio = accountsReceivable > 0
        ? overdueReceivables / accountsReceivable
        : 0.0;

    return DsoMetric(
      dsoDays: double.parse(dso.toStringAsFixed(1)),
      overdueRatio: double.parse(overdueRatio.toStringAsFixed(3)),
      accountsReceivable: accountsReceivable,
      overdueReceivables: overdueReceivables,
      agingBuckets: agingBuckets ??
          {
            '0_30': accountsReceivable - overdueReceivables,
            '31_60': overdueReceivables * 0.6,
            '61_90': overdueReceivables * 0.3,
            '90_plus': overdueReceivables * 0.1,
          },
    );
  }

  // 3. Gross Margin %
  MarginMetric computeGrossMargin({
    required double revenue,
    required double costOfGoodsSold,
  }) {
    final profit = revenue - costOfGoodsSold;
    final marginPct = revenue > 0 ? (profit / revenue) * 100.0 : 0.0;

    return MarginMetric(
      revenue: revenue,
      costOfGoodsSold: costOfGoodsSold,
      grossProfit: double.parse(profit.toStringAsFixed(2)),
      grossMarginPercentage: double.parse(marginPct.toStringAsFixed(2)),
    );
  }

  // 4. Order Cadence & Regularity Index
  CadenceMetric computeOrderCadence(List<DateTime> orderDates) {
    if (orderDates.length < 2) {
      return const CadenceMetric(
        averageIntervalDays: 0.0,
        standardDeviationDays: 0.0,
        regularityIndex: 1.0,
      );
    }

    final sorted = List<DateTime>.from(orderDates)..sort();
    final intervals = <double>[];
    for (int i = 1; i < sorted.length; i++) {
      final days = sorted[i].difference(sorted[i - 1]).inHours / 24.0;
      intervals.add(days);
    }

    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals
            .map((x) => math.pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        intervals.length;
    final stdDev = math.sqrt(variance);

    // Regularity index: coefficient of variation inverse normalized to [0, 1]
    final cv = mean > 0 ? stdDev / mean : 0.0;
    final regularity = math.max(0.0, 1.0 - math.min(1.0, cv));

    return CadenceMetric(
      averageIntervalDays: double.parse(mean.toStringAsFixed(1)),
      standardDeviationDays: double.parse(stdDev.toStringAsFixed(2)),
      regularityIndex: double.parse(regularity.toStringAsFixed(2)),
    );
  }

  // 5. Churn Risk Probability
  ChurnRiskMetric computeChurnRiskScore({
    required int daysSinceLastOrder,
    required double expectedCadenceDays,
    required double volumeTrendRatio, // e.g. recent 30d volume / previous 30d volume
  }) {
    if (expectedCadenceDays <= 0) {
      return const ChurnRiskMetric(
        churnProbability: 0.0,
        riskTier: 'LOW',
        recommendation: 'Cadence undefined; monitor order patterns.',
      );
    }

    final cadenceOverdueRatio = daysSinceLastOrder / expectedCadenceDays;
    double probability = 0.0;

    if (cadenceOverdueRatio > 3.0) {
      probability += 0.6;
    } else if (cadenceOverdueRatio > 1.8) {
      probability += 0.4;
    } else if (cadenceOverdueRatio > 1.2) {
      probability += 0.2;
    }

    if (volumeTrendRatio < 0.5) {
      probability += 0.35;
    } else if (volumeTrendRatio < 0.8) {
      probability += 0.15;
    }

    probability = math.min(1.0, math.max(0.0, probability));

    String tier = 'LOW';
    String recommendation = 'Customer engagement healthy. Regular cadence.';

    if (probability >= 0.75) {
      tier = 'CRITICAL';
      recommendation =
          'Dispatch Key Account Manager immediately with retention offer.';
    } else if (probability >= 0.45) {
      tier = 'HIGH';
      recommendation = 'Trigger automated WhatsApp reorder reminder with promotional incentive.';
    } else if (probability >= 0.25) {
      tier = 'MEDIUM';
      recommendation = 'Flag for sales rep weekly follow-up.';
    }

    return ChurnRiskMetric(
      churnProbability: double.parse(probability.toStringAsFixed(2)),
      riskTier: tier,
      recommendation: recommendation,
    );
  }

  // 6. Machine Vibration RUL Hours
  MachineRulMetric computeMachineRul({
    required double baselineVibrationMmS,
    required double currentVibrationMmS,
    required double maxAllowedMmS,
    required double operatingHoursRun,
  }) {
    if (operatingHoursRun <= 0 || currentVibrationMmS <= baselineVibrationMmS) {
      return const MachineRulMetric(
        remainingUsefulLifeHours: 5000.0,
        wearRateMmSPerHour: 0.0001,
        healthGrade: 'EXCELLENT',
      );
    }

    final wearRate = (currentVibrationMmS - baselineVibrationMmS) / operatingHoursRun;
    final remainingMmS = math.max(0.0, maxAllowedMmS - currentVibrationMmS);
    final rulHours = wearRate > 0 ? remainingMmS / wearRate : 10000.0;

    String grade = 'EXCELLENT';
    if (currentVibrationMmS >= maxAllowedMmS) {
      grade = 'ACTION_REQUIRED';
    } else if (currentVibrationMmS >= 4.5) {
      grade = 'WARNING';
    } else if (currentVibrationMmS >= 2.8) {
      grade = 'ACCEPTABLE';
    }

    return MachineRulMetric(
      remainingUsefulLifeHours: double.parse(rulHours.toStringAsFixed(1)),
      wearRateMmSPerHour: double.parse(wearRate.toStringAsExponential(3)),
      healthGrade: grade,
    );
  }

  // 7. Scrap Rate per 1,000 packs
  ScrapRateMetric computeScrapRate({
    required int totalUnitsProduced,
    required int scrappedUnits,
  }) {
    if (totalUnitsProduced <= 0) {
      return const ScrapRateMetric(
        totalUnitsProduced: 0,
        scrappedUnits: 0,
        scrapRatePerThousand: 0.0,
        yieldPercentage: 100.0,
      );
    }

    final ratePerThousand = (scrappedUnits / totalUnitsProduced) * 1000.0;
    final yieldPct = ((totalUnitsProduced - scrappedUnits) / totalUnitsProduced) * 100.0;

    return ScrapRateMetric(
      totalUnitsProduced: totalUnitsProduced,
      scrappedUnits: scrappedUnits,
      scrapRatePerThousand: double.parse(ratePerThousand.toStringAsFixed(2)),
      yieldPercentage: double.parse(yieldPct.toStringAsFixed(2)),
    );
  }

  // 8. Cold-Chain Thermal Degree-Hours Breach
  ThermalBreachMetric computeThermalBreachDegreeHours({
    required List<TemperatureLogPoint> logs,
    required double upperLimitCelsius,
  }) {
    double totalDegreeHours = 0.0;

    for (final pt in logs) {
      if (pt.temperatureCelsius > upperLimitCelsius) {
        final delta = pt.temperatureCelsius - upperLimitCelsius;
        totalDegreeHours += delta * pt.durationHours;
      }
    }

    final isCompliant = totalDegreeHours <= 1.0; // max 1.0 degree-hour allowed for frozen flatbreads
    final status = isCompliant
        ? 'CCP PASSED — Cold Chain Maintained'
        : 'CCP VIOLATION — Threshold Exceeded ($totalDegreeHours degree-hours)';

    return ThermalBreachMetric(
      totalDegreeHours: double.parse(totalDegreeHours.toStringAsFixed(2)),
      isHaccpCompliant: isCompliant,
      status: status,
    );
  }

  // 9. Landed Cost & Tariff Margin
  ExportMarginMetric computeLandedCostMargin({
    required double sellingPriceForeign,
    required double fxRate,
    required double fobCostInr,
    required double freightInr,
    required double dutyInr,
    required double portHandlingInr,
  }) {
    final realizedInr = sellingPriceForeign * fxRate;
    final landedCostInr = fobCostInr + freightInr + dutyInr + portHandlingInr;
    final grossProfitInr = realizedInr - landedCostInr;
    final marginPct = realizedInr > 0 ? (grossProfitInr / realizedInr) * 100.0 : 0.0;

    return ExportMarginMetric(
      sellingPriceForeign: sellingPriceForeign,
      fxRate: fxRate,
      realizedRevenueInr: double.parse(realizedInr.toStringAsFixed(2)),
      totalLandedCostInr: double.parse(landedCostInr.toStringAsFixed(2)),
      grossProfitInr: double.parse(grossProfitInr.toStringAsFixed(2)),
      netExportMarginPercentage: double.parse(marginPct.toStringAsFixed(2)),
    );
  }

  // 10. Standing Order Auto-Fulfillment Rate
  StandingOrderMetric computeStandingOrderFulfillment({
    required int totalScheduledOrders,
    required int autoDispatchedOrders,
    required int manualInterventions,
  }) {
    if (totalScheduledOrders <= 0) {
      return const StandingOrderMetric(
        totalScheduledOrders: 0,
        autoDispatchedOrders: 0,
        manualInterventions: 0,
        autoFulfillmentRate: 100.0,
        manualInterventionRate: 0.0,
      );
    }

    final autoRate = (autoDispatchedOrders / totalScheduledOrders) * 100.0;
    final manualRate = (manualInterventions / totalScheduledOrders) * 100.0;

    return StandingOrderMetric(
      totalScheduledOrders: totalScheduledOrders,
      autoDispatchedOrders: autoDispatchedOrders,
      manualInterventions: manualInterventions,
      autoFulfillmentRate: double.parse(autoRate.toStringAsFixed(2)),
      manualInterventionRate: double.parse(manualRate.toStringAsFixed(2)),
    );
  }

  // Executive Dashboard Synthesis
  ExecutiveKpiReport generateExecutiveReport({
    required List<DeliveryRecord> deliveries,
    required double accountsReceivable,
    required double periodGrossRevenue,
    required int periodDays,
    required double overdueReceivables,
    required double totalRevenue,
    required double totalCogs,
    required List<DateTime> orderDates,
    required int daysSinceLastOrder,
    required double expectedCadenceDays,
    required double volumeTrendRatio,
    required double baselineVibMmS,
    required double currentVibMmS,
    required double maxAllowedVibMmS,
    required double operatingHoursRun,
    required int totalUnitsProduced,
    required int scrappedUnits,
    required List<TemperatureLogPoint> tempLogs,
    required double tempLimitCelsius,
    required double exportSellingForeign,
    required double fxRate,
    required double exportFobInr,
    required double exportFreightInr,
    required double exportDutyInr,
    required double exportPortInr,
    required int totalScheduledOrders,
    required int autoDispatchedOrders,
    required int manualInterventions,
  }) {
    final otif = computeOtif(deliveries);
    final dso = computeDsoAndOverdue(
      accountsReceivable: accountsReceivable,
      periodGrossRevenue: periodGrossRevenue,
      periodDays: periodDays,
      overdueReceivables: overdueReceivables,
    );
    final margin = computeGrossMargin(
      revenue: totalRevenue,
      costOfGoodsSold: totalCogs,
    );
    final cadence = computeOrderCadence(orderDates);
    final churn = computeChurnRiskScore(
      daysSinceLastOrder: daysSinceLastOrder,
      expectedCadenceDays: expectedCadenceDays,
      volumeTrendRatio: volumeTrendRatio,
    );
    final machineRul = computeMachineRul(
      baselineVibrationMmS: baselineVibMmS,
      currentVibrationMmS: currentVibMmS,
      maxAllowedMmS: maxAllowedVibMmS,
      operatingHoursRun: operatingHoursRun,
    );
    final scrapRate = computeScrapRate(
      totalUnitsProduced: totalUnitsProduced,
      scrappedUnits: scrappedUnits,
    );
    final thermal = computeThermalBreachDegreeHours(
      logs: tempLogs,
      upperLimitCelsius: tempLimitCelsius,
    );
    final export = computeLandedCostMargin(
      sellingPriceForeign: exportSellingForeign,
      fxRate: fxRate,
      fobCostInr: exportFobInr,
      freightInr: exportFreightInr,
      dutyInr: exportDutyInr,
      portHandlingInr: exportPortInr,
    );
    final standing = computeStandingOrderFulfillment(
      totalScheduledOrders: totalScheduledOrders,
      autoDispatchedOrders: autoDispatchedOrders,
      manualInterventions: manualInterventions,
    );

    // Weighted Corporate Health Score (0 - 100)
    // OTIF (15%) + Margin (15%) + Low DSO (10%) + Low Churn (10%) + Scrap Yield (10%) +
    // Cold Chain Compliance (10%) + Export Margin (10%) + Standing Order Rate (10%) +
    // Machine Health (10%)
    double score = 0.0;
    score += (otif.otifPercentage / 100.0) * 15.0;
    score += math.min(15.0, (margin.grossMarginPercentage / 40.0) * 15.0);
    score += math.max(0.0, (1.0 - math.min(1.0, dso.dsoDays / 60.0)) * 10.0);
    score += (1.0 - churn.churnProbability) * 10.0;
    score += (scrapRate.yieldPercentage / 100.0) * 10.0;
    score += (thermal.isHaccpCompliant ? 10.0 : 0.0);
    score += math.min(10.0, (export.netExportMarginPercentage / 30.0) * 10.0);
    score += (standing.autoFulfillmentRate / 100.0) * 10.0;
    score += (machineRul.healthGrade == 'EXCELLENT'
        ? 10.0
        : machineRul.healthGrade == 'ACCEPTABLE'
            ? 8.0
            : machineRul.healthGrade == 'WARNING'
                ? 4.0
                : 0.0);

    return ExecutiveKpiReport(
      otif: otif,
      dso: dso,
      margin: margin,
      cadence: cadence,
      churn: churn,
      machineRul: machineRul,
      scrapRate: scrapRate,
      thermalBreach: thermal,
      exportMargin: export,
      standingOrders: standing,
      corporateHealthScore: double.parse(score.toStringAsFixed(1)),
    );
  }
}
