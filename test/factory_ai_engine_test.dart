import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/factory_ai_engine.dart';

void main() {
  group('Phase 10 — Advanced On-Device AI & Factory Automation Tests', () {
    test('Step 10.1: ISO 10816-3 Predictive Maintenance correctly classifies machine health & RUL', () {
      // 1. Normal Machine A
      final normalEval = FactoryAiEngine.instance.evaluateMachineHealth(
        machineId: 'MIXER-01',
        machineName: 'Industrial Spiral Dough Mixer (150kg)',
        vibrationMmS: 1.8,
        temperatureCelsius: 48.0,
        hoursRun: 450.0,
      );
      expect(normalEval.grade, MachineHealthGrade.good);
      expect(normalEval.estimatedRulHours, 550);
      expect(normalEval.maintenanceAction, contains('OPTIMAL'));

      // 2. Warning Machine B (Bearing Wear)
      final warningEval = FactoryAiEngine.instance.evaluateMachineHealth(
        machineId: 'PRESS-02',
        machineName: 'Automated 4-Lane Parota Press',
        vibrationMmS: 5.4,
        temperatureCelsius: 74.0,
        hoursRun: 820.0,
      );
      expect(warningEval.grade, MachineHealthGrade.warning);
      expect(warningEval.estimatedRulHours, lessThan(100));
      expect(warningEval.maintenanceAction, contains('IMMEDIATE SERVICE'));

      // 3. Critical Emergency Machine C
      final criticalEval = FactoryAiEngine.instance.evaluateMachineHealth(
        machineId: 'FREEZER-01',
        machineName: 'Bitzer Screw Compressor (Blast Tunnel)',
        vibrationMmS: 8.4,
        temperatureCelsius: 91.0,
        hoursRun: 950.0,
      );
      expect(criticalEval.grade, MachineHealthGrade.critical);
      expect(criticalEval.estimatedRulHours, 0);
      expect(criticalEval.maintenanceAction, contains('EMERGENCY SHUTDOWN'));
    });

    test('Step 10.2: Statistical 3-Sigma Wastage Anomaly Detector identifies scrap spikes', () {
      final normalLog = WastageLog(
        id: 1,
        stage: 'pressing',
        reason: 'edge_trim',
        wastageKg: 2.8,
        costEstimatedMinor: 2800,
        currencyCode: 'INR',
        createdAt: DateTime.now(),
      );

      final anomalyLog = WastageLog(
        id: 2,
        stage: 'pressing',
        reason: 'torn_dough',
        wastageKg: 14.5, // Far above mean 2.5 kg (z-score > 8.0)
        costEstimatedMinor: 14500,
        currencyCode: 'INR',
        createdAt: DateTime.now(),
      );

      final reports = FactoryAiEngine.instance.detectWastageAnomalies(
        logs: [normalLog, anomalyLog],
        baselineMeanKg: 2.5,
        baselineStdDevKg: 1.2,
      );

      expect(reports.length, 2);

      // Normal report
      expect(reports[0].isAnomaly, isFalse);
      expect(reports[0].zScore, lessThan(2.5));

      // Anomaly report
      expect(reports[1].isAnomaly, isTrue);
      expect(reports[1].zScore, greaterThan(8.0));
      expect(reports[1].rootCauseHypothesis, contains('Dough elasticity'));
      expect(reports[1].correctiveAction, contains('pneumatic pressure'));
    });

    test('Step 10.3: On-Device BM25 Okapi Search Engine ranks factory SOPs and formulations accurately', () {
      final sopCorpus = [
        {
          'id': 'SOP-001',
          'title': 'Classic Malabar Parotta Formulation and Dough Mixing',
          'content': 'Standard recipe calls for refined wheat maida, 2.2% iodized salt, refined vegetable oil, and 48% water hydration. Mix in spiral mixer for 12 minutes until dough temperature reaches 24C.',
        },
        {
          'id': 'SOP-002',
          'title': 'Tunnel Oven Temperature & Conveyor Troubleshooting',
          'content': 'Gas infrared tunnel oven burners must maintain 260C upper deck and 220C lower deck. If roti blisters unevenly, check conveyor speed calibration and infrared thermocouple alignment.',
        },
        {
          'id': 'SOP-003',
          'title': 'Blast Freezing & Cold Chain HACCP Standards for Export',
          'content': 'Parotas exit oven and enter blast freeze tunnel at -35C. Core product temperature must reach -18C within 28 minutes to minimize ice crystal size. Store in frozen reefer holding.',
        },
        {
          'id': 'SOP-004',
          'title': 'FSSAI Allergen Declaration and Gluten Labeling Rules',
          'content': 'Under FSSAI Labelling Regulations 2020, wheat gluten must be declared in bold capital letters: CONTAINS WHEAT GLUTEN. State veg logo on front of pack.',
        },
      ];

      // Query 1: Oven conveyor issue
      final ovenResults = FactoryAiEngine.instance.searchBm25(
        query: 'oven conveyor temperature thermocouple',
        corpus: sopCorpus,
      );

      expect(ovenResults, isNotEmpty);
      expect(ovenResults.first.documentId, 'SOP-002');
      expect(ovenResults.first.title, contains('Tunnel Oven'));

      // Query 2: Blast freezing export
      final freezerResults = FactoryAiEngine.instance.searchBm25(
        query: 'blast freezing reefer cold chain export',
        corpus: sopCorpus,
      );

      expect(freezerResults, isNotEmpty);
      expect(freezerResults.first.documentId, 'SOP-003');
      expect(freezerResults.first.title, contains('Blast Freezing'));
    });
  });
}
