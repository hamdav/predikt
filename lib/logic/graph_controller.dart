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
    _points.add(DataPoint(
      value: value,
      timestamp: timestamp == null ? DateTime.now() : timestamp,
    ));
  }

  void deletePoint(DataPoint point){
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

    final x_norm = xs.map((x) => (x - minX) / rangeX).toList();
    final y_norm = ys.map((y) => (y - minY) / rangeY).toList();

    // Initial fit using deterministic method
    final initialFit = fitABC(x_norm, y_norm);

    // Run MCMC (stub function, replace with your own sampling)
    final samples = runMCMC(x_norm, y_norm,
        a0: initialFit.a, b0: initialFit.b, c0: initialFit.c, d0: initialFit.d, steps: 50000);

    const int curvePoints = 100;
    _medianLine = [];
    _lowerBand = [];
    _upperBand = [];

    // Find the intercept with target (if target is not null...)
    // y = a - b exp(c*(x-d)) => x = d + ln[-(y-a)/ b] / c iff -(y-a)/b > 0, otherwise, there is no solution.
    double targetIntercept(FitResult s) {
        double a = rangeY * s.a + minY;
        double b = rangeY * s.b;
        double c = s.c / rangeX;
        double d = rangeX * s.d + minX;

        if ((target! >= a && b >= 0) || (target! <= a && b <= 0)) {
            return - c.sign * double.infinity;
        }

        return d + math.log(-(target!-a)/b) / c;
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
            minX - 0.1*rangeX
        ].where((v) => v != -double.infinity).reduce(math.min);

        plotWindowMaxX = [
            lowIntercept!, 
            medIntercept!, 
            highIntercept!, 
            maxX + 0.1*rangeX
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
      final t = plotWindowMinX + (plotWindowMaxX - plotWindowMinX) * i / (curvePoints - 1);
      final tNorm = (t - minX) / rangeX;

      // compute y-values for each MCMC sample
      List<double> ySamples = samples.map((s) => model(tNorm, s.a, s.b, s.c, s.d)).toList()
        ..sort();
      //List<double> ySamples = samples.map((s) => model(tNorm, initialFit.a, initialFit.b, initialFit.c, initialFit.d)).toList()
         //..sort();

      final lowerIndex = (ySamples.length * 0.025).floor();
      final upperIndex = (ySamples.length * 0.975).floor();
      final medianIndex = ySamples.length ~/ 2;

      _lowerBand.add(FlSpot(t, minY + rangeY * ySamples[lowerIndex]));
      _upperBand.add(FlSpot(t, minY + rangeY * ySamples[upperIndex]));
      _medianLine.add(FlSpot(t, minY + rangeY * ySamples[medianIndex]));
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