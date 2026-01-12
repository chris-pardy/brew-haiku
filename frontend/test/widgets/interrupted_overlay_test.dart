import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/widgets/interrupted_overlay.dart';
import 'package:brew_haiku/providers/focus_guard_provider.dart';

void main() {
  group('InterruptedOverlay', () {
    Widget createTestWidget({Widget? child}) {
      return ProviderScope(
        child: MaterialApp(
          home: InterruptedOverlay(
            child: child ?? const Scaffold(body: Text('Child Content')),
          ),
        ),
      );
    }

    testWidgets('shows child content when not interrupted', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Child Content'), findsOneWidget);
      expect(find.text('Ritual Interrupted'), findsNothing);
    });

    testWidgets('shows overlay when interrupted and active', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Get the focus guard notifier and activate + interrupt
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      expect(find.text('Ritual Interrupted'), findsOneWidget);
      expect(find.text('Return to Ritual'), findsOneWidget);
      expect(find.text('Long-press to return'), findsOneWidget);
    });

    testWidgets('does not show overlay when interrupted but not active', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      // Interrupt without activating
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      expect(find.text('Ritual Interrupted'), findsNothing);
    });

    testWidgets('shows time away display', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      expect(find.text('You were away for'), findsOneWidget);
      // Time display will show 00:00 or similar
      expect(find.textContaining(':'), findsWidgets);
    });

    testWidgets('shows interruption count when more than one', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();

      // First interruption
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      notifier.acknowledgeReturn();
      await tester.pump();

      // Second interruption
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();

      expect(find.text('2 interruptions this session'), findsOneWidget);
    });

    testWidgets('does not show count text for first interruption', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      expect(find.textContaining('interruptions this session'), findsNothing);
    });

    testWidgets('shows encouraging message', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      expect(find.text('The brew continues...'), findsOneWidget);
    });

    testWidgets('return button exists and is tappable area', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      final returnButton = find.text('Return to Ritual');
      expect(returnButton, findsOneWidget);

      // Verify it's inside a GestureDetector
      final gestureDetector = find.ancestor(
        of: returnButton,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsWidgets);
    });

    testWidgets('long press starts progress animation', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      final returnButton = find.text('Return to Ritual');

      // Start long press
      final gesture = await tester.startGesture(tester.getCenter(returnButton));
      await tester.pump(const Duration(milliseconds: 500));

      // Still in progress (not completed yet)
      expect(container.read(focusGuardProvider).isInterrupted, true);

      await gesture.up();
    });

    testWidgets('completed long press dismisses overlay', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();
      expect(container.read(focusGuardProvider).isInterrupted, true);

      final returnButton = find.text('Return to Ritual');

      // Start a long press gesture - need to hold past the long press duration
      final gesture = await tester.startGesture(tester.getCenter(returnButton));
      // Wait for GestureDetector's long press delay (default 500ms)
      await tester.pump(const Duration(milliseconds: 600));
      // Now pump animation frames over 2 seconds for the progress animation
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pump();

      // Should be dismissed
      expect(container.read(focusGuardProvider).isInterrupted, false);
      expect(find.text('Ritual Interrupted'), findsNothing);
    });

    testWidgets('cancelled long press does not dismiss overlay', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      final returnButton = find.text('Return to Ritual');

      // Start long press then release before completion
      final gesture = await tester.startGesture(tester.getCenter(returnButton));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();

      // Should still be interrupted
      expect(container.read(focusGuardProvider).isInterrupted, true);
      expect(find.text('Ritual Interrupted'), findsOneWidget);
    });

    testWidgets('uses BackdropFilter for blur effect', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterruptedOverlay)),
      );
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      await tester.pump();

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('FocusGuardWrapper', () {
    testWidgets('wraps child with InterruptedOverlay', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FocusGuardWrapper(
              child: Scaffold(body: Text('Wrapped Content')),
            ),
          ),
        ),
      );

      expect(find.text('Wrapped Content'), findsOneWidget);
      expect(find.byType(InterruptedOverlay), findsOneWidget);
    });
  });
}
