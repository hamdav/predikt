import 'dart:math' as math;
import 'package:advance_math/advance_math.dart';

class FitResult {
  final double a;
  final double b;
  final double c;
  final double d;
  FitResult(this.a, this.b, this.c, this.d);
}

// Model: a * (1 - exp((t - b)*c))
double model(double t, double a, double b, double c, double d) {
  return a - b * math.exp(c * (t - d));
}

// -------------------------------------------------------------
// Log-likelihood: Gaussian error model
// -------------------------------------------------------------
double logLikelihood(
  List<double> ts,
  List<double> ys,
  double a,
  double b,
  double c,
  double d,
  double s,
) {
  double sum = 0;
  for (int i = 0; i < ts.length; i++) {
    final pred = model(ts[i], a, b, c, d);
    final err = ys[i] - pred;
    sum += -(0.5 * err * err) / (s * s) - 0.5 * math.log(2 * math.pi * s * s);
  }
  // Gammadistribution for variance with alpha=2, theta=0.1
  double prior =
      math.log(s * s) -
      s * s / 0.01 -
      a * a / 1000 -
      b * b / 1000 -
      c * c / 1000 -
      d * d / 1000;
  return sum + prior;
}

// TODO: WHAT IF Number of points is two or three?
// Nonlinear least-squares fit using gradient descent
FitResult fitABC(List<double> t, List<double> y) {
  double a = y.last; // initial guess
  double b = a - y.first; // initial guess
  double c = -4 / (t.reduce(math.max) - t.reduce(math.min)); // growth timescale
  double d = t.reduce(math.min);
  double disableC = 1.0;
  if (y.length == 2) {
    c = -0.05 / (t.reduce(math.max) - t.reduce(math.min)); // growth timescale
    disableC = 0.0;
  }

  double mA = 0, mB = 0, mC = 0, mD = 0;
  double vA = 0, vB = 0, vC = 0, vD = 0;
  double beta1 = 0.9;
  double beta2 = 0.95;
  double epsilon = 1e-7;
  double err = 0;

  double lrInitial = 5e-2; // learning rate
  for (int iter = 0; iter < 8000; iter++) {
    double lr = 80 * lrInitial / (iter + 80);
    //double lr = lrInitial;
    double da = 0, db = 0, dc = 0, dd = 0;
    err = 0;

    for (int i = 0; i < t.length; i++) {
      double ti = t[i];
      double yi = y[i];
      double pred = model(ti, a, b, c, d);

      double e = pred - yi;
      double E = math.exp(c * (ti - d));

      da += 2 * e;
      db += -2 * e * E;
      dc += -2 * e * b * (E * (ti - d)) * disableC;
      dd += 2 * e * b * (E * c);
      err += e * e;
    }

    mA = (beta1 * mA + (1 - beta1) * da);
    vA = (beta2 * vA + (1 - beta2) * da * da);
    mB = (beta1 * mB + (1 - beta1) * db);
    vB = (beta2 * vB + (1 - beta2) * db * db);
    mC = (beta1 * mC + (1 - beta1) * dc);
    vC = (beta2 * vC + (1 - beta2) * dc * dc);
    mD = (beta1 * mD + (1 - beta1) * dd);
    vD = (beta2 * vD + (1 - beta2) * dd * dd);

    a -= lr * mA / math.sqrt(vA + epsilon);
    b -= lr * mB / math.sqrt(vB + epsilon);
    c -= lr * mC / math.sqrt(vC + epsilon);
    d -= lr * mD / math.sqrt(vD + epsilon);
    err = math.sqrt(err / t.length);
    // if (iter % 100 == 0) {
    //   print(
    //     "a: " +
    //         a.toStringAsPrecision(5) +
    //         " b: " +
    //         b.toStringAsPrecision(5) +
    //         " c: " +
    //         c.toStringAsPrecision(5) +
    //         " d: " +
    //         d.toStringAsPrecision(5) +
    //         " err: " +
    //         err.toStringAsPrecision(3),
    //   );
    //}
  }

  // print(
  //   "a: " +
  //       a.toStringAsPrecision(5) +
  //       " b: " +
  //       b.toStringAsPrecision(5) +
  //       " c: " +
  //       c.toStringAsPrecision(5) +
  //       " d: " +
  //       d.toStringAsPrecision(5) +
  //       " err: " +
  //       err.toStringAsPrecision(3),
  // );

  return FitResult(a, b, c, d);
}

// -------------------------------------------------------------
// Simple Metropolis-Hastings MCMC
// -------------------------------------------------------------
List<FitResult> runMCMC(
  List<double> ts,
  List<double> ys, {
  required double a0,
  required double b0,
  required double c0,
  required double d0,
  int steps = 5000,
  int burnin = 2000,
  int thin = 5,
}) {
  final rand = math.Random();

  double a = a0;
  double b = b0;
  double c = c0;
  double d = d0;
  double s = 0.01; // Sigma: uncertainty in mmts

  double propStep = 1e-3;
  double currentLL = logLikelihood(ts, ys, a, b, c, d, s);

  List<FitResult> samples = [];

  int acceptNumber = 0;
  for (int i = 1; i <= steps; i++) {
    // propose new parameters
    final aProp = a + propStep * rand.nextGaussian();
    final bProp = b + propStep * rand.nextGaussian();
    final cProp = c + propStep * rand.nextGaussian();
    final dProp = d + propStep * rand.nextGaussian();
    final sProp = s + propStep * rand.nextGaussian();
    if (sProp <= 0) continue;

    final llProp = logLikelihood(ts, ys, aProp, bProp, cProp, dProp, sProp);

    final acceptProb = math.exp(llProp - currentLL);
    // print("a $aProp, b $bProp, c $cProp, d $dProp, s $sProp, ");
    // print(acceptProb);
    // if (i > 200) return [];

    if (rand.nextDouble() < acceptProb) {
      a = aProp;
      b = bProp;
      c = cProp;
      d = dProp;
      s = sProp;
      currentLL = llProp;
      acceptNumber++;
    }

    if (i > 300 && i % 50 == 0 && i < burnin) {
      if (acceptNumber / i < 0.2) {
        propStep *= 0.9;
      } else if (acceptNumber / i > 0.3) {
        propStep *= 1.1;
      }
    }

    samples.add(FitResult(a, b, c, d));
  }
  print("accept number: $acceptNumber out of $steps");

  // Remove burn in, and thin (TODO)
  samples.removeRange(0, burnin);

  print(
    "a: " +
        a.toStringAsPrecision(5) +
        " b: " +
        b.toStringAsPrecision(5) +
        " c: " +
        c.toStringAsPrecision(5) +
        " d: " +
        d.toStringAsPrecision(5) +
        " s: " +
        s.toStringAsPrecision(5),
  );

  final List<FitResult> thin_samples = [];
  for (int i = 0; i < samples.length; i += thin) {
    thin_samples.add(samples[i]);
  }

  return thin_samples;
}

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
