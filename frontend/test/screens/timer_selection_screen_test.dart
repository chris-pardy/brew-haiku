import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/screens/timer_selection_screen.dart';
import 'package:brew_haiku/data/default_timers.dart';
import 'package:brew_haiku/data/vessels.dart';
import 'package:brew_haiku/models/timer_model.dart';
import 'package:brew_haiku/theme/colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget({
    void Function(TimerModel)? onTimerSelected,
    void Function(Vessel)? onVesselSelected,
    VoidCallback? onCreateCustom,
    Brightness brightness = Brightness.light,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: TimerSelectionScreen(
          onTimerSelected: onTimerSelected,
          onVesselSelected: onVesselSelected,
          onCreateCustom: onCreateCustom,
        ),
      ),
    );
  }

  group('TimerSelectionScreen', () {
    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Start a Brew'), findsOneWidget);
    });

    testWidgets('displays Coffee and Tea tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
    });

    testWidgets('Coffee tab is selected by default', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should show coffee timers
      expect(find.text('Simple Pour Over'), findsOneWidget);
      // French Press appears in both timer card and vessel card
      expect(find.text('French Press'), findsWidgets);
    });

    testWidgets('can switch to Tea tab', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap Tea tab
      await tester.tap(find.text('Tea'));
      await tester.pumpAndSettle();

      // Should show tea timers
      expect(find.text('Green Tea'), findsOneWidget);
      expect(find.text('Black Tea'), findsOneWidget);
      expect(find.text('Gongfu Intro'), findsOneWidget);
    });

    testWidgets('displays Quick Start section', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Quick Start'), findsOneWidget);
      expect(find.text('Ready-to-use recipes'), findsOneWidget);
    });

    testWidgets('displays Choose a Vessel section', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Choose a Vessel'), findsOneWidget);
      expect(find.text('Start with a template'), findsOneWidget);
    });

    testWidgets('displays coffee vessels in Coffee tab', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Hario V60'), findsOneWidget);
      expect(find.text('Chemex'), findsOneWidget);
      expect(find.text('AeroPress'), findsOneWidget);
    });

    testWidgets('displays tea vessels in Tea tab', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Tea'));
      await tester.pumpAndSettle();

      expect(find.text('Gaiwan'), findsOneWidget);
      expect(find.text('Kyusu'), findsOneWidget);
    });

    testWidgets('calls onTimerSelected when timer card is tapped',
        (tester) async {
      TimerModel? selectedTimer;

      await tester.pumpWidget(createTestWidget(
        onTimerSelected: (timer) {
          selectedTimer = timer;
        },
      ));

      // Tap the Simple Pour Over timer
      await tester.tap(find.text('Simple Pour Over'));
      await tester.pumpAndSettle();

      expect(selectedTimer, isNotNull);
      expect(selectedTimer!.name, 'Simple Pour Over');
    });

    testWidgets('displays vessel section in coffee tab', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Choose a Vessel section header should be present
      expect(find.text('Choose a Vessel'), findsOneWidget);
    });

    testWidgets('displays FAB when onCreateCustom is provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        onCreateCustom: () {},
      ));

      expect(find.text('Custom Timer'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('hides FAB when onCreateCustom is null', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Custom Timer'), findsNothing);
    });

    testWidgets('calls onCreateCustom when FAB is tapped', (tester) async {
      bool customTapped = false;

      await tester.pumpWidget(createTestWidget(
        onCreateCustom: () {
          customTapped = true;
        },
      ));

      await tester.tap(find.text('Custom Timer'));
      await tester.pumpAndSettle();

      expect(customTapped, true);
    });

    testWidgets('uses light theme colors in light mode', (tester) async {
      await tester.pumpWidget(createTestWidget(brightness: Brightness.light));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, BrewColors.fogLight);
    });

    testWidgets('uses dark theme colors in dark mode', (tester) async {
      await tester.pumpWidget(createTestWidget(brightness: Brightness.dark));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, BrewColors.fogDark);
    });

    testWidgets('timer cards display ratio', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simple Pour Over has 16:1 ratio - there may be multiple on screen
      expect(find.text('16:1'), findsWidgets);
    });

    testWidgets('timer cards display duration', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Simple Pour Over is 3:00 - there may be multiple duration displays
      expect(find.textContaining('03:00'), findsWidgets);
    });
  });

  group('TimerCard', () {
    testWidgets('displays timer name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimerCard(
              timer: DefaultTimers.simplePourOver,
            ),
          ),
        ),
      );

      expect(find.text('Simple Pour Over'), findsOneWidget);
    });

    testWidgets('displays vessel and duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimerCard(
              timer: DefaultTimers.simplePourOver,
            ),
          ),
        ),
      );

      expect(find.textContaining('Generic'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimerCard(
              timer: DefaultTimers.simplePourOver,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TimerCard));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });
  });

  group('VesselCard', () {
    testWidgets('displays vessel name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: VesselCard(
                vessel: Vessels.harioV60,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hario V60'), findsOneWidget);
    });

    testWidgets('displays ratio and duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: VesselCard(
                vessel: Vessels.harioV60,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('16:1'), findsOneWidget);
    });

    testWidgets('displays description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: VesselCard(
                vessel: Vessels.harioV60,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('cone dripper'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: VesselCard(
                vessel: Vessels.harioV60,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(VesselCard));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('handles variable duration vessels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: VesselCard(
                vessel: Vessels.grandpaStyle,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Grandpa Style'), findsOneWidget);
      expect(find.textContaining('Variable'), findsOneWidget);
    });
  });
}
