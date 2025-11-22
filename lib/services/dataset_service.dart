import 'package:hive/hive.dart';
import '../logic/data_point.dart';

class DatasetService {
  static const boxName = 'datasets';

  Future<Box> _open() async {
    return await Hive.openBox(boxName);
  }

  /// Save list of DataPoints under a dataset name
  Future<void> saveDataset(String name, List<DataPoint> points) async {
    final box = await _open();
    await box.put(name, points);
  }

  /// Load DataPoints of a dataset
  Future<List<DataPoint>> loadDataset(String name) async {
    final box = await _open();
    final data = box.get(name);
    return data != null ? List<DataPoint>.from(data) : [];
  }

  /// List all dataset names
  Future<List<String>> listDatasets() async {
    final box = await _open();
    return box.keys.cast<String>().toList();
  }

  /// Delete a dataset
  Future<void> deleteDataset(String name) async {
    final box = await _open();
    await box.delete(name);
  }
}