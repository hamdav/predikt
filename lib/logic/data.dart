import 'package:hive/hive.dart';

part 'data.g.dart';

@HiveType(typeId: 1)
class DataPoint extends HiveObject {
  @HiveField(0)
  double value;

  @HiveField(1)
  DateTime timestamp;

  DataPoint({required this.value, required this.timestamp});
}

@HiveType(typeId: 3)
enum FitFunction {
  @HiveField(0)
  linear,
  @HiveField(1)
  exponential,
}

@HiveType(typeId: 2)
class DataSet extends HiveObject {
  @HiveField(0)
  FitFunction fitFunc;

  @HiveField(1)
  List<DataPoint> points;

  @HiveField(2)
  double? target;

  DataSet({required this.fitFunc, required this.points, this.target});
}
