import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../logic/graph_controller.dart';
import '../logic/data_point.dart';

class GraphPage extends StatefulWidget {
  final String? datasetName;

  const GraphPage({super.key, this.datasetName});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  final controller = GraphController();
  final TextEditingController valueController = TextEditingController();
  late List<DataPoint> localpoints;

    @override
    void initState() {
        super.initState();
        _init();
    }

    Future<void> _init() async {

        if (widget.datasetName == null) {
            // Automatically create a brand-new dataset
            final newName = _generateDatasetName();
            controller.currentDatasetName = newName;
            await controller.saveCurrentDataset(); // save empty dataset
        } else {
            // Load existing dataset
            await controller.loadDataset(widget.datasetName!);
        }
        setState( () {
            localpoints = controller.points.toList();
            controller.updateFit();
        });
    }

    String _generateDatasetName() {
        final now = DateTime.now();
        return 'Dataset_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}';
    }

  void _addValueNow() {
    final text = valueController.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;

    controller.addPoint(number);
    valueController.clear();
    setState(() {
      localpoints = controller.points.toList();
      controller.updateFit();
      controller.saveCurrentDataset();
    });
  }

  void _addValueWithPicker() async {
    final picked = await pickDateTime(context);
    if (picked == null) return;

    final text = valueController.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;

    controller.addPoint(number, timestamp: picked);
    valueController.clear();
    setState(() {
      localpoints = controller.points.toList();
      controller.updateFit();
      controller.saveCurrentDataset();
    });
  }

  Future<DateTime?> pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void editPointDialog(DataPoint point, int index) {
    final valueController =
      TextEditingController(text: point.value.toString());

    showDialog(
        context: context,
        builder: (_) {
        return AlertDialog(
            title: const Text("Edit Point"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: valueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Value"),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  child: const Text("Change Timestamp"),
                  onPressed: () async {
                    final picked = await pickDateTime(context);
                    if (picked != null) {
                      point.timestamp = picked;
                      // await point.save();
                      setState(() {
                        localpoints = controller.points.toList();
                        controller.updateFit();
                        controller.saveCurrentDataset();
                      });
                    }
                  },
                  )
              ],
              ),
              actions: [
                TextButton(
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.pop(context),
                    ),
              TextButton(
                  child: const Text("Save"),
                  onPressed: () async {
                  final newVal = double.tryParse(valueController.text);
                  if (newVal != null) {
                  point.value = newVal;
                  // await point.save();
                  setState(() {
                    localpoints = controller.points.toList();
                        controller.updateFit();
      controller.saveCurrentDataset();
                  });
                  }
                  Navigator.pop(context);
                  },
                  ),
              ],
              );
        },
        );
  }

  String formatTimestamp(double s) {
    final dt = DateTime.fromMillisecondsSinceEpoch(s.toInt() * 1000);
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}\n${dt.month}/${dt.day}";
  }

  Widget buildChart() {
    if (controller.points.isEmpty) return const Center(child: Text("Chart will appear here"));

    final minX = controller.valueSpots.first.x;
    final maxX = controller.valueSpots.last.x;
    // TODO: +1/-1... do better
    final minY = controller.valueSpots.map((s) => s.y).reduce(math.min) - 1;
    final maxY = controller.valueSpots.map((s) => s.y).reduce(math.max) + 1;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxX - minX) == 0
                 ? 1  // fallback interval
                 : (maxX- minX) / 4,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(formatTimestamp(value),
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(left: BorderSide(width: 2), bottom: BorderSide(width: 2)),
        ),
        lineBarsData: [
          // USER DATA
          LineChartBarData(
            spots: controller.valueSpots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),

          // MEDIAN FITTED LINE
          LineChartBarData(
            spots: controller.medianLine,
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),

          // CONFIDENCE BAND (shaded area)
          LineChartBarData(
            spots: controller.lowerBand,
            isCurved: true,
            color: Colors.transparent,
            barWidth: 0,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: controller.upperBand,
            isCurved: true,
            color: Colors.transparent,
            barWidth: 0,
            dotData: FlDotData(show: false),
          ),
        ],
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: 2, // lowerBand index
            toIndex: 3,   // upperBand index
            color: Colors.red.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(title: const Text("Plot Values")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Enter a number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addValueNow,
                  onLongPress: _addValueWithPicker,
                  child: ElevatedButton(
                    onPressed: null,
                    child: const Text("Add"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: buildChart(),
              ),
            ),
            // List of points
            Expanded(
              child: ListView.builder(
                itemCount: controller.points.length,
                itemBuilder: (context, index) {
                  final point = controller.points[index]!;

                  return Dismissible(
                    key: Key(point.value.toString() + point.timestamp.millisecondsSinceEpoch.toDouble().toString()),
                    background: Container(color: Colors.red),
                    onDismissed: (_) {
                        // Remove the item from the data source immediately
                        final removedPoint = point;

                        // Optionally show a snackbar to undo
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                            content: Text("Deleted ${removedPoint.value}"),
                            action: SnackBarAction(
                                label: "Undo",
                                onPressed: () {
                                setState(() {
                                    controller.addPoint(removedPoint.value, timestamp: removedPoint.timestamp);
                                    controller.updateFit();
                                    localpoints = controller.points.toList();
                                    controller.saveCurrentDataset();
                                });
                                },
                            ),
                            ),
                        );
                        setState((){
                          controller.deletePoint(point);
                        controller.updateFit();
                        controller.saveCurrentDataset();
                      });
                    // WidgetsBinding.instance.addPostFrameCallback((_) { // Delay rebuild...
                    //   setState(() {});
                    // });
                    },
                    child: ListTile(
                      title: Text("${point.value}"),
                      subtitle: Text(point.timestamp.toString()),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => editPointDialog(point, index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}