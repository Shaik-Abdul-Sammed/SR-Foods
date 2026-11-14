import 'dart:math' as math;

class DemandFeatures {
  final int dayOfWeek; // 0=Mon, 6=Sun
  final bool isFestivalWindow; // India or destination festival
  final double rolling7dAvg;
  final double rolling28dAvg;
  final double temperatureDelta; // Departure from 25°C
  final bool distributorPromoFlag;

  const DemandFeatures({
    required this.dayOfWeek,
    required this.isFestivalWindow,
    required this.rolling7dAvg,
    required this.rolling28dAvg,
    this.temperatureDelta = 0.0,
    this.distributorPromoFlag = false,
  });

  List<double> toFeatureVector() {
    // 6 features: day_of_week, is_festival, rolling_7d, rolling_28d, temp_delta, promo
    return [
      dayOfWeek.toDouble(),
      isFestivalWindow ? 1.0 : 0.0,
      rolling7dAvg,
      rolling28dAvg,
      temperatureDelta,
      distributorPromoFlag ? 1.0 : 0.0,
    ];
  }
}

class GBDTNode {
  final int featureIndex;
  final double threshold;
  final double value; // Leaf value
  final GBDTNode? left;
  final GBDTNode? right;

  const GBDTNode({
    this.featureIndex = -1,
    this.threshold = 0.0,
    this.value = 0.0,
    this.left,
    this.right,
  });

  bool get isLeaf => left == null && right == null;

  double predict(List<double> x) {
    if (isLeaf) return value;
    if (x[featureIndex] <= threshold) {
      return left!.predict(x);
    } else {
      return right!.predict(x);
    }
  }
}

class GbdtDemandForecaster {
  final int nTrees;
  final int maxDepth;
  final double learningRate;
  double _basePrediction = 0.0;
  final List<GBDTNode> _trees = [];

  GbdtDemandForecaster({
    this.nTrees = 10,
    this.maxDepth = 4,
    this.learningRate = 0.1,
  });

  List<GBDTNode> get trees => List.unmodifiable(_trees);
  double get basePrediction => _basePrediction;

  /// Train the GBDT on historical observations (X: features, y: actual demanded packs)
  void train(List<List<double>> X, List<double> y) {
    if (X.isEmpty || y.isEmpty || X.length != y.length) {
      throw ArgumentError('X and y must be non-empty and have matching lengths');
    }

    _trees.clear();
    _basePrediction = y.reduce((a, b) => a + b) / y.length;

    // Current ensemble predictions
    final predictions = List<double>.filled(y.length, _basePrediction);

    for (var t = 0; t < nTrees; t++) {
      // Compute negative gradients (residuals for MSE loss)
      final residuals = List<double>.generate(y.length, (i) => y[i] - predictions[i]);

      // Fit regression tree to residuals
      final indices = List<int>.generate(y.length, (i) => i);
      final tree = _buildTree(X, residuals, indices, currentDepth: 0);
      _trees.add(tree);

      // Update predictions
      for (var i = 0; i < y.length; i++) {
        predictions[i] += learningRate * tree.predict(X[i]);
      }
    }
  }

  GBDTNode _buildTree(
    List<List<double>> X,
    List<double> residuals,
    List<int> sampleIndices, {
    required int currentDepth,
  }) {
    if (sampleIndices.isEmpty) return const GBDTNode(value: 0.0);

    // Leaf condition
    if (currentDepth >= maxDepth || sampleIndices.length <= 4) {
      final leafVal = sampleIndices.map((i) => residuals[i]).reduce((a, b) => a + b) / sampleIndices.length;
      return GBDTNode(value: leafVal);
    }

    final nFeatures = X.first.length;
    var bestFeature = -1;
    var bestThreshold = 0.0;
    var bestVarianceReduction = -1.0;
    List<int> bestLeft = [];
    List<int> bestRight = [];

    final currentVariance = _calculateVariance(residuals, sampleIndices);

    // Grid search for optimal split across features
    for (var f = 0; f < nFeatures; f++) {
      final values = sampleIndices.map((i) => X[i][f]).toSet().toList()..sort();
      if (values.length <= 1) continue;

      for (var s = 0; s < values.length - 1; s++) {
        final thresh = (values[s] + values[s + 1]) / 2.0;
        final leftIndices = <int>[];
        final rightIndices = <int>[];

        for (final idx in sampleIndices) {
          if (X[idx][f] <= thresh) {
            leftIndices.add(idx);
          } else {
            rightIndices.add(idx);
          }
        }

        if (leftIndices.isEmpty || rightIndices.isEmpty) continue;

        final varLeft = _calculateVariance(residuals, leftIndices);
        final varRight = _calculateVariance(residuals, rightIndices);
        final weightedVar = (leftIndices.length * varLeft + rightIndices.length * varRight) / sampleIndices.length;
        final varReduction = currentVariance - weightedVar;

        if (varReduction > bestVarianceReduction) {
          bestVarianceReduction = varReduction;
          bestFeature = f;
          bestThreshold = thresh;
          bestLeft = leftIndices;
          bestRight = rightIndices;
        }
      }
    }

    if (bestFeature == -1 || bestVarianceReduction <= 1e-6) {
      final leafVal = sampleIndices.map((i) => residuals[i]).reduce((a, b) => a + b) / sampleIndices.length;
      return GBDTNode(value: leafVal);
    }

    final leftNode = _buildTree(X, residuals, bestLeft, currentDepth: currentDepth + 1);
    final rightNode = _buildTree(X, residuals, bestRight, currentDepth: currentDepth + 1);

    return GBDTNode(
      featureIndex: bestFeature,
      threshold: bestThreshold,
      left: leftNode,
      right: rightNode,
    );
  }

  double _calculateVariance(List<double> values, List<int> indices) {
    if (indices.isEmpty) return 0.0;
    final mean = indices.map((i) => values[i]).reduce((a, b) => a + b) / indices.length;
    var sumSq = 0.0;
    for (final idx in indices) {
      final diff = values[idx] - mean;
      sumSq += diff * diff;
    }
    return sumSq / indices.length;
  }

  /// Predict demand for given feature vector. Ultra-fast (< 0.1ms).
  double predict(DemandFeatures features) {
    if (_trees.isEmpty) return _basePrediction;
    final x = features.toFeatureVector();
    var yPred = _basePrediction;
    for (final tree in _trees) {
      yPred += learningRate * tree.predict(x);
    }
    return math.max(0.0, yPred);
  }

  /// Check whether a given calendar date is within major domestic or international diaspora festival windows
  static bool isFestivalWindow(DateTime date) {
    final m = date.month;
    final d = date.day;

    // Pongal / Makar Sankranti (Jan 13 - 18)
    if (m == 1 && d >= 13 && d <= 18) return true;
    // Ramadan & Eid al-Fitr window (approx Mar 20 - Apr 15)
    if ((m == 3 && d >= 20) || (m == 4 && d <= 15)) return true;
    // Eid al-Adha / Bakrid (approx June 10 - June 20)
    if (m == 6 && d >= 10 && d <= 20) return true;
    // Dussehra / Navratri (Oct 10 - Oct 25)
    if (m == 10 && d >= 10 && d <= 25) return true;
    // Diwali / Deepavali peak (Oct 28 - Nov 12)
    if ((m == 10 && d >= 28) || (m == 11 && d <= 12)) return true;
    // US Thanksgiving & Black Friday export rush (Nov 20 - Nov 30)
    if (m == 11 && d >= 20 && d <= 30) return true;
    // Christmas & New Year international rush (Dec 18 - Jan 2)
    if ((m == 12 && d >= 18) || (m == 1 && d <= 2)) return true;

    return false;
  }
}
