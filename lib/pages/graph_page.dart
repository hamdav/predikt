import 'package:advance_math/advance_math.dart';
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
  final TextEditingController targetController = TextEditingController();
  final TextEditingController datasetNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.datasetName == null) {
      // Automatically create a brand-new dataset
      // final newName = _generateDatasetName();
      final newName = "Autosave";
      controller.currentDatasetName = newName;
      //await controller.saveCurrentDataset(); // save empty dataset
    } else {
      // Load existing dataset
      await controller.loadDataset(widget.datasetName!);
    }
    setState(() {
      controller.updateFit();
    });
  }

  String _generateDatasetName() {
    final now = DateTime.now();
    return 'Dataset_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}';
  }

  void _setTarget() {
    final text = targetController.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;
    controller.target = number;
    // targetController.clear();
    setState(() {
      controller.updateFit();
    });
  }

  void _addValueNow() {
    final text = valueController.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;

    controller.addPoint(number);
    valueController.clear();
    setState(() {
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
      controller.updateFit();
      controller.saveCurrentDataset();
    });
  }

  void _saveDatasetAs() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Save Dataset"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: datasetNameController,
                // keyboardType: const TextInputType.text,
                decoration: const InputDecoration(labelText: "Name"),
              ),
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
                final newName = datasetNameController.text;
                if (newName != null && newName != "") {
                  controller.currentDatasetName = newName;
                  controller.saveCurrentDataset();
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
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
    final valueController = TextEditingController(text: point.value.toString());

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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                      controller.updateFit();
                      controller.saveCurrentDataset();
                    });
                  }
                },
              ),
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
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}\n${dt.day}/${dt.month}";
  }

  String formatTimestampWithSeconds(double s) {
    final dt = DateTime.fromMillisecondsSinceEpoch(s.toInt() * 1000);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }

  Widget buildChart(BuildContext context) {
    if (controller.medianLine.isEmpty)
      return const Center(child: Text("Chart will appear here"));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    double minX = math.min(
      controller.medianLine.first.x,
      controller.valueSpots.first.x,
    );
    double maxX = math.max(
      controller.medianLine.last.x,
      controller.valueSpots.last.x,
    );
    double minY = math.min(
      controller.medianLine.map((s) => s.y).reduce(math.min),
      controller.valueSpots.map((s) => s.y).reduce(math.min),
    );
    double maxY = math.max(
      controller.medianLine.map((s) => s.y).reduce(math.max),
      controller.valueSpots.map((s) => s.y).reduce(math.max),
    );
    if (controller.target != null) {
      minY = math.min(minY, controller.target!);
      maxY = math.max(maxY, controller.target!);
    }
    //minX -= 0.05 * (maxX - minX);
    //maxX += 0.05 * (maxX - minX);
    minY -= 0.05 * (maxY - minY);
    maxY += 0.05 * (maxY - minY);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(10),
              getTooltipColor: (_) => colorScheme.surface,
              getTooltipItems: (touchedSpots) {
                List<LineTooltipItem?> rv = touchedSpots.map((e) {
                  final textStyle = TextStyle(
                    color:
                        e.bar.gradient?.colors.first ??
                        e.bar.color ??
                        Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  );
                  return e.bar.color == Colors.transparent
                      ? null
                      : LineTooltipItem(
                          't: ${formatTimestampWithSeconds(e.x)}\ny: ${e.y.toStringAsPrecision(4)}',
                          textStyle,
                        );
                }).toList();
                return rv;
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.onSurface.withAlpha(25),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: colorScheme.onSurface.withAlpha(25),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (maxX - minX) == 0
                    ? 1 // fallback interval
                    : (maxX - minX) / 4,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      formatTimestamp(value),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                interval: (maxY - minY) == 0
                    ? 1 // fallback interval
                    : (maxY - minY) / 4,
                minIncluded: false,
                maxIncluded: false,
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      value.toStringAsPrecision(2),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(width: 2),
              bottom: BorderSide(width: 2),
            ),
          ),
          lineBarsData: [
            // MEDIAN FITTED LINE
            LineChartBarData(
              spots: controller.medianLine,
              isCurved: true,
              color: colorScheme.secondary,
              barWidth: 4,
              dotData: const FlDotData(show: false),
            ),
            // USER DATA
            LineChartBarData(
              spots: controller.valueSpots,
              isCurved: false,
              color: colorScheme.tertiary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
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
            // Target line
            LineChartBarData(
              spots: controller.target == null
                  ? []
                  : [
                      FlSpot(minX, controller.target!),
                      FlSpot(maxX, controller.target!),
                    ],
              isCurved: false,
              color: colorScheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [2, 1],
            ),
          ],
          betweenBarsData: [
            BetweenBarsData(
              fromIndex: 2, // lowerBand index
              toIndex: 3, // upperBand index
              color: colorScheme.secondary.withAlpha(100),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String lowIntercept = "no target";
    String medIntercept = "no target";
    String highIntercept = "no target";
    if (controller.target != null) {
      if (controller.lowIntercept == double.infinity)
        lowIntercept = "infinity";
      else if (controller.lowIntercept == -double.infinity)
        lowIntercept = "-infinity";
      else
        lowIntercept = formatTimestamp(controller.lowIntercept!);
      if (controller.medIntercept == double.infinity)
        medIntercept = "infinity";
      else if (controller.medIntercept == -double.infinity)
        medIntercept = "-infinity";
      else
        medIntercept = formatTimestamp(controller.medIntercept!);
      if (controller.highIntercept == double.infinity)
        highIntercept = "infinity";
      else if (controller.highIntercept == -double.infinity)
        highIntercept = "-infinity";
      else
        highIntercept = formatTimestamp(controller.highIntercept!);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.currentDatasetName ?? "Autosave"),
        actions: [
          ElevatedButton(
            onPressed: _saveDatasetAs,
            child: const Text("Save Data"),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 10,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Enter a number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  //onTap: _addValueNow,
                  onLongPress: _addValueWithPicker,
                  child: ElevatedButton(
                    onPressed: _addValueNow,
                    child: const Text("Add"),
                    // style: ElevatedButton.styleFrom(
                    //   foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    //   backgroundColor: Theme.of(context).colorScheme.primary,
                    //   disabledForegroundColor: Theme.of(
                    //     context,
                    //   ).colorScheme.onPrimary,
                    //   disabledBackgroundColor: Theme.of(
                    //     context,
                    //   ).colorScheme.primary,
                    // ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Enter the target",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _setTarget,
                  child: const Text("Set target"),
                ),
              ],
            ),
            Row(
              children: [
                Spacer(),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  child: Column(
                    children: [Text("optimistic"), Text(lowIntercept)],
                  ),
                ),
                Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  child: Column(
                    children: [Text("most probable"), Text(medIntercept)],
                  ),
                ),
                Spacer(),
                Container(
                  decoration: BoxDecoration(
                    //color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  child: Column(
                    children: [Text("conservative"), Text(highIntercept)],
                  ),
                ),
                Spacer(),
              ],
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  //color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: buildChart(context),
              ),
            ),
            // List of points
            Expanded(
              child: ListView.builder(
                itemCount: controller.points.length,
                itemBuilder: (context, index) {
                  final point = controller.points[index]!;

                  return Dismissible(
                    key: Key(
                      point.value.toString() +
                          point.timestamp.millisecondsSinceEpoch
                              .toDouble()
                              .toString(),
                    ),
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
                                controller.addPoint(
                                  removedPoint.value,
                                  timestamp: removedPoint.timestamp,
                                );
                                controller.updateFit();
                                controller.saveCurrentDataset();
                              });
                            },
                          ),
                        ),
                      );
                      setState(() {
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
