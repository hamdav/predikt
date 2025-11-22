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

class PlotScreen extends StatefulWidget {
  const PlotScreen({super.key});
  @override
  State<PlotScreen> createState() => _PlotScreenState();
}

class _PlotScreenState extends State<PlotScreen> {

  final TextEditingController _controller = TextEditingController();
  late Box<DataPoint> pointsBox;
  List<DataPoint> get points => pointsBox.values.toList();

  // Fitted line and confidence band
  List<FlSpot> medianLine = [];
  List<FlSpot> lowerBand = [];
  List<FlSpot> upperBand = [];

  @override
  void initState() {
    super.initState();
    pointsBox = Hive.box<DataPoint>('pointsBox');
    updateFitAndBand();
  }

  void _addValueNow() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;

    pointsBox.add(DataPoint(value: number, timestamp: DateTime.now()));
    _controller.clear();
    setState(() {
      updateFitAndBand();
    });
  }

  void _addValueWithPicker() async {
    final picked = await pickDateTime(context);
    if (picked == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final number = double.tryParse(text);
    if (number == null) return;

    pointsBox.add(DataPoint(value: number, timestamp: picked));
    _controller.clear();
    setState(() {
      updateFitAndBand();
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

  /// ------------------------------------------------------
  /// Compute fitted line and 95% confidence band using MCMC
  /// ------------------------------------------------------
  void updateFitAndBand() {
    if (points.length < 2) {
      medianLine = [];
      lowerBand = [];
      upperBand = [];
      return;
    }

    final xs = points
        .map((p) => p.timestamp.millisecondsSinceEpoch.toDouble() / 1000.0)
        .toList();
    final ys = points.map((p) => p.value).toList();

    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final rangeX = maxX - minX;
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final rangeY = maxY - minY;

    final x_norm = xs.map((x) => (x - minX) / rangeX).toList();
    final y_norm = ys.map((y) => (y - minY) / rangeY).toList();

    // Initial fit using deterministic method
    final initialFit = fitABC(x_norm, y_norm);

    // Run MCMC (stub function, replace with your own sampling)
    final samples = runMCMC(x_norm, y_norm,
        a0: initialFit.a, b0: initialFit.b, c0: initialFit.c, d0: initialFit.d, steps: 50000);

    const int curvePoints = 150;
    medianLine = [];
    lowerBand = [];
    upperBand = [];

    for (int i = 0; i < curvePoints; i++) {
      //final t = minX + (maxX - minX) * i / (curvePoints - 1);
      final tNorm = i / (curvePoints - 1);

      // compute y-values for each MCMC sample
      List<double> ySamples = samples.map((s) => model(tNorm, s.a, s.b, s.c, s.d)).toList()
        ..sort();
      //List<double> ySamples = samples.map((s) => model(tNorm, initialFit.a, initialFit.b, initialFit.c, initialFit.d)).toList()
         //..sort();

      final lowerIndex = (ySamples.length * 0.025).floor();
      final upperIndex = (ySamples.length * 0.975).floor();
      final medianIndex = ySamples.length ~/ 2;

      final t = minX + rangeX * tNorm;
      lowerBand.add(FlSpot(t, minY + rangeY * ySamples[lowerIndex]));
      upperBand.add(FlSpot(t, minY + rangeY * ySamples[upperIndex]));
      medianLine.add(FlSpot(t, minY + rangeY * ySamples[medianIndex]));
    }
  }

  List<FlSpot> get valueSpots {
    if (points.isEmpty) return [];
    final spots = points.map((p) {
      return FlSpot(
        p.timestamp.millisecondsSinceEpoch.toDouble() / 1000.0,
        p.value,
      );
    }).toList();
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  String formatTimestamp(double s) {
    final dt = DateTime.fromMillisecondsSinceEpoch(s.toInt() * 1000);
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}\n${dt.month}/${dt.day}";
  }

  Widget buildChart() {
    if (points.isEmpty) return const Center(child: Text("Chart will appear here"));

    final minX = valueSpots.first.x;
    final maxX = valueSpots.last.x;
    final minY = points.map((p) => p.value).reduce(math.min) - 1;
    final maxY = points.map((p) => p.value).reduce(math.max) + 1;

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
            spots: valueSpots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),

          // MEDIAN FITTED LINE
          LineChartBarData(
            spots: medianLine,
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),

          // CONFIDENCE BAND (shaded area)
          LineChartBarData(
            spots: lowerBand,
            isCurved: true,
            color: Colors.transparent,
            barWidth: 0,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: upperBand,
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
                    controller: _controller,
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
