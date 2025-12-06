import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../services/dataset_service.dart';
import 'data_point.dart';
import 'fitting.dart';

class GraphController {
  final _datasetService = DatasetService();
  final List<DataPoint> _points = [];
  String? currentDatasetName;

  double? target;
  double? lowIntercept;
  double? medIntercept;
  double? highIntercept;

  // Fitted line and confidence band
  List<FlSpot> _medianLine = [];
  List<FlSpot> _lowerBand = [];
  List<FlSpot> _upperBand = [];

  List<DataPoint> get points => List.unmodifiable(_points);
  List<FlSpot> get medianLine => List.unmodifiable(_medianLine);
  List<FlSpot> get lowerBand => List.unmodifiable(_lowerBand);
  List<FlSpot> get upperBand => List.unmodifiable(_upperBand);

  List<FlSpot> get valueSpots {
    if (points.isEmpty) return [];
    final spots = points.map((p) {
      return FlSpot(
        p.timestamp.millisecondsSinceEpoch.toDouble() / 1000.0,
        p.value,
      );
    }).toList();
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  void addPoint(double value, {DateTime? timestamp}) {
    _points.add(
      DataPoint(
        value: value,
        timestamp: timestamp == null ? DateTime.now() : timestamp,
      ),
    );
  }

  void deletePoint(DataPoint point) {
    _points.remove(point);
  }

  Future<void> updateFit() async {
    if (points.length < 2) {
      _medianLine = [];
      _lowerBand = [];
      _upperBand = [];
      return;
    }

    final xs = points
        .map((p) => p.timestamp.millisecondsSinceEpoch.toDouble() / 1000.0)
        .toList();
    final ys = points.map((p) => p.value).toList();

    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final rangeX = maxX - minX;
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final rangeY = maxY - minY;
    final meanY = (maxY + minY) / 2;
    final meanX = (maxX + minX) / 2;

    final x_norm = xs.map((x) => (x - meanX) / rangeX).toList();
    final y_norm = ys.map((y) => (y - meanY) / rangeY).toList();

    // Initial fit using deterministic method
    //final initialFit = fitABC(x_norm, y_norm);

    // Run MCMC
    // final samples = runMCMC(x_norm, y_norm, a0: 0, b0: 1, c0: 0, steps: 50000);
    final initialWalkers = List<List<double>>.generate(12, (i) {
      final rnd = Rand(i + 123);
      return [
        0.0 + 0.2 * rnd.nextGaussian(), // a
        1.0 + 0.5 * rnd.nextGaussian(), // b
        0.0 + 1.0 * rnd.nextGaussian(), // c
        math.max(0.005, 0.05 + 0.05 * rnd.nextGaussian()), // sigma
      ];
    });
    final samples = ensembleSampler(
      x_norm,
      y_norm,
      initialWalkers: initialWalkers,
      steps: 8000,
      thin: 5,
      burnin: 1000,
    );

    const int curvePoints = 100;
    _medianLine = [];
    _lowerBand = [];
    _upperBand = [];

    // Find the intercept with target (if target is not null...)
    // y = a - b^2/c (1-exp(c/b*x))) => x = ln[1+(y-a) * c / b^2] * b / c
    double targetIntercept(FitResult s) {
      double t = (target! - meanY) / rangeY;

      if ((1 + (t - s.a) * s.c / (s.b * s.b)) <= 0) {
        return -(s.c / s.b).sign * double.infinity;
      }

      double xInterceptNorm =
          math.log(1 + (t - s.a) * s.c / (s.b * s.b)) * s.b / s.c;

      return xInterceptNorm * rangeX + meanX;
    }

    double plotWindowMinX = minX - 0.1 * rangeX;
    double plotWindowMaxX = maxX + 0.1 * rangeX;

    if (target != null) {
      List<double> tIntercepts = samples.map(targetIntercept).toList()..sort();
      final lowerIndex = (tIntercepts.length * 0.025).floor();
      final upperIndex = (tIntercepts.length * 0.975).floor();
      final medianIndex = tIntercepts.length ~/ 2;

      lowIntercept = tIntercepts[lowerIndex];
      medIntercept = tIntercepts[medianIndex];
      highIntercept = tIntercepts[upperIndex];

      plotWindowMinX = [
        lowIntercept!,
        medIntercept!,
        highIntercept!,
        minX - 0.1 * rangeX,
      ].where((v) => v != -double.infinity).reduce(math.min);

      plotWindowMaxX = [
        lowIntercept!,
        medIntercept!,
        highIntercept!,
        maxX + 0.1 * rangeX,
      ].where((v) => v != double.infinity).reduce(math.max);
    }
    print(lowIntercept);
    print(medIntercept);
    print(highIntercept);
    print(minX);
    print(maxX);
    print(plotWindowMinX);
    print(plotWindowMaxX);

    for (int i = 0; i < curvePoints; i++) {
      final t =
          plotWindowMinX +
          (plotWindowMaxX - plotWindowMinX) * i / (curvePoints - 1);
      final tNorm = (t - meanX) / rangeX;

      // compute y-values for each MCMC sample
      List<double> ySamples =
          samples.map((s) => model(tNorm, s.a, s.b, s.c)).toList()..sort();
      //List<double> ySamples = samples.map((s) => model(tNorm, initialFit.a, initialFit.b, initialFit.c, initialFit.d)).toList()
      //..sort();

      final lowerIndex = (ySamples.length * 0.025).floor();
      final upperIndex = (ySamples.length * 0.975).floor();
      final medianIndex = ySamples.length ~/ 2;

      _lowerBand.add(FlSpot(t, meanY + rangeY * ySamples[lowerIndex]));
      _upperBand.add(FlSpot(t, meanY + rangeY * ySamples[upperIndex]));
      _medianLine.add(FlSpot(t, meanY + rangeY * ySamples[medianIndex]));
    }
  }

  Future<void> saveCurrentDataset() async {
    if (currentDatasetName == null) return;
    await _datasetService.saveDataset(currentDatasetName!, _points);
  }

  Future<void> loadDataset(String name) async {
    currentDatasetName = name;
    final loaded = await _datasetService.loadDataset(name);

    _points
      ..clear()
      ..addAll(loaded);
  }
}
