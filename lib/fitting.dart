import 'dart:math' as math;

class FitResult {
  final double a;
  final double b;
  final double c;
  FitResult(this.a, this.b, this.c);
}

// Model: a * (1 - exp((t - b)/c))
double model(double t, double a, double b, double c) {
  return a * (1 - math.exp(-(t - b) / c));
}

// Nonlinear least-squares fit using gradient descent
FitResult fitABC(List<double> t, List<double> y) {
  double a = y.reduce(math.max);     // initial guess
  double b = t.first;                // offset time
  double c = (t.last - t.first) / 2; // growth timescale

  double lr = 1e-6;  // learning rate
  for (int iter = 0; iter < 8000; iter++) {
    double da = 0, db = 0, dc = 0;

    for (int i = 0; i < t.length; i++) {
      double ti = t[i];
      double yi = y[i];
      double pred = model(ti, a, b, c);

      double e = pred - yi;
      double E  = math.exp((ti - b) / c);

      da += 2 * e * (1 - E);
      db += 2 * e * a * (E / c);
      dc += 2 * e * a * (E * (b - ti) / (c * c));
    }

    a -= lr * da;
    b -= lr * db;
    c -= lr * dc;
  }

print("a=$a, b=$b, c=$c");
  return FitResult(a, b, c);
}

// -------------------------------------------------------------
// Log-likelihood: Gaussian error model
// -------------------------------------------------------------
double logLikelihood(
    List<double> ts, List<double> ys, double a, double b, double c) {
  double sum = 0;
  for (int i = 0; i < ts.length; i++) {
    final pred = model(ts[i], a, b, c);
    final err = ys[i] - pred;
    sum += -0.5 * err * err; // sigma^2 = 1 (we don't need to know sigma)
  }
  return sum;
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
  int steps = 5000,
  double stepA = 0.05,
  double stepB = 0.05,
  double stepC = 0.05,
}) {
  final rand = math.Random();

  double a = a0;
  double b = b0;
  double c = c0;

  double currentLL = logLikelihood(ts, ys, a, b, c);

  List<FitResult> samples = [];

  for (int i = 0; i < steps; i++) {
    // propose new parameters
    final aProp = a + rand.nextGaussian() * stepA;
    final bProp = b + rand.nextGaussian() * stepB;
    final cProp = c + rand.nextGaussian() * stepC;

    // reject nonsense
    if (cProp == 0 || cProp.isNaN || aProp.isNaN) continue;

    final llProp = logLikelihood(ts, ys, aProp, bProp, cProp);

    final acceptProb = math.exp(llProp - currentLL);

    if (rand.nextDouble() < acceptProb) {
      a = aProp;
      b = bProp;
      c = cProp;
      currentLL = llProp;
    }

    samples.add(FitResult(a, b, c));
  }

  return samples;
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
