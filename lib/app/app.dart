import 'package:flutter/material.dart';
import '../pages/start_page.dart';

class Plotter extends StatelessWidget {
  const Plotter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graph App',
      theme: ThemeData.dark(),
      home: const StartScreen(),
    );
  }
}