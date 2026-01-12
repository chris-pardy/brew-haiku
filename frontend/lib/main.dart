import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/theme_exports.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BrewHaikuApp(),
    ),
  );
}

class BrewHaikuApp extends StatelessWidget {
  const BrewHaikuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brew Haiku',
      debugShowCheckedModeBanner: false,
      theme: BrewTheme.light(),
      darkTheme: BrewTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final haikuStyle = BrewTypography.haikuStyle(isDark: isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brew Haiku'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Steam rises slowly', style: haikuStyle),
            const SizedBox(height: 8),
            Text('Patience rewards the waiting', style: haikuStyle),
            const SizedBox(height: 8),
            Text('First sip, pure bliss', style: haikuStyle),
          ],
        ),
      ),
    );
  }
}
