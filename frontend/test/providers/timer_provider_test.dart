import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/providers/timer_provider.dart';
import 'package:brew_haiku/models/timer_model.dart';

void main() {
  group('TimerStep', () {
    test('creates timed step correctly', () {
      const step = TimerStep(
        action: 'Bloom',
        stepType: StepType.timed,
        durationSeconds: 30,
      );

      expect(step.action, 'Bloom');
      expect(step.stepType, StepType.timed);
      expect(step.durationSeconds, 30);
    });

    test('creates indeterminate step correctly', () {
      const step = TimerStep(
        action: 'Wait for drain',
        stepType: StepType.indeterminate,
      );

      expect(step.action, 'Wait for drain');
      expect(step.stepType, StepType.indeterminate);
      expect(step.durationSeconds, isNull);
    });

    test('fromModel creates step from TimerStepModel', () {
      const model = TimerStepModel(
        action: 'Pour water',
        stepType: 'timed',
        durationSeconds: 60,
      );

      final step = TimerStep.fromModel(model);

      expect(step.action, 'Pour water');
      expect(step.stepType, StepType.timed);
      expect(step.durationSeconds, 60);
    });

    test('fromModel handles indeterminate type', () {
      const model = TimerStepModel(
        action: 'Heat water',
        stepType: 'indeterminate',
      );

      final step = TimerStep.fromModel(model);

      expect(step.stepType, StepType.indeterminate);
    });

    test('copyWith creates new instance', () {
      const step = TimerStep(
        action: 'Bloom',
        stepType: StepType.timed,
        durationSeconds: 30,
      );

      final modified = step.copyWith(durationSeconds: 45);

      expect(modified.action, 'Bloom');
      expect(modified.durationSeconds, 45);
      expect(step.durationSeconds, 30); // Original unchanged
    });
  });

  group('TimerState', () {
    test('initial state is correct', () {
      const state = TimerState();

      expect(state.status, TimerStatus.notStarted);
      expect(state.currentStepIndex, 0);
      expect(state.elapsedSeconds, 0);
      expect(state.steps, isEmpty);
      expect(state.autoAdvance, true);
    });

    test('currentStep returns correct step', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 30),
        TimerStep(action: 'Step 2', stepType: StepType.timed, durationSeconds: 60),
      ];
      const state = TimerState(steps: steps, currentStepIndex: 1);

      expect(state.currentStep?.action, 'Step 2');
    });

    test('currentStep returns null when out of bounds', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 30),
      ];
      const state = TimerState(steps: steps, currentStepIndex: 5);

      expect(state.currentStep, isNull);
    });

    test('remainingSeconds calculates correctly', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 60),
      ];
      const state = TimerState(steps: steps, elapsedSeconds: 25);

      expect(state.remainingSeconds, 35);
    });

    test('remainingSeconds returns 0 for indeterminate', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.indeterminate),
      ];
      const state = TimerState(steps: steps);

      expect(state.remainingSeconds, 0);
    });

    test('stepProgress calculates correctly', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 100),
      ];
      const state = TimerState(steps: steps, elapsedSeconds: 50);

      expect(state.stepProgress, 0.5);
    });

    test('stepProgress is 0 for indeterminate steps', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.indeterminate),
      ];
      const state = TimerState(steps: steps);

      expect(state.stepProgress, 0.0);
    });

    test('stepProgress caps at 1.0', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 10),
      ];
      const state = TimerState(steps: steps, elapsedSeconds: 15);

      expect(state.stepProgress, 1.0);
    });

    test('totalTimedDuration sums all timed steps', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 30),
        TimerStep(action: 'Step 2', stepType: StepType.indeterminate),
        TimerStep(action: 'Step 3', stepType: StepType.timed, durationSeconds: 60),
      ];
      const state = TimerState(steps: steps);

      expect(state.totalTimedDuration, 90);
    });

    test('overallProgress calculates correctly', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 50),
        TimerStep(action: 'Step 2', stepType: StepType.timed, durationSeconds: 50),
      ];
      // On second step with 25 elapsed = 75 total elapsed out of 100
      const state = TimerState(
        steps: steps,
        currentStepIndex: 1,
        elapsedSeconds: 25,
      );

      expect(state.overallProgress, 0.75);
    });

    test('isLastStep returns true for last step', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 30),
        TimerStep(action: 'Step 2', stepType: StepType.timed, durationSeconds: 30),
      ];
      const state = TimerState(steps: steps, currentStepIndex: 1);

      expect(state.isLastStep, true);
    });

    test('formattedRemaining formats correctly', () {
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 125),
      ];
      const state = TimerState(steps: steps, elapsedSeconds: 0);

      expect(state.formattedRemaining, '02:05');
    });

    test('formattedTotalElapsed formats correctly', () {
      const state = TimerState(totalElapsedSeconds: 185);

      expect(state.formattedTotalElapsed, '03:05');
    });
  });

  group('TimerNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initialize sets steps', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Bloom', stepType: StepType.timed, durationSeconds: 30),
        TimerStep(action: 'Pour', stepType: StepType.timed, durationSeconds: 90),
      ];

      notifier.initialize(steps);

      final state = container.read(timerStateProvider);
      expect(state.steps.length, 2);
      expect(state.status, TimerStatus.notStarted);
    });

    test('initializeFromModel creates steps from model', () {
      final notifier = container.read(timerStateProvider.notifier);
      final timer = TimerModel(
        uri: 'test://timer',
        did: 'did:test',
        name: 'Test Timer',
        vessel: 'V60',
        brewType: 'coffee',
        saveCount: 0,
        createdAt: DateTime.now(),
        steps: const [
          TimerStepModel(action: 'Bloom', stepType: 'timed', durationSeconds: 30),
          TimerStepModel(action: 'Pour', stepType: 'timed', durationSeconds: 90),
        ],
      );

      notifier.initializeFromModel(timer);

      final state = container.read(timerStateProvider);
      expect(state.steps.length, 2);
      expect(state.steps[0].action, 'Bloom');
    });

    test('start changes status to running for timed step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Bloom', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);

      notifier.start();

      final state = container.read(timerStateProvider);
      expect(state.status, TimerStatus.running);
      expect(state.startedAt, isNotNull);
    });

    test('start sets waitingForUser for indeterminate first step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Heat water', stepType: StepType.indeterminate),
        TimerStep(action: 'Pour', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);

      notifier.start();

      final state = container.read(timerStateProvider);
      expect(state.status, TimerStatus.waitingForUser);
    });

    test('start does nothing when no steps', () {
      final notifier = container.read(timerStateProvider.notifier);

      notifier.start();

      final state = container.read(timerStateProvider);
      expect(state.status, TimerStatus.notStarted);
    });

    test('start does nothing when already running', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Bloom', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);
      notifier.start();
      final startedAt = container.read(timerStateProvider).startedAt;

      notifier.start(); // Call again

      final state = container.read(timerStateProvider);
      expect(state.startedAt, startedAt); // Same startedAt
    });

    test('advanceStep moves to next step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 10),
        TimerStep(action: 'Step 2', stepType: StepType.timed, durationSeconds: 20),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.advanceStep();

      final state = container.read(timerStateProvider);
      expect(state.currentStepIndex, 1);
      expect(state.elapsedSeconds, 0);
      expect(state.status, TimerStatus.running);
    });

    test('advanceStep completes when on last step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Only step', stepType: StepType.timed, durationSeconds: 10),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.advanceStep();

      final state = container.read(timerStateProvider);
      expect(state.status, TimerStatus.completed);
      expect(state.completedAt, isNotNull);
    });

    test('advanceStep sets waitingForUser for indeterminate next step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 10),
        TimerStep(action: 'Step 2', stepType: StepType.indeterminate),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.advanceStep();

      final state = container.read(timerStateProvider);
      expect(state.status, TimerStatus.waitingForUser);
    });

    test('completeIndeterminateStep advances from indeterminate', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Wait', stepType: StepType.indeterminate),
        TimerStep(action: 'Pour', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.completeIndeterminateStep();

      final state = container.read(timerStateProvider);
      expect(state.currentStepIndex, 1);
      expect(state.status, TimerStatus.running);
    });

    test('completeIndeterminateStep does nothing for timed step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Pour', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.completeIndeterminateStep();

      final state = container.read(timerStateProvider);
      expect(state.currentStepIndex, 0); // Unchanged
    });

    test('reset returns to initial state with same steps', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 10),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.reset();

      final state = container.read(timerStateProvider);
      expect(state.status, TimerStatus.notStarted);
      expect(state.elapsedSeconds, 0);
      expect(state.steps.length, 1);
      expect(state.startedAt, isNull);
    });

    test('skipToStep jumps to specific step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 10),
        TimerStep(action: 'Step 2', stepType: StepType.timed, durationSeconds: 20),
        TimerStep(action: 'Step 3', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.skipToStep(2);

      final state = container.read(timerStateProvider);
      expect(state.currentStepIndex, 2);
      expect(state.elapsedSeconds, 0);
    });

    test('skipToStep ignores invalid index', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Step 1', stepType: StepType.timed, durationSeconds: 10),
      ];
      notifier.initialize(steps);
      notifier.start();

      notifier.skipToStep(5);

      final state = container.read(timerStateProvider);
      expect(state.currentStepIndex, 0); // Unchanged
    });
  });

  group('CurrentBrew', () {
    test('initial state has no timer', () {
      const brew = CurrentBrew();

      expect(brew.hasTimer, false);
      expect(brew.timer, isNull);
      expect(brew.dryWeight, isNull);
      expect(brew.waterWeight, isNull);
    });

    test('calculatedWaterWeight uses ratio', () {
      final brew = CurrentBrew(
        timer: TimerModel(
          uri: 'test://timer',
          did: 'did:test',
          name: 'Test',
          vessel: 'V60',
          brewType: 'coffee',
          ratio: 16.0,
          saveCount: 0,
          createdAt: DateTime.now(),
          steps: const [],
        ),
        dryWeight: 20.0,
      );

      expect(brew.calculatedWaterWeight, 320.0);
    });

    test('calculatedWaterWeight returns null without ratio', () {
      final brew = CurrentBrew(
        timer: TimerModel(
          uri: 'test://timer',
          did: 'did:test',
          name: 'Test',
          vessel: 'V60',
          brewType: 'coffee',
          saveCount: 0,
          createdAt: DateTime.now(),
          steps: const [],
        ),
        dryWeight: 20.0,
      );

      expect(brew.calculatedWaterWeight, isNull);
    });

    test('copyWith with clearTimer removes timer', () {
      final brew = CurrentBrew(
        timer: TimerModel(
          uri: 'test://timer',
          did: 'did:test',
          name: 'Test',
          vessel: 'V60',
          brewType: 'coffee',
          saveCount: 0,
          createdAt: DateTime.now(),
          steps: const [],
        ),
      );

      final cleared = brew.copyWith(clearTimer: true);

      expect(cleared.timer, isNull);
    });
  });

  group('CurrentBrewNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('setTimer updates timer', () {
      final notifier = container.read(currentBrewProvider.notifier);
      final timer = TimerModel(
        uri: 'test://timer',
        did: 'did:test',
        name: 'Test',
        vessel: 'V60',
        brewType: 'coffee',
        saveCount: 0,
        createdAt: DateTime.now(),
        steps: const [],
      );

      notifier.setTimer(timer);

      final brew = container.read(currentBrewProvider);
      expect(brew.hasTimer, true);
      expect(brew.timer?.name, 'Test');
    });

    test('setDryWeight updates dry weight', () {
      final notifier = container.read(currentBrewProvider.notifier);

      notifier.setDryWeight(18.0);

      final brew = container.read(currentBrewProvider);
      expect(brew.dryWeight, 18.0);
    });

    test('setWaterWeight updates water weight', () {
      final notifier = container.read(currentBrewProvider.notifier);

      notifier.setWaterWeight(300.0);

      final brew = container.read(currentBrewProvider);
      expect(brew.waterWeight, 300.0);
    });

    test('clear removes all data', () {
      final notifier = container.read(currentBrewProvider.notifier);
      notifier.setDryWeight(20.0);
      notifier.setWaterWeight(320.0);

      notifier.clear();

      final brew = container.read(currentBrewProvider);
      expect(brew.hasTimer, false);
      expect(brew.dryWeight, isNull);
      expect(brew.waterWeight, isNull);
    });

    test('resetWeights clears weights but keeps timer', () {
      final notifier = container.read(currentBrewProvider.notifier);
      final timer = TimerModel(
        uri: 'test://timer',
        did: 'did:test',
        name: 'Test',
        vessel: 'V60',
        brewType: 'coffee',
        saveCount: 0,
        createdAt: DateTime.now(),
        steps: const [],
      );
      notifier.setTimer(timer);
      notifier.setDryWeight(20.0);

      notifier.resetWeights();

      final brew = container.read(currentBrewProvider);
      expect(brew.hasTimer, true);
      expect(brew.dryWeight, isNull);
    });
  });

  group('Derived Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('currentStepProvider returns current step', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Test Step', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);

      final currentStep = container.read(currentStepProvider);

      expect(currentStep?.action, 'Test Step');
    });

    test('timerStatusProvider returns status', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Test', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);
      notifier.start();

      final status = container.read(timerStatusProvider);

      expect(status, TimerStatus.running);
    });

    test('hasCurrentBrewProvider returns false initially', () {
      final hasBrew = container.read(hasCurrentBrewProvider);

      expect(hasBrew, false);
    });

    test('isTimerRunningProvider reflects running state', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Test', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);

      expect(container.read(isTimerRunningProvider), false);

      notifier.start();

      expect(container.read(isTimerRunningProvider), true);
    });

    test('isTimerCompletedProvider reflects completed state', () {
      final notifier = container.read(timerStateProvider.notifier);
      const steps = [
        TimerStep(action: 'Test', stepType: StepType.timed, durationSeconds: 30),
      ];
      notifier.initialize(steps);
      notifier.start();

      expect(container.read(isTimerCompletedProvider), false);

      notifier.advanceStep(); // Complete single step timer

      expect(container.read(isTimerCompletedProvider), true);
    });
  });
}
