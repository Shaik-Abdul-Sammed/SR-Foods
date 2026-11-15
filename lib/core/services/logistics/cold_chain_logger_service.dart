import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class ColdChainBreachSummary {
  final int totalReadings;
  final int totalBreaches;
  final double maxTemperatureC;
  final double minTemperatureC;
  final double averageTemperatureC;
  final bool hasActiveBreach;

  const ColdChainBreachSummary({
    required this.totalReadings,
    required this.totalBreaches,
    required this.maxTemperatureC,
    required this.minTemperatureC,
    required this.averageTemperatureC,
    required this.hasActiveBreach,
  });
}

class ColdChainLoggerService {
  final AppDatabase db;

  ColdChainLoggerService(this.db);

  /// Records an individual telemetry reading, automatically evaluating cold-chain breach status.
  Future<int> recordReading({
    required String sensorId,
    String? vehicleNumber,
    String? batchNumber,
    required double temperatureC,
    double? humidityPercent,
    required DateTime recordedAt,
    double maxPermissibleTempC = 4.0, // Default 4°C for chilled milk/dairy
    String? notes,
  }) async {
    final isBreach = temperatureC > maxPermissibleTempC;

    return db.into(db.coldChainReadings).insert(
          ColdChainReadingsCompanion.insert(
            sensorId: sensorId,
            vehicleNumber: Value(vehicleNumber),
            batchNumber: Value(batchNumber),
            temperatureC: temperatureC,
            humidityPercent: Value(humidityPercent),
            recordedAt: recordedAt,
            isBreach: Value(isBreach),
            notes: Value(notes),
          ),
        );
  }

  /// Ingests IoT logger data in CSV format:
  /// sensorId,vehicleNumber,batchNumber,temperatureC,humidityPercent,isoTimestamp
  Future<int> importCsv(String csvData, {double maxPermissibleTempC = 4.0}) async {
    final lines = csvData.trim().split('\n');
    if (lines.isEmpty) return 0;

    int insertedCount = 0;
    // Skip header line if present
    final startIndex = lines.first.toLowerCase().contains('sensor') ? 1 : 0;

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 6) {
        final sensorId = parts[0].trim();
        final vehicleNumber = parts[1].trim();
        final batchNumber = parts[2].trim();
        final temp = double.tryParse(parts[3].trim()) ?? 0.0;
        final humidity = double.tryParse(parts[4].trim());
        final recordedAt = DateTime.tryParse(parts[5].trim()) ?? DateTime.now();

        await recordReading(
          sensorId: sensorId,
          vehicleNumber: vehicleNumber,
          batchNumber: batchNumber,
          temperatureC: temp,
          humidityPercent: humidity,
          recordedAt: recordedAt,
          maxPermissibleTempC: maxPermissibleTempC,
        );
        insertedCount++;
      }
    }

    return insertedCount;
  }

  /// Analyzes telemetry logs for a vehicle/sensor and returns breach metrics.
  Future<ColdChainBreachSummary> getTelemetrySummary({String? vehicleNumber, String? sensorId}) async {
    final query = db.select(db.coldChainReadings);
    if (vehicleNumber != null) {
      query.where((tbl) => tbl.vehicleNumber.equals(vehicleNumber));
    }
    if (sensorId != null) {
      query.where((tbl) => tbl.sensorId.equals(sensorId));
    }

    final readings = await query.get();
    if (readings.isEmpty) {
      return const ColdChainBreachSummary(
        totalReadings: 0,
        totalBreaches: 0,
        maxTemperatureC: 0.0,
        minTemperatureC: 0.0,
        averageTemperatureC: 0.0,
        hasActiveBreach: false,
      );
    }

    int breaches = 0;
    double maxT = readings.first.temperatureC;
    double minT = readings.first.temperatureC;
    double sumT = 0.0;

    for (final r in readings) {
      if (r.isBreach) breaches++;
      if (r.temperatureC > maxT) maxT = r.temperatureC;
      if (r.temperatureC < minT) minT = r.temperatureC;
      sumT += r.temperatureC;
    }

    return ColdChainBreachSummary(
      totalReadings: readings.length,
      totalBreaches: breaches,
      maxTemperatureC: (maxT * 10.0).round() / 10.0,
      minTemperatureC: (minT * 10.0).round() / 10.0,
      averageTemperatureC: ((sumT / readings.length) * 10.0).round() / 10.0,
      hasActiveBreach: readings.last.isBreach,
    );
  }
}
