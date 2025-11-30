import 'package:flutter/material.dart';
import 'graph_page.dart';
import 'dataset_selection_page.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Start")),
      body: Center(
        child: Column(
          children: [
            Spacer(flex: 3),
            ElevatedButton(
              child: const Text("New data series"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GraphPage()),
                );
              },
            ),
            Spacer(),
            ElevatedButton(
              child: const Text("Load data series"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DatasetSelectorPage(),
                  ),
                );
              },
            ),
            Spacer(),
            ElevatedButton(
              child: const Text("About"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DatasetSelectorPage(),
                  ),
                );
              },
            ),
            Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
