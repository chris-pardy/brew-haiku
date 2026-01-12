import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/screens/splash_screen.dart';
import 'package:brew_haiku/theme/colors.dart';

void main() {
  // Initialize binding to prevent google_fonts issues
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen', () {
    testWidgets('displays app name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      // Let animation start
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Brew Haiku'), findsOneWidget);

      // Pump remaining duration to clear pending timer
      await tester.pumpAndSettle();
    });

    testWidgets('displays tagline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('mindful moments'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('displays logo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SplashLogo), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('calls onComplete after duration', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            duration: const Duration(milliseconds: 300),
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Before duration completes
      await tester.pump(const Duration(milliseconds: 100));
      expect(completed, false);

      // After duration completes
      await tester.pump(const Duration(milliseconds: 300));
      expect(completed, true);

      await tester.pumpAndSettle();
    });

    testWidgets('uses light theme colors in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const SplashScreen(
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      // Should use fogLight color (#FAF8F5)
      expect(scaffold.backgroundColor, BrewColors.fogLight);

      await tester.pumpAndSettle();
    });

    testWidgets('uses dark theme colors in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const SplashScreen(
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      // Should use fogDark color (#1A1612)
      expect(scaffold.backgroundColor, BrewColors.fogDark);

      await tester.pumpAndSettle();
    });

    testWidgets('animates on start', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            duration: Duration(milliseconds: 2000),
          ),
        ),
      );

      // At start
      await tester.pump();

      // Find FadeTransition
      final fadeFinder = find.byType(FadeTransition);
      expect(fadeFinder, findsWidgets);

      // Get the first FadeTransition (there may be multiple in the tree)
      final fadeTransition = tester.widget<FadeTransition>(fadeFinder.first);
      // Animation should be starting (opacity close to 0 or starting)
      expect(fadeTransition.opacity.value, lessThanOrEqualTo(1.0));

      // Pump more frames to let animation progress
      await tester.pump(const Duration(milliseconds: 800));

      final fadeTransitionAfter =
          tester.widget<FadeTransition>(fadeFinder.first);
      // Animation should have progressed
      expect(fadeTransitionAfter.opacity.value, greaterThan(0.5));

      // Complete timer
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('SplashLogo', () {
    testWidgets('renders with given size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SplashLogo(
                size: 100,
                color: Colors.brown,
              ),
            ),
          ),
        ),
      );

      // SplashLogo should be present
      expect(find.byType(SplashLogo), findsOneWidget);

      // The logo should render at the correct size
      final logoWidget = tester.widget<SplashLogo>(find.byType(SplashLogo));
      expect(logoWidget.size, 100);
    });

    testWidgets('renders with different sizes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SplashLogo(
                size: 200,
                color: Colors.brown,
              ),
            ),
          ),
        ),
      );

      final logoWidget = tester.widget<SplashLogo>(find.byType(SplashLogo));
      expect(logoWidget.size, 200);
    });

    testWidgets('accepts custom color', (tester) async {
      const testColor = Color(0xFF123456);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SplashLogo(
                size: 100,
                color: testColor,
              ),
            ),
          ),
        ),
      );

      final logoWidget = tester.widget<SplashLogo>(find.byType(SplashLogo));
      expect(logoWidget.color, testColor);
    });
  });

  group('SplashScreen customization', () {
    testWidgets('uses custom duration', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            duration: const Duration(milliseconds: 500),
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // At 200ms, should not be complete
      await tester.pump(const Duration(milliseconds: 200));
      expect(completed, false);

      // At 600ms, should be complete
      await tester.pump(const Duration(milliseconds: 400));
      expect(completed, true);

      await tester.pumpAndSettle();
    });

    testWidgets('handles no onComplete callback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            duration: Duration(milliseconds: 100),
          ),
        ),
      );

      // Should not throw when duration completes without callback
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('default duration is 2500ms', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // At 2000ms, should not be complete
      await tester.pump(const Duration(milliseconds: 2000));
      expect(completed, false);

      // At 2600ms, should be complete (default is 2500ms)
      await tester.pump(const Duration(milliseconds: 600));
      expect(completed, true);

      await tester.pumpAndSettle();
    });
  });
}
