import 'package:hive/hive.dart';

part 'data_point.g.dart';

@HiveType(typeId: 1)
class DataPoint extends HiveObject {
  @HiveField(0)
  double value;

  @HiveField(1)
  DateTime timestamp;

  DataPoint({required this.value, required this.timestamp});
}
