import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/cold_chain_telemetry_service.dart';

void main() {
  group('Dairy Cold Chain Telemetry Tests', () {
    final service = ColdChainTelemetryService.instance;

    test('1. Chilled dairy storage holding at 2.5°C to 3.8°C maintains Optimal integrity', () {
      final now = DateTime.now();
      final readings = [
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 3)), temperatureCelsius: 2.8),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 2)), temperatureCelsius: 3.2),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 1)), temperatureCelsius: 3.5),
        TelemetryReading(timestamp: now, temperatureCelsius: 3.1),
      ];

      final report = service.auditColdChain(
        readings: readings,
        storageClass: ColdChainStorageClass.chilled,
      );

      expect(report.status, equals(ColdChainIntegrityStatus.optimal));
      expect(report.breachReadingsCount, equals(0));
      expect(report.thermalDegreeHoursBreach, equals(0.0));
      expect(report.safetyAssessment, contains('HACCP CCP 1'));
    });

    test('2. Raw milk temperature spike above 4.0°C flags warning or critical breach', () {
      final now = DateTime.now();
      final readings = [
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 4)), temperatureCelsius: 3.5),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 3)), temperatureCelsius: 6.8),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 2)), temperatureCelsius: 8.5),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 1)), temperatureCelsius: 7.2),
        TelemetryReading(timestamp: now, temperatureCelsius: 5.5),
      ];

      final report = service.auditColdChain(
        readings: readings,
        storageClass: ColdChainStorageClass.chilled,
      );

      expect(report.breachReadingsCount, greaterThan(0));
      expect(report.thermalDegreeHoursBreach, greaterThan(0.0));
      expect(
        report.status,
        isIn([ColdChainIntegrityStatus.warning, ColdChainIntegrityStatus.criticalBreach]),
      );
    });

    test('3. High temperature spike over 10°C triggers critical breach quarantine status', () {
      final now = DateTime.now();
      final readings = [
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 2)), temperatureCelsius: 3.0),
        TelemetryReading(timestamp: now.subtract(const Duration(hours: 1)), temperatureCelsius: 11.5), // > 4 + 6 = 10°C
        TelemetryReading(timestamp: now, temperatureCelsius: 3.5),
      ];

      final report = service.auditColdChain(
        readings: readings,
        storageClass: ColdChainStorageClass.chilled,
      );

      expect(report.status, equals(ColdChainIntegrityStatus.criticalBreach));
      expect(report.safetyAssessment, contains('quarantined'));
    });

    test('4. Empty readings safely handled with default nominal baseline', () {
      final report = service.auditColdChain(
        readings: const [],
        storageClass: ColdChainStorageClass.chilled,
      );

      expect(report.breachReadingsCount, equals(0));
      expect(report.thermalDegreeHoursBreach, equals(0.0));
      expect(report.status, equals(ColdChainIntegrityStatus.optimal));
      expect(report.safetyAssessment, contains('nominal baseline'));
    });
  });
}
