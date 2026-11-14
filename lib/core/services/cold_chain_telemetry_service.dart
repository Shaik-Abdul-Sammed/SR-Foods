enum ColdChainStorageClass {
  ambient('Ambient Storage', 22.0, 15.0, 28.0),
  chilled('Chilled Fresh Holding', 3.0, 0.0, 4.0),
  frozen('Deep Blast Frozen Reefer', -18.0, -25.0, -12.0);

  final String label;
  final double targetCelsius;
  final double minAcceptableCelsius;
  final double maxAcceptableCelsius;
  const ColdChainStorageClass(this.label, this.targetCelsius, this.minAcceptableCelsius, this.maxAcceptableCelsius);
}

enum ColdChainIntegrityStatus {
  optimal('Optimal Cold Chain Integrity', 0xFF2E7D32),
  acceptable('Acceptable Operational Tolerance', 0xFF1565C0),
  warning('Thermal Variance Warning', 0xFFF57F17),
  criticalBreach('CRITICAL CCP BREACH - QUARANTINE', 0xFFC62828);

  final String label;
  final int colorValue;
  const ColdChainIntegrityStatus(this.label, this.colorValue);
}

class TelemetryReading {
  final DateTime timestamp;
  final double temperatureCelsius;
  final double? humidityPercentage;

  const TelemetryReading({
    required this.timestamp,
    required this.temperatureCelsius,
    this.humidityPercentage,
  });
}

class ColdChainAuditReport {
  final ColdChainStorageClass storageClass;
  final double meanTemperature;
  final double minTemperature;
  final double maxTemperature;
  final double thermalDegreeHoursBreach;
  final int breachReadingsCount;
  final ColdChainIntegrityStatus status;
  final String safetyAssessment;

  const ColdChainAuditReport({
    required this.storageClass,
    required this.meanTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    required this.thermalDegreeHoursBreach,
    required this.breachReadingsCount,
    required this.status,
    required this.safetyAssessment,
  });
}

class ColdChainTelemetryService {
  ColdChainTelemetryService._();
  static final ColdChainTelemetryService instance = ColdChainTelemetryService._();

  ColdChainAuditReport auditColdChain({
    required ColdChainStorageClass storageClass,
    required List<TelemetryReading> readings,
    double intervalHours = 0.5, // 30-min log interval default
  }) {
    if (readings.isEmpty) {
      return ColdChainAuditReport(
        storageClass: storageClass,
        meanTemperature: storageClass.targetCelsius,
        minTemperature: storageClass.targetCelsius,
        maxTemperature: storageClass.targetCelsius,
        thermalDegreeHoursBreach: 0.0,
        breachReadingsCount: 0,
        status: ColdChainIntegrityStatus.optimal,
        safetyAssessment: 'No telemetry data recorded. Operating at nominal baseline.',
      );
    }

    double sumTemp = 0.0;
    double minTemp = readings.first.temperatureCelsius;
    double maxTemp = readings.first.temperatureCelsius;
    double degreeHoursBreach = 0.0;
    int breachCount = 0;

    for (final r in readings) {
      final t = r.temperatureCelsius;
      sumTemp += t;
      if (t < minTemp) minTemp = t;
      if (t > maxTemp) maxTemp = t;

      if (t > storageClass.maxAcceptableCelsius) {
        breachCount++;
        final excess = t - storageClass.maxAcceptableCelsius;
        degreeHoursBreach += (excess * intervalHours);
      }
    }

    final meanTemp = sumTemp / readings.length;

    ColdChainIntegrityStatus status;
    String assessment;

    if (degreeHoursBreach > 8.0 || maxTemp > (storageClass.maxAcceptableCelsius + 6.0)) {
      status = ColdChainIntegrityStatus.criticalBreach;
      assessment = 'DANGER: Critical CCP Thermal Breach (${degreeHoursBreach.toStringAsFixed(1)} °C-hours). Quality & microbiological compromise detected. Stock must be quarantined.';
    } else if (degreeHoursBreach > 2.0 || breachCount > 3) {
      status = ColdChainIntegrityStatus.warning;
      assessment = 'WARNING: Minor temperature excursion detected. Reefer unit requires servicing. Stock safe for immediate dispatch only.';
    } else if (breachCount > 0) {
      status = ColdChainIntegrityStatus.acceptable;
      assessment = 'Operational fluctuation within allowable buffer. No textural damage.';
    } else {
      status = ColdChainIntegrityStatus.optimal;
      assessment = 'Continuous cold-chain compliance verified under HACCP CCP 1.';
    }

    return ColdChainAuditReport(
      storageClass: storageClass,
      meanTemperature: double.parse(meanTemp.toStringAsFixed(1)),
      minTemperature: double.parse(minTemp.toStringAsFixed(1)),
      maxTemperature: double.parse(maxTemp.toStringAsFixed(1)),
      thermalDegreeHoursBreach: double.parse(degreeHoursBreach.toStringAsFixed(2)),
      breachReadingsCount: breachCount,
      status: status,
      safetyAssessment: assessment,
    );
  }
}
