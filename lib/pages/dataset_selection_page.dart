import 'package:flutter/material.dart';
import '../services/dataset_service.dart';
import 'graph_page.dart';
import '../logic/data.dart';

class DatasetSelectorPage extends StatefulWidget {
  const DatasetSelectorPage({super.key});

  @override
  State<DatasetSelectorPage> createState() => _DatasetSelectorPageState();
}

class _DatasetSelectorPageState extends State<DatasetSelectorPage> {
  final DatasetService service = DatasetService();
  List<String> datasets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    datasets = await service.listDatasets();
    setState(() {});
  }

  void _createDatasetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create new dataset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Dataset name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createDataset(controller.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createDataset(String name) async {
    if (name.isEmpty) return;
    await service.saveDataset(
      name,
      DataSet(fitFunc: FitFunction.exponential, points: [], target: null),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Dataset")),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDatasetDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: datasets.length,
        itemBuilder: (_, i) {
          final name = datasets[i];
          return Dismissible(
            key: Key(name),
            background: Container(color: Colors.red),
            onDismissed: (_) {
              service.deleteDataset(name);
              setState(() {
                _load();
              });
            },
            child: ListTile(
              title: Text(name),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GraphPage(datasetName: name),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
