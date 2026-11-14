import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/fefo_allocation_service.dart';
import 'package:sr_foods/core/services/cold_chain_telemetry_service.dart';

void main() {
  group('Phase 7 — Warehouse, Cold Chain, FEFO & QC Tests', () {
    final now = DateTime(2026, 11, 14);

    test('Step 7.1: FEFO picking allocation prioritizes earlier expiring batch first', () {
      final lotExpiringIn3Days = InventoryLot(
        lotNumber: 'LOT-2026-CH-01',
        sku: 'SRF-BRD-001',
        availableQuantity: 40,
        mfgDate: now.subtract(const Duration(days: 4)),
        expiryDate: now.add(const Duration(days: 3)), // Expires in 3 days
        binLocation: 'ZONE-CHILLED-B1',
      );

      final lotExpiringIn7Days = InventoryLot(
        lotNumber: 'LOT-2026-CH-02',
        sku: 'SRF-BRD-001',
        availableQuantity: 100,
        mfgDate: now.subtract(const Duration(days: 1)),
        expiryDate: now.add(const Duration(days: 7)), // Expires in 7 days
        binLocation: 'ZONE-CHILLED-B2',
      );

      // Customer orders 60 packs of SRF-BRD-001
      // FEFO must allocate 40 packs from LOT-2026-CH-01 (expires first),
      // and remaining 20 packs from LOT-2026-CH-02.
      final result = FefoAllocationService.instance.allocateFefo(
        sku: 'SRF-BRD-001',
        requiredQuantity: 60,
        availableLots: [lotExpiringIn7Days, lotExpiringIn3Days], // Provided in random order
        referenceDate: now,
      );

      expect(result.isFullyAllocated, isTrue);
      expect(result.totalAllocatedQuantity, 60);
      expect(result.allocations.length, 2);

      // Verify First-Expired was picked first
      expect(result.allocations[0].lotNumber, 'LOT-2026-CH-01');
      expect(result.allocations[0].allocatedQuantity, 40);

      // Verify Second lot covers remainder
      expect(result.allocations[1].lotNumber, 'LOT-2026-CH-02');
      expect(result.allocations[1].allocatedQuantity, 20);
    });

    test('Step 7.2: FEFO rejects expired and near-expiry lots (< 2 days threshold)', () {
      final expiredLot = InventoryLot(
        lotNumber: 'LOT-EXP-99',
        sku: 'SRF-BRD-001',
        availableQuantity: 50,
        mfgDate: now.subtract(const Duration(days: 10)),
        expiryDate: now.add(const Duration(days: 1)), // Less than 2 days threshold
        binLocation: 'ZONE-DISCARD',
      );

      final freshLot = InventoryLot(
        lotNumber: 'LOT-FRESH-01',
        sku: 'SRF-BRD-001',
        availableQuantity: 50,
        mfgDate: now,
        expiryDate: now.add(const Duration(days: 6)),
        binLocation: 'ZONE-CHILLED-A1',
      );

      final result = FefoAllocationService.instance.allocateFefo(
        sku: 'SRF-BRD-001',
        requiredQuantity: 40,
        availableLots: [expiredLot, freshLot],
        referenceDate: now,
        minimumShelfLifeDaysThreshold: 2,
      );

      expect(result.isFullyAllocated, isTrue);
      expect(result.allocations.length, 1);
      expect(result.allocations.first.lotNumber, 'LOT-FRESH-01');
      expect(result.rejectedExpiredLots.length, 1);
      expect(result.rejectedExpiredLots.first, contains('LOT-EXP-99'));
    });

    test('Step 7.3: Cold-Chain Telemetry evaluates normal optimal frozen Reefer profile', () {
      final optimalReadings = [
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 4)), temperatureCelsius: -18.2),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 3)), temperatureCelsius: -18.5),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 2)), temperatureCelsius: -17.9),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 1)), temperatureCelsius: -18.0),
      ];

      final report = ColdChainTelemetryService.instance.auditColdChain(
        storageClass: ColdChainStorageClass.frozen,
        readings: optimalReadings,
      );

      expect(report.status, ColdChainIntegrityStatus.optimal);
      expect(report.breachReadingsCount, 0);
      expect(report.thermalDegreeHoursBreach, 0.0);
      expect(report.meanTemperature, closeTo(-18.1, 0.2));
    });

    test('Step 7.4: Cold-Chain Telemetry triggers CRITICAL quarantine alert on reefer failure', () {
      // Reefer failure: temperature rises to -5°C for multiple hours (limit is -12°C max)
      final breachReadings = [
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 4)), temperatureCelsius: -15.0),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 3)), temperatureCelsius: -9.0), // breach (+3°C over -12)
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 2)), temperatureCelsius: -6.0), // breach (+6°C over -12)
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 1)), temperatureCelsius: -5.0), // breach (+7°C over -12)
      ];

      final report = ColdChainTelemetryService.instance.auditColdChain(
        storageClass: ColdChainStorageClass.frozen,
        readings: breachReadings,
        intervalHours: 1.0,
      );

      expect(report.status, ColdChainIntegrityStatus.criticalBreach);
      expect(report.breachReadingsCount, 3);
      expect(report.thermalDegreeHoursBreach, greaterThan(8.0));
      expect(report.safetyAssessment.toLowerCase(), contains('quarantine'));
    });
  });
}
