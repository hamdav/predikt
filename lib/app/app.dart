import 'package:flutter/material.dart';
import '../pages/start_page.dart';

class Plotter extends StatelessWidget {
  const Plotter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graph App',
      theme: ThemeData(
        colorScheme: ColorScheme(
          surface: Color.fromARGB(255, 20, 2, 15),
          onSurface: const Color.fromARGB(255, 202, 182, 255),
          surfaceContainerLow: Color.fromARGB(255, 53, 24, 73),
          surfaceContainerHigh: Color.fromARGB(255, 99, 45, 136),
          primaryContainer: Colors.deepPurple,
          onPrimaryContainer: Colors.white,
          primary: const Color.fromARGB(255, 170, 139, 255),
          onPrimary: Color.fromARGB(255, 20, 2, 15),
          secondary: const Color.fromARGB(255, 255, 111, 67),
          onSecondary: Color.fromARGB(255, 20, 2, 15),
          tertiary: const Color.fromARGB(255, 74, 206, 79),
          onTertiary: Color.fromARGB(255, 20, 2, 15),
          brightness: Brightness.dark,
          error: Colors.red,
          onError: Colors.black,
        ),
      ),
      home: const StartScreen(),
    );
  }
}
