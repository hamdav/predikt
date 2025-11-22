import 'dart:math' as math;

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
    List<double> ts, List<double> ys, double a, double b, double c, double d, double s) {
  double sum = 0;
  for (int i = 0; i < ts.length; i++) {
    final pred = model(ts[i], a, b, c, d);
    final err = ys[i] - pred;
    sum += -(0.5 * err * err) / (s*s) - 0.5*math.log(2*math.pi*s*s);
  }
  return sum;
}

// Nonlinear least-squares fit using gradient descent
FitResult fitABC(List<double> t, List<double> y) {
  double a = y.last;     // initial guess
  double b = a - y.first;     // initial guess
  double c = -4/(t.reduce(math.max) - t.reduce(math.min)); // growth timescale
  double d = t.reduce(math.min);

  double mA = 0, mB = 0, mC = 0, mD = 0;
  double vA = 0, vB = 0, vC = 0, vD = 0;
  double beta1 = 0.9;
  double beta2 = 0.95;
  double epsilon = 1e-7;


  double lrInitial = 1e-1;  // learning rate
  for (int iter = 0; iter < 8000; iter++) {
    double lr = 80 * lrInitial / (iter+80);
    //double lr = lrInitial;
    double da = 0, db = 0, dc = 0, dd = 0;
    double err = 0;

    for (int i = 0; i < t.length; i++) {
      double ti = t[i];
      double yi = y[i];
      double pred = model(ti, a, b, c, d);

      double e = pred - yi;
      double E  = math.exp(c * (ti - d));

      da += 2 * e;
      db += -2 * e * E;
      dc += -2 * e * b * (E * (ti - d));
      dd += 2 * e * b * (E * c);
      err += e*e;
    }

    mA = (beta1 * mA + (1-beta1) * da);
    vA = (beta2 * vA + (1-beta2) * da * da);
    mB = (beta1 * mB + (1-beta1) * db);
    vB = (beta2 * vB + (1-beta2) * db * db);
    mC = (beta1 * mC + (1-beta1) * dc);
    vC = (beta2 * vC + (1-beta2) * dc * dc);
    mD = (beta1 * mD + (1-beta1) * dd);
    vD = (beta2 * vD + (1-beta2) * dd * dd);

    a -= lr * mA / (vA + epsilon);
    b -= lr * mB / (vB + epsilon);
    c -= lr * mC / (vC + epsilon);
    d -= lr * mD / (vD + epsilon);
    err = math.sqrt(err/t.length);
    if (iter % 100 == 0) {
      print("da=$da, db=$db, dc=$dc");
      print("a=$a, b=$b, c=$c, err=$err");
      }
  }

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
  double stepA = 0.01,
  double stepB = 0.01,
  double stepC = 0.01,
  double stepD = 0.01,
}) {
  final rand = math.Random();

  double a = a0;
  double b = b0;
  double c = c0;
  double d = d0;
  double s = 0.01; // Sigma: uncertainty in mmts
  // double a = 1;
  // double b = 0;
  // double c = 10;
  // double s = 0.01; // Sigma: uncertainty in mmts

  double stepS = 0.01; // Sigma: uncertainty in mmts

  double currentLL = logLikelihood(ts, ys, a, b, c, d, s);

  List<FitResult> samples = [];

  //double manualLLTMP = logLikelihood(ts, ys, 1, 0, 10, 0.1);
  //print("Manual LL: $manualLLTMP");

  int acceptNumber = 0;
  for (int i = 0; i < steps; i++) {
    // propose new parameters
    final aProp = a + rand.nextGaussian() * stepA;
    final bProp = b + rand.nextGaussian() * stepB;
    final cProp = c + rand.nextGaussian() * stepC;
    final dProp = d + rand.nextGaussian() * stepD;
    final sProp = s + rand.nextGaussian() * stepS;

    // if (sProp > 0.1)
    //   continue;

    final llProp = logLikelihood(ts, ys, aProp, bProp, cProp, dProp, sProp);

    final acceptProb = math.exp(llProp - currentLL);

    if (rand.nextDouble() < acceptProb) {
      a = aProp;
      b = bProp;
      c = cProp;
      d = dProp;
      s = sProp;
      currentLL = llProp;
      acceptNumber++;
    }

    // if (i < 100)
    //     print("a=$a, b=$b, c=$c, s=$s, ll=$currentLL");
    samples.add(FitResult(a, b, c, d));
  }
  print("accept number: $acceptNumber out of $steps");

  // Remove burn in, and thin (TODO)
  samples.removeRange(0,2000);

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
