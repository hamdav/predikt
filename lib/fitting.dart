import 'dart:math' as math;

class FitResult {
  final double a;
  final double b;
  final double c;
  FitResult(this.a, this.b, this.c);
}

// Model: a * (1 - exp((t - b)/c))
double model(double t, double a, double b, double c) {
  return a * (1 - math.exp((t - b) / c));
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
