import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/logistics/cold_chain_logger_service.dart';

void main() {
  late AppDatabase db;
  late ColdChainLoggerService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ColdChainLoggerService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ColdChainLoggerService Tests', () {
    test('1. Records telemetry reading and automatically detects temperature breach', () async {
      final now = DateTime.now();

      // Safe reading (3.2°C <= 4.0°C)
      final safeId = await service.recordReading(
        sensorId: 'SENSOR-01',
        vehicleNumber: 'TS09-VAN-1',
        temperatureC: 3.2,
        recordedAt: now,
      );
      expect(safeId, greaterThan(0));

      // Breach reading (6.5°C > 4.0°C)
      final breachId = await service.recordReading(
        sensorId: 'SENSOR-01',
        vehicleNumber: 'TS09-VAN-1',
        temperatureC: 6.5,
        recordedAt: now.add(const Duration(minutes: 15)),
      );
      expect(breachId, greaterThan(0));

      final summary = await service.getTelemetrySummary(vehicleNumber: 'TS09-VAN-1');
      expect(summary.totalReadings, 2);
      expect(summary.totalBreaches, 1);
      expect(summary.maxTemperatureC, 6.5);
      expect(summary.minTemperatureC, 3.2);
      expect(summary.hasActiveBreach, isTrue);
    });

    test('2. Ingests CSV telemetry data format accurately', () async {
      const csv = '''sensorId,vehicleNumber,batchNumber,temperatureC,humidityPercent,isoTimestamp
SENSOR-A,TS09-101,B-1,2.5,75.0,2026-11-15T08:00:00Z
SENSOR-A,TS09-101,B-1,3.0,74.0,2026-11-15T08:15:00Z
SENSOR-A,TS09-101,B-1,5.2,78.0,2026-11-15T08:30:00Z''';

      final count = await service.importCsv(csv, maxPermissibleTempC: 4.0);
      expect(count, 3);

      final summary = await service.getTelemetrySummary(sensorId: 'SENSOR-A');
      expect(summary.totalReadings, 3);
      expect(summary.totalBreaches, 1); // 5.2°C is a breach
    });

    test('3. Empty telemetry summary returns zeroed metrics', () async {
      final summary = await service.getTelemetrySummary(vehicleNumber: 'NON_EXISTENT');
      expect(summary.totalReadings, 0);
      expect(summary.totalBreaches, 0);
      expect(summary.hasActiveBreach, isFalse);
    });
  });
}
