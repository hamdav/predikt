import 'package:flutter/material.dart';
import 'graph_page.dart';
import 'dataset_selection_page.dart';
import 'about_page.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      //appBar: AppBar(title: const Text("Start")),
      body: Center(
        child: Column(
          children: [
            Spacer(flex: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),

              child: Image.asset(
                'assets/images/start_page_icon.png',
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            Spacer(),
            Text(
              "Predikt",
              style: textTheme.displayLarge?.copyWith(
                color: colorScheme.secondary,
              ),
            ),
            Spacer(),
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
                  MaterialPageRoute(builder: (_) => const AboutPage()),
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
