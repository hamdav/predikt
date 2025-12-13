import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../logic/graph_controller.dart';
import '../logic/data.dart';

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
  bool _updatingFit = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _updatingFit = true);
    if (widget.datasetName == null) {
      // Automatically create a brand-new dataset
      // final newName = _generateDatasetName();
      final newName = "Autosave";
      controller.currentDatasetName = newName;
      //await controller.saveCurrentDataset(); // save empty dataset
    } else {
      // Load existing dataset
      await controller.loadDataset(widget.datasetName!);
      if (controller.target != null) {
        targetController.text = controller.target!.toString();
      }
    }
    await controller.updateFit();
    setState(() => _updatingFit = false);
  }

  String _generateDatasetName() {
    final now = DateTime.now();
    return 'Dataset_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}';
  }

  void _setTarget() async {
    setState(() => _updatingFit = true);
    //setState(() {});
    final text = targetController.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;
    controller.target = number;
    // targetController.clear();
    controller.saveCurrentDataset();
    await controller.updateFit();
    setState(() => _updatingFit = false);
  }

  String get fitFuncText =>
      controller.fitFunc == FitFunction.exponential ? 'exp' : 'lin';

  void _toggleFitFunc() async {
    setState(() => _updatingFit = true);
    switch (controller.fitFunc) {
      case FitFunction.exponential:
        controller.fitFunc = FitFunction.linear;
      case FitFunction.linear:
        controller.fitFunc = FitFunction.exponential;
    }
    controller.saveCurrentDataset();
    await controller.updateFit();

    setState(() => _updatingFit = false);
  }

  void _addValueNow() async {
    setState(() => _updatingFit = true);
    final text = valueController.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;

    controller.addPoint(number);
    valueController.clear();
    controller.saveCurrentDataset();
    await controller.updateFit();
    setState(() => _updatingFit = false);
  }

  void _addValueWithPicker() async {
    final picked = await pickDateTime(context);
    if (picked == null) return;

    final text = valueController.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;

    setState(() => _updatingFit = true);
    controller.addPoint(number, timestamp: picked);
    valueController.clear();
    controller.saveCurrentDataset();
    await controller.updateFit();
    setState(() => _updatingFit = false);
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
                if (newName != "") {
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
    final oldPoint = DataPoint(timestamp: point.timestamp, value: point.value);

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
                    //controller.saveCurrentDataset();
                    //await controller.updateFit();
                    //setState(() {});
                    //Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                point.timestamp = oldPoint.timestamp;
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text("Save"),
              onPressed: () async {
                final newVal = double.tryParse(valueController.text);
                if (newVal != null) {
                  setState(() => _updatingFit = true);
                  point.value = newVal;
                  Navigator.pop(context);
                  // await point.save();
                  controller.saveCurrentDataset();
                  await controller.updateFit();
                  setState(() => _updatingFit = false);
                }
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
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => colorScheme.surface.withAlpha(200),
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
      else if (controller.lowIntercept == null)
        lowIntercept = "Not enough data";
      else
        lowIntercept = formatTimestamp(controller.lowIntercept!);
      if (controller.medIntercept == double.infinity)
        medIntercept = "infinity";
      else if (controller.medIntercept == -double.infinity)
        medIntercept = "-infinity";
      else if (controller.medIntercept == null)
        medIntercept = "Not enough data";
      else
        medIntercept = formatTimestamp(controller.medIntercept!);
      if (controller.highIntercept == double.infinity)
        highIntercept = "infinity";
      else if (controller.highIntercept == -double.infinity)
        highIntercept = "-infinity";
      else if (controller.highIntercept == null)
        highIntercept = "Not enough data";
      else
        highIntercept = formatTimestamp(controller.highIntercept!);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // final textTheme = theme.textTheme;

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
                  onLongPress: _updatingFit ? null : _addValueWithPicker,
                  child: ElevatedButton(
                    onPressed: _updatingFit ? null : _addValueNow,
                    child: const Text("Add"),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _updatingFit ? null : _toggleFitFunc,
                  child: Text(fitFuncText),
                ),
                const SizedBox(width: 10),
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
                  onPressed: _updatingFit ? null : _setTarget,
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
                  final point = controller.points[index];

                  return Dismissible(
                    key: Key(
                      point.value.toString() +
                          point.timestamp.millisecondsSinceEpoch
                              .toDouble()
                              .toString(),
                    ),
                    background: Container(color: colorScheme.secondary),
                    onDismissed: (_) async {
                      // Remove the item from the data source immediately
                      final removedPoint = point;

                      // Optionally show a snackbar to undo
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Deleted ${removedPoint.value}"),
                          duration: Duration(seconds: 10),
                          persist: false,
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
                      controller.deletePoint(point);
                      controller.saveCurrentDataset();
                      await controller.updateFit();
                      setState(() {});
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
