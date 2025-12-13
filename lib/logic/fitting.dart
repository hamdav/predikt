import 'dart:math' as math;
import 'package:predikt/logic/data.dart';

class FitResult {
  final List<double> x;
  FitResult(this.x);
}

// Model: a * (1 - exp((t - b)*c))
double expModel(double t, List<double> x) {
  final a = x[0];
  final b = x[1];
  final c = x[2];
  if (b == 0) return a;
  if (c == 0) return a + b * t;
  return a - b * b / c * (1 - math.exp(c / b * t));
}

double linModel(double t, List<double> x) {
  final a = x[0];
  final b = x[1];
  return a * t + b;
}

// -------------------------------------------------------------
// Log-likelihood: Gaussian error model
// -------------------------------------------------------------
double expLogLikelihood(List<double> ts, List<double> ys, List<double> x) {
  final a = x[0];
  final b = x[1];
  final c = x[2];
  final s = x[3];
  double sum = 0;
  for (int i = 0; i < ts.length; i++) {
    final pred = expModel(ts[i], x);
    final err = ys[i] - pred;
    sum += -(0.5 * err * err) / (s * s) - 0.5 * math.log(2 * math.pi * s * s);
  }
  // Gammadistribution for variance with alpha=2, theta=0.1
  double prior =
      math.log(s * s) -
      s * s / 0.01 -
      a * a / 1000 -
      b * b / 1000 -
      c * c / 1000;
  return sum + prior;
}

double linLogLikelihood(List<double> ts, List<double> ys, List<double> x) {
  final a = x[0];
  final b = x[1];
  final s = x[2];
  double sum = 0;
  for (int i = 0; i < ts.length; i++) {
    final pred = linModel(ts[i], x);
    final err = ys[i] - pred;
    sum += -(0.5 * err * err) / (s * s) - 0.5 * math.log(2 * math.pi * s * s);
  }
  // Gammadistribution for variance with alpha=2, theta=0.1
  double prior = math.log(s * s) - s * s / 0.01 - a * a / 1000 - b * b / 1000;
  return sum + prior;
}

// TODO: WHAT IF Number of points is two or three?
// Nonlinear least-squares fit using gradient descent
// FitResult fitABC(List<double> t, List<double> y) {
//   double a = (y.reduce(math.max) - y.reduce(math.min));
//   double b = a - y.first; // initial guess
//   double c = 0;
//   double d = t.reduce(math.min);
//   double disableC = 1.0;
//   if (y.length == 2) {
//     c = -0.05 / (t.reduce(math.max) - t.reduce(math.min)); // growth timescale
//     disableC = 0.0;
//   }

//   double mA = 0, mB = 0, mC = 0, mD = 0;
//   double vA = 0, vB = 0, vC = 0, vD = 0;
//   double beta1 = 0.9;
//   double beta2 = 0.95;
//   double epsilon = 1e-7;
//   double err = 0;

//   double lrInitial = 5e-2; // learning rate
//   for (int iter = 0; iter < 8000; iter++) {
//     double lr = 80 * lrInitial / (iter + 80);
//     //double lr = lrInitial;
//     double da = 0, db = 0, dc = 0, dd = 0;
//     err = 0;

//     for (int i = 0; i < t.length; i++) {
//       double ti = t[i];
//       double yi = y[i];
//       double pred = 0;
//       //model(ti, a, b, c, d);

//       double e = pred - yi;
//       double E = math.exp(c * (ti - d));

//       da += 2 * e;
//       db += -2 * e * E;
//       dc += -2 * e * b * (E * (ti - d)) * disableC;
//       dd += 2 * e * b * (E * c);
//       err += e * e;
//     }

//     mA = (beta1 * mA + (1 - beta1) * da);
//     vA = (beta2 * vA + (1 - beta2) * da * da);
//     mB = (beta1 * mB + (1 - beta1) * db);
//     vB = (beta2 * vB + (1 - beta2) * db * db);
//     mC = (beta1 * mC + (1 - beta1) * dc);
//     vC = (beta2 * vC + (1 - beta2) * dc * dc);
//     mD = (beta1 * mD + (1 - beta1) * dd);
//     vD = (beta2 * vD + (1 - beta2) * dd * dd);

//     a -= lr * mA / math.sqrt(vA + epsilon);
//     b -= lr * mB / math.sqrt(vB + epsilon);
//     c -= lr * mC / math.sqrt(vC + epsilon);
//     d -= lr * mD / math.sqrt(vD + epsilon);
//     err = math.sqrt(err / t.length);
//     // if (iter % 100 == 0) {
//     //   print(
//     //     "a: " +
//     //         a.toStringAsPrecision(5) +
//     //         " b: " +
//     //         b.toStringAsPrecision(5) +
//     //         " c: " +
//     //         c.toStringAsPrecision(5) +
//     //         " d: " +
//     //         d.toStringAsPrecision(5) +
//     //         " err: " +
//     //         err.toStringAsPrecision(3),
//     //   );
//     //}
//   }

//   // print(
//   //   "a: " +
//   //       a.toStringAsPrecision(5) +
//   //       " b: " +
//   //       b.toStringAsPrecision(5) +
//   //       " c: " +
//   //       c.toStringAsPrecision(5) +
//   //       " d: " +
//   //       d.toStringAsPrecision(5) +
//   //       " err: " +
//   //       err.toStringAsPrecision(3),
//   // );

//   //return FitResult(a, b, c, d);
//   return FitResult(a, b, c);
// }

// -------------------------------------------------------------
// Simple Metropolis-Hastings MCMC
// -------------------------------------------------------------
// List<FitResult> runMCMC(
//   List<double> ts,
//   List<double> ys, {
//   required List<double> x0,
//   required FitFunction fitFunc,
//   int steps = 5000,
//   int burnin = 2000,
//   int thin = 5,
// }) {
//   final rand = math.Random();

//   double s = 0.01; // Sigma: uncertainty in mmts
//   double propStep = 1e-3;
//   List<double> x = x0.toList()..add(s);
//   double Function(List<double>, List<double>, List<double>) logLikelihood;
//   switch (fitFunc) {
//     case FitFunction.linear:
//       logLikelihood = linLogLikelihood;
//     case FitFunction.exponential;
//       logLikelihood = expLogLikelihood;
//   }
//   double currentLL = logLikelihood(ts, ys, x);

//   List<FitResult> samples = [];

//   int acceptNumber = 0;
//   for (int i = 1; i <= steps; i++) {
//     // propose new parameters
//     final aProp = a + propStep * rand.nextGaussian();
//     final bProp = b + propStep * rand.nextGaussian();
//     final cProp = c + propStep * rand.nextGaussian();
//     final sProp = s + propStep * rand.nextGaussian();
//     if (sProp <= 0) continue;

//     final llProp = logLikelihood(ts, ys, aProp, bProp, cProp, sProp);

//     final acceptProb = math.exp(llProp - currentLL);
//     // print("a $aProp, b $bProp, c $cProp, d $dProp, s $sProp, ");
//     // print(acceptProb);
//     // if (i > 200) return [];

//     if (rand.nextDouble() < acceptProb) {
//       a = aProp;
//       b = bProp;
//       c = cProp;
//       s = sProp;
//       currentLL = llProp;
//       acceptNumber++;
//     }

//     if (i > 300 && i % 50 == 0 && i < burnin) {
//       if (acceptNumber / i < 0.2) {
//         propStep *= 0.9;
//       } else if (acceptNumber / i > 0.3) {
//         propStep *= 1.1;
//       }
//     }

//     samples.add(FitResult(a, b, c));
//   }
//   print("accept number: $acceptNumber out of $steps");

//   // Remove burn in, and thin (TODO)
//   samples.removeRange(0, burnin);

//   print(
//     "a: " +
//         a.toStringAsPrecision(5) +
//         " b: " +
//         b.toStringAsPrecision(5) +
//         " c: " +
//         c.toStringAsPrecision(5) +
//         " s: " +
//         s.toStringAsPrecision(5),
//   );

//   final List<FitResult> thin_samples = [];
//   for (int i = 0; i < samples.length; i += thin) {
//     thin_samples.add(samples[i]);
//   }

//   return thin_samples;
// }

// -------------------------------------------------------------
// Bonus: Gaussian random utility
// -------------------------------------------------------------
extension RandGaussian on math.Random {
  double nextGaussian() {
    double u1 = nextDouble();
    double u2 = nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

// -------------------------------------------------------------
// New sampler: ensamble
// -------------------------------------------------------------

class EnsembleState {
  final List<List<double>> walkers; // shape: nWalkers x 3
  EnsembleState(this.walkers);
}

// -------------------------------
// Utility: randoms
// -------------------------------
class Rand {
  final math.Random _r;
  Rand([int? seed]) : _r = math.Random(seed);

  double nextDouble() => _r.nextDouble();

  // Box-Muller for Gaussian
  double nextGaussian() {
    double u1 = math.max(1e-12, _r.nextDouble());
    double u2 = _r.nextDouble();
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
  }

  int nextInt(int max) => _r.nextInt(max);
}

// -------------------------------
// Stretch move (Goodman & Weare)
// -------------------------------
// z ~ g(z) ∝ 1/sqrt(z), z in [1/aStretch, aStretch]
double drawStretchFactor(Rand r, double aStretch) {
  // Sample z using the standard trick: z = (u * (a - 1)/a + 1/a)^2
  final u = r.nextDouble();
  final amin = 1.0 / aStretch;
  // Equivalent parameterization with support [1/a, a]
  // Using Goodman & Weare’s original form: z = (u*(a - 1)/a + 1/a)^2 is common;
  // here we map linearly then square to shape the density ∝ 1/sqrt(z).
  final z = math.pow(amin + (aStretch - amin) * u, 2.0).toDouble();
  return z;
}

// -------------------------------
// Core: one stretch move proposal for a single walker
// -------------------------------
List<double> proposeStretchMove({
  required List<double> x,
  required List<double> y,
  required double z,
}) {
  assert(x.length == y.length);

  final result = List<double>.filled(x.length, 0.0);
  for (var i = 0; i < x.length; i++) {
    result[i] = y[i] + (x[i] - y[i]) * z;
  }
  return result;
}

// -------------------------------
// Acceptance probability
// -------------------------------
// For dimension d=3: alpha = min(1, z^(d-1) * exp(llProp - llCurr))
double acceptanceProb({
  required double z,
  required int dim,
  required double llProp,
  required double llCurr,
}) {
  final geom = math.pow(z, dim - 1).toDouble(); // z^(d-1)
  final ratio = geom * math.exp(llProp - llCurr);
  return ratio < 1.0 ? ratio : 1.0;
}

// -------------------------------
// Public API: ensemble sampler
// -------------------------------
class EnsembleSamplerParameters {
  List<double> ts;
  List<double> ys;
  List<List<double>> initialWalkers;
  FitFunction fitFunc;
  int steps;
  double aStretch;
  int thin;
  int burnin;
  int? seed;
  EnsembleSamplerParameters(
    this.ts,
    this.ys,
    this.initialWalkers,
    this.fitFunc, {
    this.steps = 5000,
    this.aStretch = 2.0,
    this.thin = 1,
    this.burnin = 0,
    this.seed,
  });
}

List<FitResult> ensembleSampler(EnsembleSamplerParameters p) {
  final r = Rand(p.seed);

  final int dim = 4;
  final int nWalkers = p.initialWalkers.length;
  if (nWalkers < 2 * dim) {
    throw ArgumentError('Need at least ${2 * dim} walkers; got $nWalkers.');
  }
  double Function(List<double>, List<double>, List<double>) logLikelihood;
  switch (p.fitFunc) {
    case FitFunction.linear:
      logLikelihood = linLogLikelihood;
    case FitFunction.exponential:
      logLikelihood = expLogLikelihood;
  }

  // Current state and LLs
  final walkers = p.initialWalkers.map((w) => w.toList()).toList();
  final llVals = List<double>.generate(
    nWalkers,
    (i) => logLikelihood(p.ts, p.ys, walkers[i]),
  );

  // Storage
  final samples = <FitResult>[];
  int accepted = 0;
  int proposed = 0;

  // Main loop
  for (int t = 0; t < p.steps; t++) {
    // Split walkers into two complementary sets (alternating)
    final evenIdx = <int>[];
    final oddIdx = <int>[];
    for (int i = 0; i < nWalkers; i++) {
      (i % 2 == 0 ? evenIdx : oddIdx).add(i);
    }

    // Update even using odd as complementary
    _updateGroup(
      ts: p.ts,
      ys: p.ys,
      logLikelihood: logLikelihood,
      targetIdx: evenIdx,
      compIdx: oddIdx,
      walkers: walkers,
      llVals: llVals,
      r: r,
      aStretch: p.aStretch,
      dim: dim,
      acceptedRef: () => accepted++,
      proposedRef: () => proposed++,
    );

    // Update odd using even as complementary
    _updateGroup(
      ts: p.ts,
      ys: p.ys,
      logLikelihood: logLikelihood,
      targetIdx: oddIdx,
      compIdx: evenIdx,
      walkers: walkers,
      llVals: llVals,
      r: r,
      aStretch: p.aStretch,
      dim: dim,
      acceptedRef: () => accepted++,
      proposedRef: () => proposed++,
    );

    // Record sample (e.g., mean of walkers or all walkers)
    // Here we record all walkers; you can change to mean if you prefer.
    if (t >= p.burnin && ((t - p.burnin) % p.thin == 0)) {
      for (final w in walkers) {
        samples.add(FitResult(w));
      }
    }
  }

  // final accRate = proposed > 0 ? accepted / proposed : 0.0;
  // Optional: print or return diagnostics
  // print('Ensemble acceptance rate: ${(accRate * 100).toStringAsFixed(1)}%');

  return samples;
}

// -------------------------------
// Internal helper: update one group via stretch moves
// -------------------------------
void _updateGroup({
  required List<double> ts,
  required List<double> ys,
  required Function logLikelihood,
  required List<int> targetIdx,
  required List<int> compIdx,
  required List<List<double>> walkers,
  required List<double> llVals,
  required Rand r,
  required double aStretch,
  required int dim,
  required void Function() acceptedRef,
  required void Function() proposedRef,
}) {
  for (final i in targetIdx) {
    // Choose a complementary walker uniformly
    final j = compIdx[r.nextInt(compIdx.length)];
    final x = walkers[i];
    final y = walkers[j];

    // Draw stretch factor
    final z = drawStretchFactor(r, aStretch);

    // Propose
    final xProp = proposeStretchMove(x: x, y: y, z: z);
    final llProp = logLikelihood(ts, ys, xProp);
    final llCurr = llVals[i];

    // Accept-reject
    final alpha = acceptanceProb(
      z: z,
      dim: dim,
      llProp: llProp,
      llCurr: llCurr,
    );
    proposedRef();
    if (r.nextDouble() < alpha) {
      walkers[i] = xProp;
      llVals[i] = llProp;
      acceptedRef();
    }
  }
}

class PredictCurvesParameters {
  FitFunction fitFunc;
  double? target;
  double meanX;
  double minX;
  double maxX;
  double rangeX;
  double meanY;
  double minY;
  double maxY;
  double rangeY;
  List<FitResult> samples;
  int nCurvePoints;

  PredictCurvesParameters(
    this.fitFunc,
    this.target,
    this.meanX,
    this.minX,
    this.maxX,
    this.rangeX,
    this.meanY,
    this.minY,
    this.maxY,
    this.rangeY,
    this.samples,
    this.nCurvePoints,
  );
}

class PredictedCurves {
  List<double> ts;
  double? lowIntercept;
  double? medIntercept;
  double? highIntercept;
  List<double> medianLine;
  List<double> lowerBand;
  List<double> upperBand;

  PredictedCurves(
    this.ts,
    this.lowIntercept,
    this.medIntercept,
    this.highIntercept,
    this.medianLine,
    this.lowerBand,
    this.upperBand,
  );
}

PredictedCurves predictCurves(PredictCurvesParameters p) {
  List<double> medianLine = [];
  List<double> lowerBand = [];
  List<double> upperBand = [];
  List<double> ts = [];
  double? lowIntercept;
  double? medIntercept;
  double? highIntercept;

  double Function(FitResult) targetIntercept;
  double Function(double, List<double>) model;
  switch (p.fitFunc) {
    case FitFunction.exponential:
      model = expModel;
      // Find the intercept with target (if target is not null...)
      // y = a - b^2/c (1-exp(c/b*x))) => x = ln[1+(y-a) * c / b^2] * b / c
      targetIntercept = (FitResult s) {
        double t = (p.target! - p.meanY) / p.rangeY;

        final a = s.x[0];
        final b = s.x[1];
        final c = s.x[2];

        if ((1 + (t - a) * c / (b * b)) <= 0) {
          return -(c / b).sign * double.infinity;
        }

        double xInterceptNorm = math.log(1 + (t - a) * c / (b * b)) * b / c;

        return xInterceptNorm * p.rangeX + p.meanX;
      };
    case FitFunction.linear:
      model = linModel;
      targetIntercept = (FitResult s) {
        double t = (p.target! - p.meanY) / p.rangeY;

        final a = s.x[0];
        final b = s.x[1];
        if (a == 0) return double.infinity;
        double xInterceptNorm = (t - b) / a;

        return xInterceptNorm * p.rangeX + p.meanX;
      };
  }

  double plotWindowMinX = p.minX - 0.1 * p.rangeX;
  double plotWindowMaxX = p.maxX + 0.1 * p.rangeX;

  if (p.target != null) {
    List<double> tIntercepts = p.samples.map(targetIntercept).toList()..sort();
    final lowerIndex = (tIntercepts.length * 0.025).floor();
    final upperIndex = (tIntercepts.length * 0.975).floor();
    final medianIndex = tIntercepts.length ~/ 2;

    lowIntercept = tIntercepts[lowerIndex];
    medIntercept = tIntercepts[medianIndex];
    highIntercept = tIntercepts[upperIndex];

    plotWindowMinX = [
      lowIntercept,
      medIntercept,
      highIntercept,
      p.minX - 0.1 * p.rangeX,
    ].where((v) => v != -double.infinity).reduce(math.min);

    plotWindowMaxX = [
      lowIntercept,
      medIntercept,
      highIntercept,
      p.maxX + 0.1 * p.rangeX,
    ].where((v) => v != double.infinity).reduce(math.max);
  }

  for (int i = 0; i < p.nCurvePoints; i++) {
    final t =
        plotWindowMinX +
        (plotWindowMaxX - plotWindowMinX) * i / (p.nCurvePoints - 1);
    final tNorm = (t - p.meanX) / p.rangeX;

    // compute y-values for each MCMC sample
    List<double> ySamples = p.samples.map((s) => model(tNorm, s.x)).toList()
      ..sort();
    //List<double> ySamples = samples.map((s) => model(tNorm, initialFit.a, initialFit.b, initialFit.c, initialFit.d)).toList()
    //..sort();

    final lowerIndex = (ySamples.length * 0.025).floor();
    final upperIndex = (ySamples.length * 0.975).floor();
    final medianIndex = ySamples.length ~/ 2;

    ts.add(t);
    lowerBand.add(p.meanY + p.rangeY * ySamples[lowerIndex]);
    upperBand.add(p.meanY + p.rangeY * ySamples[upperIndex]);
    medianLine.add(p.meanY + p.rangeY * ySamples[medianIndex]);
  }

  return PredictedCurves(
    ts,
    lowIntercept,
    medIntercept,
    highIntercept,
    medianLine,
    lowerBand,
    upperBand,
  );
}
