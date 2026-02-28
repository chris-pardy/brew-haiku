import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_model.dart';
import '../models/brew_model.dart';

enum BrewPhase { notStarted, configuring, brewing, completed }

class BrewSessionState {
  final BrewPhase phase;
  final BrewTimer? timer;
  final int currentStepIndex;
  final DateTime? brewStartedAt;
  final DateTime? stepStartedAt;
  final Map<int, double> stepValues;
  final int interruptions;
  final Duration? totalDuration;

  const BrewSessionState({
    this.phase = BrewPhase.notStarted,
    this.timer,
    this.currentStepIndex = 0,
    this.brewStartedAt,
    this.stepStartedAt,
    this.stepValues = const {},
    this.interruptions = 0,
    this.totalDuration,
  });

  TimerStep? get currentStep =>
      timer != null && currentStepIndex < timer!.steps.length
          ? timer!.steps[currentStepIndex]
          : null;

  bool get isLastStep =>
      timer != null && currentStepIndex >= timer!.steps.length - 1;

  Duration get elapsed => brewStartedAt != null
      ? DateTime.now().difference(brewStartedAt!)
      : Duration.zero;

  Duration get stepElapsed => stepStartedAt != null
      ? DateTime.now().difference(stepStartedAt!)
      : Duration.zero;

  int get stepRemainingSeconds {
    final step = currentStep;
    if (step == null || !step.isTimed) return 0;
    final remainingMs =
        ((step.durationSeconds ?? 0) * 1000) - stepElapsed.inMilliseconds;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
  }

  double get stepProgress {
    final step = currentStep;
    if (step == null || !step.isTimed || (step.durationSeconds ?? 0) == 0) {
      return 0;
    }
    final progress = stepElapsed.inMilliseconds /
        ((step.durationSeconds ?? 1) * 1000);
    return progress.clamp(0.0, 1.0);
  }

  List<StepValue> get stepValuesList => stepValues.entries
      .map((e) => StepValue(stepIndex: e.key, value: e.value))
      .toList();

  BrewSessionState copyWith({
    BrewPhase? phase,
    BrewTimer? timer,
    int? currentStepIndex,
    DateTime? brewStartedAt,
    DateTime? stepStartedAt,
    Map<int, double>? stepValues,
    int? interruptions,
    Duration? totalDuration,
  }) {
    return BrewSessionState(
      phase: phase ?? this.phase,
      timer: timer ?? this.timer,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      brewStartedAt: brewStartedAt ?? this.brewStartedAt,
      stepStartedAt: stepStartedAt ?? this.stepStartedAt,
      stepValues: stepValues ?? this.stepValues,
      interruptions: interruptions ?? this.interruptions,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}

class BrewSessionNotifier extends StateNotifier<BrewSessionState> {
  Timer? _tickTimer;

  BrewSessionNotifier() : super(const BrewSessionState());

  void configure(BrewTimer timer) {
    _cancelTick();
    state = BrewSessionState(
      phase: BrewPhase.configuring,
      timer: timer,
    );
  }

  void startBrew() {
    final now = DateTime.now();
    state = state.copyWith(
      phase: BrewPhase.brewing,
      brewStartedAt: now,
      stepStartedAt: now,
      currentStepIndex: 0,
    );
    _startTick();
  }

  void _startTick() {
    _cancelTick();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _checkStepCompletion();
      // Force state rebuild for timer display
      state = state.copyWith();
    });
  }

  void _cancelTick() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _checkStepCompletion() {
    final step = state.currentStep;
    if (step == null) return;
    if (step.isTimed && state.stepRemainingSeconds <= 0) {
      _advanceStep();
    }
  }

  void completeCurrentStep({double? value}) {
    if (value != null) {
      final updated = Map<int, double>.from(state.stepValues);
      updated[state.currentStepIndex] = value;
      state = state.copyWith(stepValues: updated);
    }
    _advanceStep();
  }

  void _advanceStep() {
    if (state.isLastStep) {
      _completeBrew();
      return;
    }
    state = state.copyWith(
      currentStepIndex: state.currentStepIndex + 1,
      stepStartedAt: DateTime.now(),
    );
  }

  void _completeBrew() {
    _cancelTick();
    state = state.copyWith(
      phase: BrewPhase.completed,
      totalDuration: state.elapsed,
    );
  }

  void recordInterruption() {
    state = state.copyWith(interruptions: state.interruptions + 1);
  }

  void reset() {
    _cancelTick();
    state = const BrewSessionState();
  }

  @override
  void dispose() {
    _cancelTick();
    super.dispose();
  }
}

final brewSessionProvider =
    StateNotifierProvider<BrewSessionNotifier, BrewSessionState>((ref) {
  return BrewSessionNotifier();
});
