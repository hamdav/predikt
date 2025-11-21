import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:hive_flutter/hive_flutter.dart';
import 'data_point.dart';
import 'fitting.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(DataPointAdapter());

  await Hive.openBox<DataPoint>('pointsBox');

  runApp(const NumberPlotApp());
}

class NumberPlotApp extends StatelessWidget {
  const NumberPlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Datetime Plot App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const StartScreen(),
    );
  }
}

// ------------------------------------------------------
// START SCREEN
// ------------------------------------------------------
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Start")),
      body: Center(
        child: ElevatedButton(
          child: const Text("Go to Plot Screen"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlotScreen()),
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------
// PLOT SCREEN
// ------------------------------------------------------
class PlotScreen extends StatefulWidget {
  const PlotScreen({super.key});

  @override
  State<PlotScreen> createState() => _PlotScreenState();
}

class _PlotScreenState extends State<PlotScreen> {
  final TextEditingController _controller = TextEditingController();
  late Box<DataPoint> pointsBox;

  List<DataPoint> get points => pointsBox.values.toList();

    @override
    void initState() {
        super.initState();              // Always call super.initState() first
        pointsBox = Hive.box<DataPoint>('pointsBox'); // Initialize your Hive box
    }

  // ------------------------------------------------------
  // Add NOW
  // ------------------------------------------------------
    void _addValueNow() {
      final text = _controller.text.trim();
      if (text.isEmpty) return;

      final number = double.tryParse(text);
      if (number == null) return;

      pointsBox.add(
        DataPoint(value: number, timestamp: DateTime.now()),
      );

      _controller.clear();
      setState(() {});
    }

  // ------------------------------------------------------
  // Add with datetime picker
  // ------------------------------------------------------
    void _addValueWithPicker() async {
      final picked = await pickDateTime(context);
      if (picked == null) return;

      final text = _controller.text.trim();
      if (text.isEmpty) return;

      final number = double.tryParse(text);
      if (number == null) return;

      pointsBox.add(
        DataPoint(value: number, timestamp: picked),
      );

      _controller.clear();
      setState(() {});
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
                      await point.save();
                      setState(() {});
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
                    await point.save();
                    setState(() {});
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    }
  // ------------------------------------------------------
  // Datetime Picker Helper
  // ------------------------------------------------------
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

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  // ------------------------------------------------------
  // Convert points → FlSpots
  // ------------------------------------------------------
  List<FlSpot> get valueSpots {
    if (points.isEmpty) return [];

    final spots = points.map((p) {
      return FlSpot(
        p.timestamp.millisecondsSinceEpoch.toDouble(),
        p.value,
      );
    }).toList();

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  // ------------------------------------------------------
  // Compute TRENDLINE using linear regression on timestamps
  // ------------------------------------------------------
  List<FlSpot> buildFittedCurve() {
  if (points.length < 2) return [];

  // convert to seconds
  final xsAbs = points
      .map((p) => p.timestamp.millisecondsSinceEpoch / 1000.0)
      .toList();
  final ys = points.map((p) => p.value).toList();

  // fit using absolute time (b fits correctly)
  final fit = fitABC(xsAbs, ys);
  final a = fit.a;
  final b = fit.b;
  final c = fit.c;

  final minX = xsAbs.reduce(math.min);
  final maxX = xsAbs.reduce(math.max);

  const samples = 200;
  List<FlSpot> spots = [];

  for (int i = 0; i < samples; i++) {
    double t = minX + (maxX - minX) * i / (samples - 1);
    double y = model(t, a, b, c);
    spots.add(FlSpot(t, y));
  }

  return spots;
}
  // ------------------------------------------------------
  // Formatter for datetime axis labels
  // ------------------------------------------------------
  String formatTimestamp(double ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}\n${dt.month}/${dt.day}";
  }

  // ------------------------------------------------------
  // Build CHART widget
  // ------------------------------------------------------
  Widget buildChart() {
    if (points.isEmpty) {
      return const Center(child: Text("Chart will appear here"));
    }

    return LineChart(
      LineChartData(
        minX: valueSpots.first.x,
        maxX: valueSpots.last.x,
        minY: points.map((p) => p.value).reduce(math.min) - 1,
        maxY: points.map((p) => p.value).reduce(math.max) + 1,

        gridData: const FlGridData(show: true),

        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (valueSpots.last.x - valueSpots.first.x) == 0
                ? 1  // fallback interval
                : (valueSpots.last.x - valueSpots.first.x) / 4,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    formatTimestamp(value),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),

        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(width: 2),
            bottom: BorderSide(width: 2),
          ),
        ),

        lineBarsData: [
          // USER DATA
          LineChartBarData(
            spots: valueSpots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
          // TRENDLINE
            LineChartBarData(
              spots: buildFittedCurve(),
              isCurved: true,
              color: Colors.red,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // UI
  // ------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plot Values")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // INPUT AREA
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Enter a number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // TAP = add now
                // LONG PRESS = pick datetime
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

            // CHART
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
            Expanded(
              child: ListView.builder(
                itemCount: pointsBox.length,
                itemBuilder: (context, index) {
                  final point = pointsBox.getAt(index)!;

                  return Dismissible(
                    key: Key(point.key.toString()),
                    background: Container(color: Colors.red),
                    onDismissed: (_) {
                      pointsBox.deleteAt(index);
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

