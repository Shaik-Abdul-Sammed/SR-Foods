import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/gbdt_demand_forecaster.dart';

void main() {
  group('GbdtDemandForecaster Tests (Step 4.1)', () {
    test('Train 10-tree GBDT on 90-day production history and beat moving average on festival spikes by >= 15%', () {
      final rand = math.Random(42);

      // Generate 90 days of synthetic production and sales demand history
      // Normal demand: baseline 200 packs + weekend bump (+60 packs)
      // Festival window: demand jumps by 80% to ~360 packs
      final xTrain = <List<double>>[];
      final yTrain = <double>[];

      final xTestFestival = <List<double>>[];
      final yTestFestival = <double>[];
      final movingAvgTest = <double>[];

      var rolling7 = 200.0;
      var rolling28 = 200.0;

      for (var day = 0; day < 90; day++) {
        final dow = day % 7;
        final isFestival = (day >= 30 && day <= 37) || (day >= 70 && day <= 76);
        final base = 200.0 + (dow >= 5 ? 60.0 : 0.0);
        final festivalUplift = isFestival ? 160.0 : 0.0;
        final noise = (rand.nextDouble() - 0.5) * 20.0;
        final actualDemand = base + festivalUplift + noise;

        rolling7 = (rolling7 * 6 + actualDemand) / 7.0;
        rolling28 = (rolling28 * 27 + actualDemand) / 28.0;

        final features = DemandFeatures(
          dayOfWeek: dow,
          isFestivalWindow: isFestival,
          rolling7dAvg: rolling7,
          rolling28dAvg: rolling28,
          temperatureDelta: 0.5,
          distributorPromoFlag: isFestival,
        );

        xTrain.add(features.toFeatureVector());
        yTrain.add(actualDemand);
      }

      // Generate holdout test dataset focusing on upcoming festival spike
      for (var day = 0; day < 14; day++) {
        final dow = day % 7;
        final isFestival = day >= 3 && day <= 10;
        final base = 200.0 + (dow >= 5 ? 60.0 : 0.0);
        final festivalUplift = isFestival ? 160.0 : 0.0;
        final noise = (rand.nextDouble() - 0.5) * 15.0;
        final actualDemand = base + festivalUplift + noise;

        final lagMovingAvg = rolling7; // Moving average baseline lags sudden festival jumps!

        rolling7 = (rolling7 * 6 + actualDemand) / 7.0;
        rolling28 = (rolling28 * 27 + actualDemand) / 28.0;

        final features = DemandFeatures(
          dayOfWeek: dow,
          isFestivalWindow: isFestival,
          rolling7dAvg: lagMovingAvg,
          rolling28dAvg: rolling28,
          temperatureDelta: 0.2,
          distributorPromoFlag: isFestival,
        );

        if (isFestival) {
          xTestFestival.add(features.toFeatureVector());
          yTestFestival.add(actualDemand);
          movingAvgTest.add(lagMovingAvg);
        }
      }

      // Train GBDT
      final forecaster = GbdtDemandForecaster(nTrees: 10, maxDepth: 4, learningRate: 0.15);
      forecaster.train(xTrain, yTrain);

      expect(forecaster.trees.length, 10);

      // Measure inference latency (warmup 1 call)
      forecaster.predict(DemandFeatures(
        dayOfWeek: 1,
        isFestivalWindow: false,
        rolling7dAvg: 200,
        rolling28dAvg: 200,
        temperatureDelta: 0,
        distributorPromoFlag: false,
      ));

      final stopwatch = Stopwatch()..start();
      final predictions = <double>[];
      for (var i = 0; i < xTestFestival.length; i++) {
        final f = DemandFeatures(
          dayOfWeek: xTestFestival[i][0].toInt(),
          isFestivalWindow: xTestFestival[i][1] == 1.0,
          rolling7dAvg: xTestFestival[i][2],
          rolling28dAvg: xTestFestival[i][3],
          temperatureDelta: xTestFestival[i][4],
          distributorPromoFlag: xTestFestival[i][5] == 1.0,
        );
        predictions.add(forecaster.predict(f));
      }
      stopwatch.stop();

      // Assert ultra-fast on-device inference (< 50ms total for batch, avg < 5ms per inference)
      expect(stopwatch.elapsedMilliseconds, lessThan(50));

      // Calculate MSE of GBDT vs Moving Average Baseline on festival spikes
      var gbdtSe = 0.0;
      var maSe = 0.0;

      for (var i = 0; i < yTestFestival.length; i++) {
        final actual = yTestFestival[i];
        final gbdtPred = predictions[i];
        final maPred = movingAvgTest[i];

        gbdtSe += (actual - gbdtPred) * (actual - gbdtPred);
        maSe += (actual - maPred) * (actual - maPred);
      }

      final gbdtMse = gbdtSe / yTestFestival.length;
      final maMse = maSe / yTestFestival.length;

      final errorReductionPercent = ((maMse - gbdtMse) / maMse) * 100.0;

      // Moving average significantly lags behind sudden festival surges,
      // while GBDT with is_festival flag immediately adapts.
      expect(errorReductionPercent, greaterThanOrEqualTo(15.0),
          reason: 'GBDT must reduce festival spike prediction MSE by >= 15% vs moving average (Achieved: ${errorReductionPercent.toStringAsFixed(1)}%)');
    });

    test('Calendar festival window detector recognizes major trade dates', () {
      expect(GbdtDemandForecaster.isFestivalWindow(DateTime(2026, 1, 14)), isTrue); // Pongal
      expect(GbdtDemandForecaster.isFestivalWindow(DateTime(2026, 11, 25)), isTrue); // Thanksgiving / US Export
      expect(GbdtDemandForecaster.isFestivalWindow(DateTime(2026, 12, 25)), isTrue); // Christmas
      expect(GbdtDemandForecaster.isFestivalWindow(DateTime(2026, 8, 10)), isFalse); // Normal day
    });
  });
}
