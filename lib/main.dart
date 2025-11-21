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

  @override
  void initState() {
    super.initState();
    pointsBox = Hive.box<DataPoint>('pointsBox');
  }

  // Add now
  void _addValueNow() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final number = double.tryParse(text);
    if (number == null) return;

    pointsBox.add(DataPoint(value: number, timestamp: DateTime.now()));

    _controller.clear();
    setState(() {});
  }

  // Add with datetime picker
  void _addValueWithPicker() async {
    final picked = await pickDateTime(context);
    if (picked == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final number = double.tryParse(text);
    if (number == null) return;

    pointsBox.add(DataPoint(value: number, timestamp: picked));

    _controller.clear();
    setState(() {});
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

  List<FlSpot> get valueSpots {
    if (points.isEmpty) return [];

    final spots = points.map((p) {
      return FlSpot(
        p.timestamp.millisecondsSinceEpoch / 1000.0, // seconds
        p.value,
      );
    }).toList();

    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  List<FlSpot> buildFittedCurve() {
    if (points.length < 2) return [];

    final xs = tsNormalized;  // from your normalized timestamps
    final ys = values;

    // Use your previous fit as initial values:
    final initialFit = fitABC(xs, ys);

    // Run the MCMC
    final samples = runMCMC(
      xs,
      ys,
      a0: initialFit.a,
      b0: initialFit.b,
      c0: initialFit.c,
      steps: 5000,
    );

    // Compute means
    final meanA = samples.map((s) => s.a).reduce((a,b)=>a+b) / samples.length;
    final meanB = samples.map((s) => s.b).reduce((a,b)=>a+b) / samples.length;
    final meanC = samples.map((s) => s.c).reduce((a,b)=>a+b) / samples.length;

    print("Posterior means:");
    print("a = $meanA");
    print("b = $meanB");
    print("c = $meanC");

    // Convert to seconds
    final xsSec = points
        .map((p) => p.timestamp.millisecondsSinceEpoch / 1000.0)
        .toList();
    final ys = points.map((p) => p.value).toList();

    // Normalize time (important)
    final t0 = xsSec.first;
    final ts = xsSec.map((t) => t - t0).toList();

    final fit = fitABC(ts, ys);
    final a = fit.a, b = fit.b, c = fit.c;

    final minT = ts.reduce(math.min);
    final maxT = ts.reduce(math.max);

    const samples = 200;
    List<FlSpot> spots = [];

    for (int i = 0; i < samples; i++) {
      double tRel = minT + (maxT - minT) * i / (samples - 1);
      double y = model(tRel, a, b, c);
      double tAbs = tRel + t0; // un-normalize
      spots.add(FlSpot(tAbs, y));
    }

    return spots;
  }

  String formatTimestamp(double seconds) {
    final ms = (seconds * 1000).toInt();
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}\n${dt.month}/${dt.day}";
  }

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
              interval: (valueSpots.last.x - valueSpots.first.x) / 4,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  formatTimestamp(v),
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
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
          LineChartBarData(
            spots: valueSpots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
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
