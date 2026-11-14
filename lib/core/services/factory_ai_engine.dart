import 'dart:math' as math;
import '../database/app_database.dart';

/// ISO 10816-3 Vibration Severity Classification for industrial food machinery
enum MachineHealthGrade {
  good('Class A: Good (Smooth operation)', 0xFF2E7D32),
  acceptable('Class B: Acceptable (Unrestricted long-term operation)', 0xFF1565C0),
  warning('Class C: Warning (Restricted operation, bearing wear detected)', 0xFFF57F17),
  critical('Class D: Critical (Danger of catastrophic failure - STOP)', 0xFFC62828);

  final String description;
  final int colorValue;
  const MachineHealthGrade(this.description, this.colorValue);
}

/// Predictive maintenance diagnostic evaluation
class MachineHealthEvaluation {
  final String machineId;
  final String machineName;
  final double currentVibrationMmS;
  final double temperatureCelsius;
  final double hoursRun;
  final MachineHealthGrade grade;
  final int estimatedRulHours; // Remaining Useful Life
  final String maintenanceAction;

  const MachineHealthEvaluation({
    required this.machineId,
    required this.machineName,
    required this.currentVibrationMmS,
    required this.temperatureCelsius,
    required this.hoursRun,
    required this.grade,
    required this.estimatedRulHours,
    required this.maintenanceAction,
  });
}

/// Wastage anomaly report
class WastageAnomalyReport {
  final int logId;
  final String stage;
  final String reason;
  final double wastageKg;
  final double zScore;
  final bool isAnomaly;
  final String rootCauseHypothesis;
  final String correctiveAction;

  const WastageAnomalyReport({
    required this.logId,
    required this.stage,
    required this.reason,
    required this.wastageKg,
    required this.zScore,
    required this.isAnomaly,
    required this.rootCauseHypothesis,
    required this.correctiveAction,
  });
}

/// Search match result from on-device BM25 engine
class Bm25SearchResult {
  final String documentId;
  final String title;
  final String snippet;
  final double score;

  const Bm25SearchResult({
    required this.documentId,
    required this.title,
    required this.snippet,
    required this.score,
  });
}

/// Master On-Device AI Engine for Factory Automation & Diagnostics
class FactoryAiEngine {
  FactoryAiEngine._();
  static final FactoryAiEngine instance = FactoryAiEngine._();

  // --- 1. Predictive Maintenance Engine (ISO 10816-3) ---

  /// Evaluates vibration & temperature telemetry to predict machine failures before they happen
  MachineHealthEvaluation evaluateMachineHealth({
    required String machineId,
    required String machineName,
    required double vibrationMmS,
    required double temperatureCelsius,
    required double hoursRun,
    double serviceIntervalHours = 1000.0,
  }) {
    MachineHealthGrade grade;
    int rul;
    String action;

    // ISO 10816-3 vibration limits for Class II machines (15kW to 300kW medium industrial motors)
    if (vibrationMmS >= 7.1 || temperatureCelsius >= 85.0) {
      grade = MachineHealthGrade.critical;
      rul = 0;
      action = 'EMERGENCY SHUTDOWN REQUIRED: High vibration ($vibrationMmS mm/s) or overheat ($temperatureCelsius°C). Imminent bearing seizure.';
    } else if (vibrationMmS >= 4.5 || temperatureCelsius >= 72.0) {
      grade = MachineHealthGrade.warning;
      rul = math.max(12, ((1000.0 - (hoursRun % 1000.0)) * 0.25).round());
      action = 'SCHEDULE IMMEDIATE SERVICE: Bearing flaking / misalignment. Grease bearings and check belt tension within 24 hours.';
    } else if (vibrationMmS >= 2.8) {
      grade = MachineHealthGrade.acceptable;
      rul = math.max(100, ((1000.0 - (hoursRun % 1000.0)) * 0.75).round());
      action = 'NORMAL MONITORING: Machine operating within acceptable factory vibration margins.';
    } else {
      grade = MachineHealthGrade.good;
      rul = (1000.0 - (hoursRun % 1000.0)).round();
      action = 'OPTIMAL HEALTH: Smooth motor and gearbox harmonics.';
    }

    return MachineHealthEvaluation(
      machineId: machineId,
      machineName: machineName,
      currentVibrationMmS: vibrationMmS,
      temperatureCelsius: temperatureCelsius,
      hoursRun: hoursRun,
      grade: grade,
      estimatedRulHours: rul,
      maintenanceAction: action,
    );
  }

  // --- 2. Wastage & Scrap Anomaly Detection (Statistical 3-Sigma) ---

  /// Analyzes wastage logs to identify out-of-control scrap spikes (> 2.5 sigma)
  List<WastageAnomalyReport> detectWastageAnomalies({
    required List<WastageLog> logs,
    required double baselineMeanKg,
    required double baselineStdDevKg,
  }) {
    final reports = <WastageAnomalyReport>[];
    final stdDev = baselineStdDevKg <= 0 ? 1.0 : baselineStdDevKg;

    for (final log in logs) {
      final zScore = (log.wastageKg - baselineMeanKg) / stdDev;
      final isAnomaly = zScore >= 2.5;

      String hypothesis;
      String action;

      if (isAnomaly) {
        switch (log.stage.toLowerCase()) {
          case 'pressing':
            hypothesis = 'Dough elasticity variance or uneven heating across pressing plates.';
            action = 'Calibrate pneumatic pressure to 6.2 bar and verify top/bottom plate surface temperature uniformity.';
            break;
          case 'baking':
            hypothesis = 'Tunnel oven conveyor speed drift or burner flame instability.';
            action = 'Inspect infrared thermocouple sensor and slow conveyor speed by 5%.';
            break;
          case 'packing':
            hypothesis = 'Sealing jaw Teflon degradation causing torn pouches.';
            action = 'Replace Teflon heating strip and inspect vacuum sealer pressure.';
            break;
          default:
            hypothesis = 'Excessive batch trim waste detected at ${log.stage}.';
            action = 'Review recipe ingredient hydration ratio with master dough chef.';
        }
      } else {
        hypothesis = 'Standard operational scrap within 2.5-sigma control chart tolerance.';
        action = 'Routine monitoring.';
      }

      reports.add(WastageAnomalyReport(
        logId: log.id,
        stage: log.stage,
        reason: log.reason,
        wastageKg: log.wastageKg,
        zScore: double.parse(zScore.toStringAsFixed(2)),
        isAnomaly: isAnomaly,
        rootCauseHypothesis: hypothesis,
        correctiveAction: action,
      ));
    }

    return reports;
  }

  // --- 3. Pure On-Device BM25 Search Engine ---

  /// Searches an in-memory document corpus using the BM25 Okapi probabilistic ranking model
  List<Bm25SearchResult> searchBm25({
    required String query,
    required List<Map<String, String>> corpus, // [{id, title, content}]
    double k1 = 1.5,
    double b = 0.75,
    int topK = 5,
  }) {
    if (corpus.isEmpty || query.trim().isEmpty) return [];

    final queryTerms = _tokenize(query);
    if (queryTerms.isEmpty) return [];

    final n = corpus.length;
    double totalDocLength = 0;
    final docTokensMap = <String, List<String>>{};
    final dfMap = <String, int>{}; // Document frequency of terms

    for (final doc in corpus) {
      final docId = doc['id']!;
      final text = '${doc['title'] ?? ''} ${doc['content'] ?? ''}';
      final tokens = _tokenize(text);
      docTokensMap[docId] = tokens;
      totalDocLength += tokens.length;

      final uniqueTokens = tokens.toSet();
      for (final term in uniqueTokens) {
        dfMap[term] = (dfMap[term] ?? 0) + 1;
      }
    }

    final avgdl = totalDocLength / n;
    final scores = <String, double>{};

    for (final doc in corpus) {
      final docId = doc['id']!;
      final tokens = docTokensMap[docId]!;
      final d = tokens.length;

      // Term counts in this document
      final tfMap = <String, int>{};
      for (final token in tokens) {
        tfMap[token] = (tfMap[token] ?? 0) + 1;
      }

      double docScore = 0.0;
      for (final term in queryTerms) {
        if (!tfMap.containsKey(term)) continue;

        final tf = tfMap[term]!;
        final df = dfMap[term] ?? 0;

        // IDF calculation with smoothing
        final idf = math.log(1.0 + (n - df + 0.5) / (df + 0.5));

        // BM25 term weighting
        final numerator = tf * (k1 + 1.0);
        final denominator = tf + k1 * (1.0 - b + b * (d / avgdl));
        docScore += idf * (numerator / denominator);
      }

      if (docScore > 0) {
        scores[docId] = docScore;
      }
    }

    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final docLookup = {for (var d in corpus) d['id']!: d};

    return sorted.take(topK).map((e) {
      final d = docLookup[e.key]!;
      final content = d['content'] ?? '';
      final snippet = content.length > 120 ? '${content.substring(0, 120)}...' : content;
      return Bm25SearchResult(
        documentId: e.key,
        title: d['title'] ?? '',
        snippet: snippet,
        score: double.parse(e.value.toStringAsFixed(3)),
      );
    }).toList();
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();
  }
}
