import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/screens/brew_config_screen.dart';
import 'package:brew_haiku/models/timer_model.dart';
import 'package:brew_haiku/providers/timer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTimer = TimerModel(
    uri: 'at://did:plc:test/app.brew-haiku.timer/test1',
    did: 'did:plc:test',
    name: 'Test Pour Over',
    vessel: 'Hario V60',
    brewType: 'coffee',
    ratio: 16,
    steps: [
      const TimerStepModel(
        action: 'Bloom with 50ml water',
        stepType: 'timed',
        durationSeconds: 30,
      ),
      const TimerStepModel(
        action: 'Stir gently',
        stepType: 'indeterminate',
      ),
      const TimerStepModel(
        action: 'Pour remaining water',
        stepType: 'timed',
        durationSeconds: 150,
      ),
    ],
    saveCount: 10,
    createdAt: DateTime(2024, 1, 1),
  );

  final testTimerNoRatio = TimerModel(
    uri: 'at://did:plc:test/app.brew-haiku.timer/test2',
    did: 'did:plc:test',
    name: 'Grandpa Style Tea',
    vessel: 'Mug',
    brewType: 'tea',
    ratio: null,
    steps: [
      const TimerStepModel(
        action: 'Add leaves to cup',
        stepType: 'indeterminate',
      ),
      const TimerStepModel(
        action: 'Pour hot water',
        stepType: 'indeterminate',
      ),
    ],
    saveCount: 5,
    createdAt: DateTime(2024, 1, 1),
  );

  Widget createTestWidget({
    required TimerModel timer,
    void Function(CurrentBrew)? onStartBrew,
    VoidCallback? onBack,
    Brightness brightness = Brightness.light,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: BrewConfigScreen(
          timer: timer,
          onStartBrew: onStartBrew,
          onBack: onBack,
        ),
      ),
    );
  }

  group('BrewConfigScreen', () {
    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.text('Configure Brew'), findsOneWidget);
    });

    testWidgets('displays back button when onBack provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        onBack: () {},
      ));

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('calls onBack when back button tapped', (tester) async {
      bool backTapped = false;

      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        onBack: () {
          backTapped = true;
        },
      ));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(backTapped, true);
    });

    testWidgets('displays timer info card with name', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.text('Test Pour Over'), findsOneWidget);
    });

    testWidgets('displays timer vessel and duration', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.textContaining('Hario V60'), findsOneWidget);
      expect(find.textContaining('03:00'), findsOneWidget);
    });

    testWidgets('displays ratio badge', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.text('16:1'), findsOneWidget);
    });

    testWidgets('displays coffee icon for coffee timers', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.byIcon(Icons.coffee_outlined), findsOneWidget);
    });

    testWidgets('displays tea icon for tea timers', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimerNoRatio));

      expect(find.byIcon(Icons.emoji_food_beverage_outlined), findsOneWidget);
    });

    testWidgets('displays ratio calculator section when timer has ratio',
        (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.text('Ratio Calculator'), findsOneWidget);
      expect(find.text('Water (ml) = Dry (g) × Ratio'), findsOneWidget);
    });

    testWidgets('hides ratio calculator when timer has no ratio',
        (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimerNoRatio));

      expect(find.text('Ratio Calculator'), findsNothing);
    });

    testWidgets('displays dry weight input field', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.text('Dry Weight'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
    });

    testWidgets('displays ratio input field', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Ratio label appears in section subtitle and input label
      expect(find.text('Ratio'), findsWidgets);
      expect(find.text(':1'), findsOneWidget);
    });

    testWidgets('displays water weight field', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Water appears in section subtitle and input label
      expect(find.textContaining('Water'), findsWidgets);
      expect(find.text('ml'), findsOneWidget);
    });

    testWidgets('calculates water from dry weight and ratio', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Find dry weight TextFormField by looking for the one with 'g' suffix
      final dryWeightFields = find.byType(TextFormField);
      // First TextFormField is dry weight
      await tester.enterText(dryWeightFields.first, '15');
      await tester.pumpAndSettle();

      // Should calculate: 15 * 16 = 240
      expect(find.text('240'), findsOneWidget);
    });

    testWidgets('updates water when ratio changes', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      final textFields = find.byType(TextFormField);
      // Enter dry weight first (first field)
      await tester.enterText(textFields.first, '20');
      await tester.pumpAndSettle();

      // Should calculate: 20 * 16 = 320
      expect(find.text('320'), findsOneWidget);

      // Change ratio (second field)
      await tester.enterText(textFields.at(1), '15');
      await tester.pumpAndSettle();

      // Should calculate: 20 * 15 = 300
      expect(find.text('300'), findsOneWidget);
    });

    testWidgets('displays brew steps section', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Scroll to see steps section
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('Brew Steps'), findsOneWidget);
      expect(find.textContaining('3 steps'), findsOneWidget);
    });

    testWidgets('displays all step actions', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Scroll to see steps
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Bloom with 50ml water'), findsOneWidget);
      expect(find.text('Stir gently'), findsOneWidget);
      expect(find.text('Pour remaining water'), findsOneWidget);
    });

    testWidgets('displays step numbers', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Scroll to see steps
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('displays timed step durations', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Scroll to see steps
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Bloom step: 30 seconds
      expect(find.text('00:30'), findsOneWidget);
      // Pour step: 150 seconds = 02:30
      expect(find.text('02:30'), findsOneWidget);
    });

    testWidgets('displays Manual indicator for indeterminate steps',
        (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      // Scroll to see steps
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Manual'), findsOneWidget);
    });

    testWidgets('displays Start Brew button', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      expect(find.text('Start Brew'), findsOneWidget);
    });

    testWidgets('calls onStartBrew when button tapped', (tester) async {
      CurrentBrew? receivedBrew;

      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        onStartBrew: (brew) {
          receivedBrew = brew;
        },
      ));

      await tester.tap(find.text('Start Brew'));
      await tester.pumpAndSettle();

      expect(receivedBrew, isNotNull);
      expect(receivedBrew!.timer, testTimer);
    });

    testWidgets('passes dry weight to brew when starting', (tester) async {
      CurrentBrew? receivedBrew;

      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        onStartBrew: (brew) {
          receivedBrew = brew;
        },
      ));

      // Enter dry weight (first TextFormField)
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '18');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Brew'));
      await tester.pumpAndSettle();

      expect(receivedBrew!.dryWeight, 18.0);
    });

    testWidgets('passes water weight to brew when starting', (tester) async {
      CurrentBrew? receivedBrew;

      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        onStartBrew: (brew) {
          receivedBrew = brew;
        },
      ));

      // Enter dry weight (water calculated automatically)
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '15');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Brew'));
      await tester.pumpAndSettle();

      expect(receivedBrew!.waterWeight, 240.0); // 15 * 16
    });

    testWidgets('uses dark theme colors in dark mode', (tester) async {
      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        brightness: Brightness.dark,
      ));

      // Just verify it builds without error
      expect(find.text('Configure Brew'), findsOneWidget);
    });

    testWidgets('shows reset button when custom water entered', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      final textFields = find.byType(TextFormField);
      // First enter dry weight (first field)
      await tester.enterText(textFields.first, '15');
      await tester.pumpAndSettle();

      // Then manually edit water (third field)
      await tester.enterText(textFields.at(2), '250');
      await tester.pumpAndSettle();

      // Reset button should appear
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('reset button restores calculated water', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      final textFields = find.byType(TextFormField);
      // Enter dry weight (first field)
      await tester.enterText(textFields.first, '15');
      await tester.pumpAndSettle();

      // Manual water entry (third field)
      await tester.enterText(textFields.at(2), '999');
      await tester.pumpAndSettle();

      // Tap reset
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Should show calculated value: 15 * 16 = 240
      expect(find.text('240'), findsOneWidget);
      expect(find.text('Reset'), findsNothing);
    });
  });

  group('RatioCalculator standalone widget', () {
    testWidgets('displays with initial values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RatioCalculator(
                initialRatio: 15,
                initialDryWeight: 20,
              ),
            ),
          ),
        ),
      );

      // Check initial values are set - TextFormField values
      // Verify widget built successfully
      expect(find.byType(RatioCalculator), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
    });

    testWidgets('calls callbacks on value changes', (tester) async {
      double? dryWeight;
      double? waterWeight;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RatioCalculator(
                initialRatio: 16,
                onDryWeightChanged: (v) => dryWeight = v,
                onWaterWeightChanged: (v) => waterWeight = v,
              ),
            ),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '10');
      await tester.pumpAndSettle();

      expect(dryWeight, 10.0);
      expect(waterWeight, 160.0); // 10 * 16
    });
  });

  group('Input validation', () {
    testWidgets('accepts numeric input', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '15');
      await tester.pumpAndSettle();

      final textField = tester.widget<TextFormField>(textFields.first);
      expect(textField.controller?.text, '15');
    });

    testWidgets('allows decimal input', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '15.5');
      await tester.pumpAndSettle();

      final textField = tester.widget<TextFormField>(textFields.first);
      expect(textField.controller?.text, '15.5');
    });
  });
}
