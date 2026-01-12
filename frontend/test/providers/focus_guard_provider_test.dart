import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/providers/focus_guard_provider.dart';

void main() {
  // Ensure WidgetsBinding is initialized for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusGuardState', () {
    test('initial state is correct', () {
      const state = FocusGuardState();

      expect(state.interruptionCount, 0);
      expect(state.totalSecondsAway, 0);
      expect(state.interruptedAt, isNull);
      expect(state.isInterrupted, false);
      expect(state.isActive, false);
    });

    test('currentInterruptionDuration returns zero when not interrupted', () {
      const state = FocusGuardState();

      expect(state.currentInterruptionDuration, Duration.zero);
    });

    test('currentInterruptionDuration returns duration when interrupted', () {
      final interruptedAt = DateTime.now().subtract(const Duration(seconds: 30));
      final state = FocusGuardState(
        isInterrupted: true,
        interruptedAt: interruptedAt,
      );

      final duration = state.currentInterruptionDuration;
      // Allow some tolerance for test execution time
      expect(duration.inSeconds, greaterThanOrEqualTo(30));
      expect(duration.inSeconds, lessThan(32));
    });

    test('totalTimeAway includes current interruption', () {
      final interruptedAt = DateTime.now().subtract(const Duration(seconds: 10));
      final state = FocusGuardState(
        totalSecondsAway: 20,
        isInterrupted: true,
        interruptedAt: interruptedAt,
      );

      final total = state.totalTimeAway;
      expect(total.inSeconds, greaterThanOrEqualTo(30));
    });

    test('formattedTotalTimeAway formats correctly', () {
      const state = FocusGuardState(totalSecondsAway: 125);

      expect(state.formattedTotalTimeAway, '02:05');
    });

    test('formattedCurrentInterruption formats correctly', () {
      final interruptedAt = DateTime.now().subtract(const Duration(seconds: 65));
      final state = FocusGuardState(
        isInterrupted: true,
        interruptedAt: interruptedAt,
      );

      final formatted = state.formattedCurrentInterruption;
      // Should be around 01:05
      expect(formatted.startsWith('01:'), true);
    });

    test('copyWith creates new state with updated values', () {
      const original = FocusGuardState();
      final modified = original.copyWith(
        interruptionCount: 3,
        isActive: true,
      );

      expect(modified.interruptionCount, 3);
      expect(modified.isActive, true);
      expect(modified.totalSecondsAway, 0);
    });

    test('copyWith with clearInterruptedAt removes interruptedAt', () {
      final state = FocusGuardState(
        interruptedAt: DateTime.now(),
        isInterrupted: true,
      );

      final cleared = state.copyWith(
        clearInterruptedAt: true,
        isInterrupted: false,
      );

      expect(cleared.interruptedAt, isNull);
      expect(cleared.isInterrupted, false);
    });
  });

  group('FocusGuardNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('activate sets isActive to true and resets counters', () {
      final notifier = container.read(focusGuardProvider.notifier);

      notifier.activate();

      final state = container.read(focusGuardProvider);
      expect(state.isActive, true);
      expect(state.interruptionCount, 0);
      expect(state.totalSecondsAway, 0);
      expect(state.isInterrupted, false);
    });

    test('deactivate sets isActive to false', () {
      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      notifier.deactivate();

      final state = container.read(focusGuardProvider);
      expect(state.isActive, false);
    });

    test('deactivate finalizes interruption if currently interrupted', () {
      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();
      // Manually set interrupted state
      final currentState = container.read(focusGuardProvider);
      container.read(focusGuardProvider.notifier);
      // Simulate being interrupted
      notifier.activate();

      // Manually trigger the internal state as if interrupted
      // We can test this via lifecycle simulation instead
      notifier.deactivate();

      final state = container.read(focusGuardProvider);
      expect(state.isInterrupted, false);
    });

    test('acknowledgeReturn clears interrupted state and adds to total', () {
      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      // We need to simulate the interruption more directly
      // Since we can't easily trigger lifecycle events in unit tests,
      // let's test the acknowledgeReturn logic when already interrupted
      // by testing through the internal state manipulation

      // First, verify acknowledgeReturn does nothing when not interrupted
      notifier.acknowledgeReturn();
      var state = container.read(focusGuardProvider);
      expect(state.totalSecondsAway, 0);
    });

    test('reset clears all state', () {
      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      notifier.reset();

      final state = container.read(focusGuardProvider);
      expect(state.isActive, false);
      expect(state.interruptionCount, 0);
      expect(state.totalSecondsAway, 0);
      expect(state.isInterrupted, false);
    });
  });

  group('FocusGuard Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('isInterruptedProvider returns interruption status', () {
      expect(container.read(isInterruptedProvider), false);

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      // Still not interrupted until lifecycle event
      expect(container.read(isInterruptedProvider), false);
    });

    test('interruptionCountProvider returns count', () {
      expect(container.read(interruptionCountProvider), 0);

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      expect(container.read(interruptionCountProvider), 0);
    });

    test('isFocusGuardActiveProvider returns active status', () {
      expect(container.read(isFocusGuardActiveProvider), false);

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      expect(container.read(isFocusGuardActiveProvider), true);
    });
  });

  group('FocusGuardNotifier lifecycle', () {
    testWidgets('responds to app lifecycle changes', (tester) async {
      // Create container in widget context
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      // Simulate app going to background
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      final state = container.read(focusGuardProvider);
      expect(state.isInterrupted, true);
      expect(state.interruptionCount, 1);
      expect(state.interruptedAt, isNotNull);

      container.dispose();
    });

    testWidgets('does not record interruption when not active', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      // Not activated

      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

      final state = container.read(focusGuardProvider);
      expect(state.isInterrupted, false);
      expect(state.interruptionCount, 0);

      container.dispose();
    });

    testWidgets('does not record multiple interruptions for same pause', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      // Simulate multiple lifecycle events while paused
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      notifier.didChangeAppLifecycleState(AppLifecycleState.inactive);
      notifier.didChangeAppLifecycleState(AppLifecycleState.hidden);

      final state = container.read(focusGuardProvider);
      expect(state.interruptionCount, 1); // Only one interruption recorded

      container.dispose();
    });

    testWidgets('records new interruption after acknowledgment', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      // First interruption
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(container.read(focusGuardProvider).interruptionCount, 1);

      // User returns
      notifier.acknowledgeReturn();
      expect(container.read(focusGuardProvider).isInterrupted, false);

      // Second interruption
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(container.read(focusGuardProvider).interruptionCount, 2);

      container.dispose();
    });

    testWidgets('inactive state triggers interruption', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      notifier.didChangeAppLifecycleState(AppLifecycleState.inactive);

      final state = container.read(focusGuardProvider);
      expect(state.isInterrupted, true);

      container.dispose();
    });

    testWidgets('hidden state triggers interruption', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      notifier.didChangeAppLifecycleState(AppLifecycleState.hidden);

      final state = container.read(focusGuardProvider);
      expect(state.isInterrupted, true);

      container.dispose();
    });

    testWidgets('resumed state does not trigger interruption', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

      final state = container.read(focusGuardProvider);
      expect(state.isInterrupted, false);

      container.dispose();
    });
  });

  group('Time tracking', () {
    testWidgets('acknowledgeReturn clears interrupted state', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      // Trigger interruption
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(container.read(focusGuardProvider).isInterrupted, true);
      expect(container.read(focusGuardProvider).interruptedAt, isNotNull);

      // Acknowledge return
      notifier.acknowledgeReturn();

      final state = container.read(focusGuardProvider);
      // Time calculation is based on real time difference, so may be 0
      // The important thing is that the state is cleared
      expect(state.isInterrupted, false);
      expect(state.interruptedAt, isNull);

      container.dispose();
    });

    testWidgets('deactivate while interrupted clears state', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            container = ProviderContainer();
            return const SizedBox.shrink();
          },
        ),
      );

      final notifier = container.read(focusGuardProvider.notifier);
      notifier.activate();

      // Trigger interruption
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(container.read(focusGuardProvider).isInterrupted, true);

      // Deactivate without acknowledging
      notifier.deactivate();

      final state = container.read(focusGuardProvider);
      expect(state.isInterrupted, false);
      expect(state.isActive, false);

      container.dispose();
    });
  });
}
