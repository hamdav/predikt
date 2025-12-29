import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../services/dataset_service.dart';
import 'data.dart';
import 'fitting.dart';

class GraphController {
  final _datasetService = DatasetService();
  final List<DataPoint> _points = [];
  String? currentDatasetName;

  double? target;
  FitFunction fitFunc = FitFunction.exponential;
  PredictedCurves? _preds;

  List<DataPoint> get points => List.unmodifiable(_points);
  List<FlSpot> get medianLine {
    if (_preds == null) return [];
    final n = _preds!.medianLine.length;

    return List<FlSpot>.generate(
      n,
      (i) => FlSpot(_preds!.ts[i], _preds!.medianLine[i]),
      growable: false,
    );
  }

  List<FlSpot> get lowerBand {
    if (_preds == null) return [];
    final n = _preds!.lowerBand.length;

    return List<FlSpot>.generate(
      n,
      (i) => FlSpot(_preds!.ts[i], _preds!.lowerBand[i]),
      growable: false,
    );
  }

  List<FlSpot> get upperBand {
    if (_preds == null) return [];
    final n = _preds!.ts.length;

    return List<FlSpot>.generate(
      n,
      (i) => FlSpot(_preds!.ts[i], _preds!.upperBand[i]),
      growable: false,
    );
  }

  List<FlSpot> get valueSpots {
    if (points.isEmpty) return [];
    final spots = points.map((p) {
      return FlSpot(
        p.timestamp.millisecondsSinceEpoch.toDouble() / 1000.0,
        p.value,
      );
    }).toList();
    //spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  double? get lowIntercept => _preds?.lowIntercept;
  double? get medIntercept => _preds?.medIntercept;
  double? get highIntercept => _preds?.highIntercept;

  void addPoint(double value, {DateTime? timestamp}) {
    DateTime t = timestamp ?? DateTime.now();
    int idx = _points.indexWhere(
      (p) => p.timestamp.millisecondsSinceEpoch > t.millisecondsSinceEpoch,
    );
    if (idx == -1) {
      idx = _points.length;
    }
    _points.insert(
      idx,
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
      _preds = null;
      return;
    }

    final xs = points
        .map((p) => p.timestamp.millisecondsSinceEpoch.toDouble() / 1000.0)
        .toList();
    final ys = points.map((p) => p.value).toList();

    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final medX = xs[xs.length ~/ 2];
    final meanX = xs.reduce((a, b) => a + b) / xs.length;

    double rangeX = maxX - minX;
    if (rangeX == 0) {
      rangeX = 1;
    }
    double stdX = math.sqrt(
      xs.map((x) => (x - meanX) * (x - meanX)).fold(0.0, (a, b) => a + b) /
          xs.length,
    );
    if (stdX == 0) {
      stdX = 1;
    }
    rangeX = stdX;
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final medY = ys[ys.length ~/ 2];
    final meanY = ys.reduce((a, b) => a + b) / ys.length;
    double rangeY = maxY - minY;
    if (rangeY == 0) {
      rangeY = 1;
    }
    double stdY = math.sqrt(
      ys.map((y) => (y - meanY) * (y - meanY)).fold(0.0, (a, b) => a + b) /
          ys.length,
    );
    if (stdY == 0) {
      stdY = 1;
    }
    rangeY = stdY;

    final xNorm = xs.map((x) => (x - meanX) / rangeX).toList();
    final yNorm = ys.map((y) => (y - meanY) / rangeY).toList();

    // Initial fit using deterministic method
    //final initialFit = fitABC(x_norm, y_norm);

    // Run MCMC
    // final samples = runMCMC(x_norm, y_norm, a0: 0, b0: 1, c0: 0, steps: 50000);
    List<List<double>> initialWalkers;
    switch (fitFunc) {
      case FitFunction.exponential:
        initialWalkers = List<List<double>>.generate(12, (i) {
          final rnd = Rand(i + 123);
          return [
            0.0 + 0.2 * rnd.nextGaussian(), // a
            1.0 + 0.5 * rnd.nextGaussian(), // b
            0.0 + 1.0 * rnd.nextGaussian(), // c
            math.max(0.005, 0.05 + 0.05 * rnd.nextGaussian()), // sigma
          ];
        });
      case FitFunction.linear:
        initialWalkers = List<List<double>>.generate(12, (i) {
          final rnd = Rand(i + 123);
          return [
            0.0 + 0.2 * rnd.nextGaussian(), // a
            1.0 + 0.5 * rnd.nextGaussian(), // b
            math.max(0.005, 0.05 + 0.05 * rnd.nextGaussian()), // sigma
          ];
        });
    }
    final samples = await compute(
      ensembleSampler,
      EnsembleSamplerParameters(
        xNorm,
        yNorm,
        initialWalkers,
        fitFunc,
        steps: 8000,
        thin: 5,
        burnin: 1000,
      ),
    );

    const int curvePoints = 100;
    _preds = await compute(
      predictCurves,
      PredictCurvesParameters(
        fitFunc,
        target,
        meanX,
        minX,
        maxX,
        rangeX,
        meanY,
        minY,
        maxY,
        rangeY,
        samples,
        curvePoints,
      ),
    );
  }

  Future<void> saveCurrentDataset() async {
    if (currentDatasetName == null) return;
    await _datasetService.saveDataset(
      currentDatasetName!,
      DataSet(fitFunc: fitFunc, points: _points, target: target),
    );
  }

  Future<void> loadDataset(String name) async {
    currentDatasetName = name;
    final loaded = await _datasetService.loadDataset(name);

    fitFunc = loaded.fitFunc;
    _points
      ..clear()
      ..addAll(loaded.points);
    target = loaded.target;
  }
}
