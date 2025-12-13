import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: Center(
        child: Column(
          children: [
            Spacer(flex: 2),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.75,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: BoxBorder.all(color: colorScheme.primary),
                  ),

                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 50,
                  ),
                  child: Text(
                    "This is an app that helps you predict the future. Moreover, the app actually works! Granted, the predictions are not very grandiose, but they are accurate, and never better than the data you provide... Have fun :)\n\nCheers, David",
                  ),
                ),
              ),
            ),
            Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
