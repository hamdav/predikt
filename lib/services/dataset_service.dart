import 'package:hive/hive.dart';
import '../logic/data.dart';

class DatasetService {
  static const boxName = 'datasets';

  Future<Box> _open() async {
    return await Hive.openBox(boxName);
  }

  /// Save list of DataPoints under a dataset name
  Future<void> saveDataset(String name, DataSet dataSet) async {
    final box = await _open();
    await box.put(name, dataSet);
  }

  /// Load DataPoints of a dataset
  Future<DataSet> loadDataset(String name) async {
    final box = await _open();
    DataSet? data = box.get(name);
    return data ??
        DataSet(fitFunc: FitFunction.exponential, points: [], target: null);
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
