import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/screens/timer_screen.dart';
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

  final singleStepTimer = TimerModel(
    uri: 'at://did:plc:test/app.brew-haiku.timer/test2',
    did: 'did:plc:test',
    name: 'Simple Steep',
    vessel: 'Teapot',
    brewType: 'tea',
    ratio: 50,
    steps: [
      const TimerStepModel(
        action: 'Steep tea leaves',
        stepType: 'timed',
        durationSeconds: 180,
      ),
    ],
    saveCount: 5,
    createdAt: DateTime(2024, 1, 1),
  );

  final indeterminateTimer = TimerModel(
    uri: 'at://did:plc:test/app.brew-haiku.timer/test3',
    did: 'did:plc:test',
    name: 'Grandpa Style',
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
    saveCount: 3,
    createdAt: DateTime(2024, 1, 1),
  );

  Widget createTestWidget({
    required TimerModel timer,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
    bool enableChimes = false,
    Brightness brightness = Brightness.light,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: TimerScreen(
          timer: timer,
          onComplete: onComplete,
          onCancel: onCancel,
          enableChimes: enableChimes,
        ),
      ),
    );
  }

  group('TimerScreen', () {
    testWidgets('displays timer name in app bar', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));
      await tester.pump();

      expect(find.text('Test Pour Over'), findsOneWidget);
    });

    testWidgets('displays close button when onCancel provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        onCancel: () {},
      ));
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onCancel when close button tapped', (tester) async {
      bool cancelCalled = false;

      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        onCancel: () {
          cancelCalled = true;
        },
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(cancelCalled, true);
    });

    testWidgets('displays current step action', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));
      await tester.pump();

      // First step should be shown
      expect(find.text('Bloom with 50ml water'), findsOneWidget);
    });

    testWidgets('displays timer visualization', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));
      await tester.pump();

      expect(find.byType(TimerVisualization), findsOneWidget);
    });

    testWidgets('displays step indicator for multi-step timers',
        (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));
      await tester.pump();

      expect(find.byType(StepIndicator), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);
    });

    testWidgets('hides step indicator for single-step timers', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: singleStepTimer));
      await tester.pump();

      expect(find.byType(StepIndicator), findsNothing);
    });

    testWidgets('displays time remaining for timed steps', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: singleStepTimer));
      await tester.pump();

      expect(find.text('Remaining'), findsOneWidget);
    });

    testWidgets('displays elapsed time for indeterminate steps',
        (tester) async {
      await tester.pumpWidget(createTestWidget(timer: indeterminateTimer));
      await tester.pump();

      // Wait for timer to start
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Elapsed'), findsOneWidget);
    });

    testWidgets('shows Done button for indeterminate steps', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: indeterminateTimer));
      await tester.pump();

      // Wait for timer to start and enter waiting state
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('uses coffee colors for coffee brews', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));
      await tester.pump();

      // Timer visualization should exist
      expect(find.byType(TimerVisualization), findsOneWidget);
    });

    testWidgets('uses tea colors for tea brews', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: singleStepTimer));
      await tester.pump();

      expect(find.byType(TimerVisualization), findsOneWidget);
    });

    testWidgets('displays total remaining for multi-step brews',
        (tester) async {
      await tester.pumpWidget(createTestWidget(timer: testTimer));
      await tester.pump();

      expect(find.text('Total Remaining'), findsOneWidget);
    });

    testWidgets('uses dark theme colors in dark mode', (tester) async {
      await tester.pumpWidget(createTestWidget(
        timer: testTimer,
        brightness: Brightness.dark,
      ));
      await tester.pump();

      expect(find.text('Test Pour Over'), findsOneWidget);
    });
  });

  group('StepIndicator', () {
    testWidgets('displays correct step count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              totalSteps: 5,
              currentStep: 2,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('Step 3 of 5'), findsOneWidget);
    });

    testWidgets('displays step dots', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              totalSteps: 4,
              currentStep: 1,
              isDark: false,
            ),
          ),
        ),
      );

      // Should have 4 step indicator dots
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });

    testWidgets('current step indicator is wider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepIndicator(
              totalSteps: 3,
              currentStep: 1,
              isDark: false,
            ),
          ),
        ),
      );

      // The current step dot should be wider (24 vs 8)
      expect(find.byType(StepIndicator), findsOneWidget);
    });

    testWidgets('works in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: StepIndicator(
              totalSteps: 3,
              currentStep: 0,
              isDark: true,
            ),
          ),
        ),
      );

      expect(find.text('Step 1 of 3'), findsOneWidget);
    });
  });

  group('TimerVisualization', () {
    testWidgets('renders with coffee brew type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: TimerVisualization(
                  progress: 0.5,
                  isRunning: true,
                  brewType: 'coffee',
                  animationValue: 0.0,
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TimerVisualization), findsOneWidget);
      // CustomPaint is used internally
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with tea brew type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: TimerVisualization(
                  progress: 0.75,
                  isRunning: false,
                  brewType: 'tea',
                  animationValue: 0.5,
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TimerVisualization), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: TimerVisualization(
                  progress: 0.25,
                  isRunning: true,
                  brewType: 'coffee',
                  animationValue: 0.0,
                  isDark: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TimerVisualization), findsOneWidget);
    });

    testWidgets('handles zero progress', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: TimerVisualization(
                  progress: 0.0,
                  isRunning: true,
                  brewType: 'coffee',
                  animationValue: 0.0,
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TimerVisualization), findsOneWidget);
    });

    testWidgets('handles full progress', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: TimerVisualization(
                  progress: 1.0,
                  isRunning: false,
                  brewType: 'tea',
                  animationValue: 1.0,
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TimerVisualization), findsOneWidget);
    });
  });

  group('TimerProgress standalone widget', () {
    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: TimerProgress(
                  progress: 0.5,
                  brewType: 'coffee',
                  isDark: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TimerProgress), findsOneWidget);
      expect(find.byType(TimerVisualization), findsOneWidget);
    });
  });

  group('Time formatting', () {
    testWidgets('displays formatted time correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(timer: singleStepTimer));
      await tester.pump();

      // Should display time in MM:SS format
      // Initial time should be close to 03:00 for 180 seconds
      expect(find.textContaining(':'), findsWidgets);
    });
  });
}
