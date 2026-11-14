import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/kpi_service.dart';

void main() {
  const service = ExecutiveKpiService();

  group('Phase 11 — 10 KPI Measurement & Executive Dashboard Suite', () {
    test('KPI 1: OTIF & Fill Rate accurately calculates on-time and full-quantity deliveries', () {
      final now = DateTime.now();
      final deliveries = [
        DeliveryRecord(
          orderId: 'ORD-001',
          orderedQuantity: 100,
          deliveredQuantity: 100,
          scheduledDeliveryTime: now,
          actualDeliveryTime: now.subtract(const Duration(minutes: 10)),
        ),
        DeliveryRecord(
          orderId: 'ORD-002',
          orderedQuantity: 50,
          deliveredQuantity: 50,
          scheduledDeliveryTime: now,
          actualDeliveryTime: now.add(const Duration(minutes: 5)), // Late
        ),
        DeliveryRecord(
          orderId: 'ORD-003',
          orderedQuantity: 200,
          deliveredQuantity: 180, // Under-filled
          scheduledDeliveryTime: now,
          actualDeliveryTime: now.subtract(const Duration(minutes: 5)),
        ),
        DeliveryRecord(
          orderId: 'ORD-004',
          orderedQuantity: 150,
          deliveredQuantity: 150,
          scheduledDeliveryTime: now,
          actualDeliveryTime: now.subtract(const Duration(minutes: 20)),
        ),
      ];

      final metric = service.computeOtif(deliveries);

      expect(metric.totalOrders, equals(4));
      expect(metric.inFullCount, equals(3)); // ORD-001, 002, 004
      expect(metric.onTimeCount, equals(3)); // ORD-001, 003, 004
      expect(metric.otifCount, equals(2)); // ORD-001, 004
      expect(metric.otifPercentage, equals(50.0));
      // Total ordered: 100+50+200+150 = 500. Total delivered: 100+50+180+150 = 480. Fill rate = 480/500 = 96%
      expect(metric.fillRatePercentage, equals(96.0));
    });

    test('KPI 2: DSO & Overdue Ratio models cash-to-cash cycle and aging buckets', () {
      final metric = service.computeDsoAndOverdue(
        accountsReceivable: 150000.0,
        periodGrossRevenue: 900000.0,
        periodDays: 90,
        overdueReceivables: 30000.0,
      );

      // DSO = (150,000 / 900,000) * 90 = 15.0 days
      expect(metric.dsoDays, equals(15.0));
      // Overdue ratio = 30,000 / 150,000 = 0.20 (20%)
      expect(metric.overdueRatio, equals(0.2));
      expect(metric.agingBuckets.containsKey('0_30'), isTrue);
      expect(metric.agingBuckets['0_30'], equals(120000.0));
    });

    test('KPI 3: Gross Margin % computes profitability per SKU and aggregate portfolio', () {
      final metric = service.computeGrossMargin(
        revenue: 250000.0,
        costOfGoodsSold: 165000.0,
      );

      expect(metric.grossProfit, equals(85000.0));
      // 85,000 / 250,000 = 34.0%
      expect(metric.grossMarginPercentage, equals(34.0));
    });

    test('KPI 4: Order Cycle Cadence and Regularity Index evaluates ordering predictability', () {
      final base = DateTime(2026, 1, 1);
      // Perfectly regular 3-day orders
      final regularOrders = [
        base,
        base.add(const Duration(days: 3)),
        base.add(const Duration(days: 6)),
        base.add(const Duration(days: 9)),
      ];

      final cadence = service.computeOrderCadence(regularOrders);
      expect(cadence.averageIntervalDays, equals(3.0));
      expect(cadence.standardDeviationDays, equals(0.0));
      expect(cadence.regularityIndex, equals(1.0)); // Perfect clockwork

      // Erratic orders
      final erraticOrders = [
        base,
        base.add(const Duration(days: 1)),
        base.add(const Duration(days: 8)),
        base.add(const Duration(days: 10)),
      ];
      final erraticCadence = service.computeOrderCadence(erraticOrders);
      expect(erraticCadence.regularityIndex, lessThan(0.8));
    });

    test('KPI 5: Churn Risk Score detects cadence lapses and volume decay', () {
      // Healthy customer: 2 days since order with 3-day cadence, 100% volume
      final healthy = service.computeChurnRiskScore(
        daysSinceLastOrder: 2,
        expectedCadenceDays: 3.0,
        volumeTrendRatio: 1.0,
      );
      expect(healthy.riskTier, equals('LOW'));
      expect(healthy.churnProbability, equals(0.0));

      // At-risk customer: 12 days since order with 3-day cadence (4x gap), volume down to 40%
      final atRisk = service.computeChurnRiskScore(
        daysSinceLastOrder: 12,
        expectedCadenceDays: 3.0,
        volumeTrendRatio: 0.4,
      );
      expect(atRisk.riskTier, equals('CRITICAL'));
      expect(atRisk.churnProbability, greaterThanOrEqualTo(0.75));
      expect(atRisk.recommendation, contains('Key Account Manager'));
    });

    test('KPI 6: Machine Vibration RUL Hours predicts equipment wear under ISO 10816-3', () {
      final rul = service.computeMachineRul(
        baselineVibrationMmS: 1.5,
        currentVibrationMmS: 3.5, // degraded to Acceptable
        maxAllowedMmS: 7.1,
        operatingHoursRun: 2000.0,
      );

      // wearRate = (3.5 - 1.5) / 2000 = 0.001 mm/s per hour
      // remaining = 7.1 - 3.5 = 3.6 mm/s -> RUL = 3.6 / 0.001 = 3600.0 hours
      expect(rul.remainingUsefulLifeHours, equals(3600.0));
      expect(rul.healthGrade, equals('ACCEPTABLE'));
    });

    test('KPI 7: Scrap / Wastage Rate per 1,000 packs measures manufacturing yield', () {
      final scrap = service.computeScrapRate(
        totalUnitsProduced: 50000,
        scrappedUnits: 450,
      );

      // (450 / 50000) * 1000 = 9.0 per thousand (0.9% scrap rate)
      expect(scrap.scrapRatePerThousand, equals(9.0));
      expect(scrap.yieldPercentage, equals(99.1));
    });

    test('KPI 8: Cold-Chain Thermal Degree-Hours assesses continuous HACCP CCP compliance', () {
      final now = DateTime.now();
      // Safe logs at -19°C for 24h
      final safeLogs = [
        TemperatureLogPoint(timestamp: now, temperatureCelsius: -19.5, durationHours: 12.0),
        TemperatureLogPoint(timestamp: now.add(const Duration(hours: 12)), temperatureCelsius: -18.2, durationHours: 12.0),
      ];
      final safeMetric = service.computeThermalBreachDegreeHours(
        logs: safeLogs,
        upperLimitCelsius: -18.0,
      );
      expect(safeMetric.totalDegreeHours, equals(0.0));
      expect(safeMetric.isHaccpCompliant, isTrue);

      // Thermal excursion: -15°C for 3 hours (3°C above limit * 3 hours = 9 degree-hours)
      final breachLogs = [
        TemperatureLogPoint(timestamp: now, temperatureCelsius: -15.0, durationHours: 3.0),
      ];
      final breachMetric = service.computeThermalBreachDegreeHours(
        logs: breachLogs,
        upperLimitCelsius: -18.0,
      );
      expect(breachMetric.totalDegreeHours, equals(9.0));
      expect(breachMetric.isHaccpCompliant, isFalse);
      expect(breachMetric.status, contains('VIOLATION'));
    });

    test('KPI 9: Multi-Currency Landed Cost & Tariff Margin verifies export profitability', () {
      final exportMargin = service.computeLandedCostMargin(
        sellingPriceForeign: 12.50, // AED 12.50 per pack
        fxRate: 22.80, // INR per AED -> Realized: 285.00 INR
        fobCostInr: 120.00,
        freightInr: 25.00,
        dutyInr: 15.00,
        portHandlingInr: 5.00, // Total landed cost: 165.00 INR
      );

      expect(exportMargin.realizedRevenueInr, equals(285.0));
      expect(exportMargin.totalLandedCostInr, equals(165.0));
      expect(exportMargin.grossProfitInr, equals(120.0));
      // (120 / 285) * 100 = 42.11%
      expect(exportMargin.netExportMarginPercentage, equals(42.11));
    });

    test('KPI 10: Standing Order Auto-Fulfillment tracks automated replenishment efficiency', () {
      final standing = service.computeStandingOrderFulfillment(
        totalScheduledOrders: 200,
        autoDispatchedOrders: 192,
        manualInterventions: 8,
      );

      expect(standing.autoFulfillmentRate, equals(96.0));
      expect(standing.manualInterventionRate, equals(4.0));
    });

    test('Executive Dashboard: Synthesizes all 10 KPIs into a unified Corporate Health Score', () {
      final now = DateTime.now();
      final report = service.generateExecutiveReport(
        deliveries: [
          DeliveryRecord(
            orderId: 'ORD-1',
            orderedQuantity: 100,
            deliveredQuantity: 100,
            scheduledDeliveryTime: now,
            actualDeliveryTime: now.subtract(const Duration(minutes: 5)),
          ),
        ],
        accountsReceivable: 100000.0,
        periodGrossRevenue: 1200000.0,
        periodDays: 90,
        overdueReceivables: 5000.0,
        totalRevenue: 500000.0,
        totalCogs: 320000.0,
        orderDates: [
          now.subtract(const Duration(days: 6)),
          now.subtract(const Duration(days: 3)),
          now,
        ],
        daysSinceLastOrder: 1,
        expectedCadenceDays: 3.0,
        volumeTrendRatio: 1.05,
        baselineVibMmS: 1.2,
        currentVibMmS: 2.1,
        maxAllowedVibMmS: 7.1,
        operatingHoursRun: 1500.0,
        totalUnitsProduced: 100000,
        scrappedUnits: 300,
        tempLogs: [
          TemperatureLogPoint(timestamp: now, temperatureCelsius: -19.0, durationHours: 24.0),
        ],
        tempLimitCelsius: -18.0,
        exportSellingForeign: 15.0,
        fxRate: 22.8,
        exportFobInr: 120.0,
        exportFreightInr: 30.0,
        exportDutyInr: 15.0,
        exportPortInr: 5.0,
        totalScheduledOrders: 150,
        autoDispatchedOrders: 147,
        manualInterventions: 3,
      );

      expect(report.otif.otifPercentage, equals(100.0));
      expect(report.dso.dsoDays, lessThan(10.0));
      expect(report.margin.grossMarginPercentage, equals(36.0));
      expect(report.churn.riskTier, equals('LOW'));
      expect(report.machineRul.healthGrade, equals('EXCELLENT'));
      expect(report.thermalBreach.isHaccpCompliant, isTrue);
      expect(report.standingOrders.autoFulfillmentRate, equals(98.0));
      expect(report.corporateHealthScore, greaterThanOrEqualTo(85.0));
    });
  });
}
