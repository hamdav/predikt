import 'dart:math' as math;

double model(double t, double a, double b, double c) {
  return a * (1 - math.exp(-(t - b) / c));
}

class FitResult {
  final double a;
  final double b;
  final double c;

  FitResult(this.a, this.b, this.c);
}

FitResult fitABC(List<double> ts, List<double> ys) {
  double a = ys.last;                                // first guess
  double b = ts.first;                               // horizontal shift
  double c = (ts.last - ts.first) / 2;               // time constant

  const double lr = 0.00005;                         // learning rate
  const int iterations = 6000;

  double loss(List<double> ts, List<double> ys, double a, double b, double c) {
    double sum = 0;
    for (int i = 0; i < ts.length; i++) {
      final yhat = model(ts[i], a, b, c);
      final err = ys[i] - yhat;
      sum += err * err;
    }
    return sum;
  }

  for (int it = 0; it < iterations; it++) {
    const double eps = 1e-6;

    double base = loss(ts, ys, a, b, c);

    double gradA = (loss(ts, ys, a + eps, b, c) - base) / eps;
    double gradB = (loss(ts, ys, a, b + eps, c) - base) / eps;
    double gradC = (loss(ts, ys, a, b, c + eps) - base) / eps;

    a -= lr * gradA;
    b -= lr * gradB;
    c -= lr * gradC;

    if (c < eps) c = eps;
  }

  return FitResult(a, b, c);
}
