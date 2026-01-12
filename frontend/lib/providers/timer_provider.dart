import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_model.dart';

/// Step types for brew timers
enum StepType {
  timed,
  indeterminate,
}

/// A single step in a brew timer
class TimerStep {
  final String action;
  final StepType stepType;
  final int? durationSeconds;

  const TimerStep({
    required this.action,
    required this.stepType,
    this.durationSeconds,
  });

  /// Create from TimerStepModel
  factory TimerStep.fromModel(TimerStepModel model) {
    return TimerStep(
      action: model.action,
      stepType: model.stepType == 'timed' ? StepType.timed : StepType.indeterminate,
      durationSeconds: model.durationSeconds,
    );
  }

  TimerStep copyWith({
    String? action,
    StepType? stepType,
    int? durationSeconds,
  }) {
    return TimerStep(
      action: action ?? this.action,
      stepType: stepType ?? this.stepType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

/// Timer status
enum TimerStatus {
  /// Timer has not started yet
  notStarted,

  /// Timer is running and counting
  running,

  /// Current timed step is complete, waiting to advance
  stepComplete,

  /// Waiting for user to complete an indeterminate step
  waitingForUser,

  /// All steps completed
  completed,
}

/// Current brew/timer state
class TimerState {
  final TimerStatus status;
  final int currentStepIndex;
  final int elapsedSeconds;
  final int totalElapsedSeconds;
  final List<TimerStep> steps;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool autoAdvance;

  const TimerState({
    this.status = TimerStatus.notStarted,
    this.currentStepIndex = 0,
    this.elapsedSeconds = 0,
    this.totalElapsedSeconds = 0,
    this.steps = const [],
    this.startedAt,
    this.completedAt,
    this.autoAdvance = true,
  });

  TimerStep? get currentStep =>
      currentStepIndex < steps.length ? steps[currentStepIndex] : null;

  bool get isRunning => status == TimerStatus.running;

  bool get isCompleted => status == TimerStatus.completed;

  bool get isNotStarted => status == TimerStatus.notStarted;

  bool get isWaitingForUser => status == TimerStatus.waitingForUser;

  bool get isStepComplete => status == TimerStatus.stepComplete;

  /// Check if current step is the last step
  bool get isLastStep => currentStepIndex >= steps.length - 1;

  /// Remaining seconds in current step (0 for indeterminate)
  int get remainingSeconds {
    final step = currentStep;
    if (step == null || step.stepType == StepType.indeterminate) return 0;
    final remaining = (step.durationSeconds ?? 0) - elapsedSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  /// Progress of current step (0.0 to 1.0)
  double get stepProgress {
    final step = currentStep;
    if (step == null ||
        step.stepType == StepType.indeterminate ||
        step.durationSeconds == null ||
        step.durationSeconds == 0) {
      return 0.0;
    }
    final progress = elapsedSeconds / step.durationSeconds!;
    return progress > 1.0 ? 1.0 : progress;
  }

  /// Total timed duration across all steps
  int get totalTimedDuration {
    return steps
        .where((s) => s.stepType == StepType.timed && s.durationSeconds != null)
        .fold(0, (sum, s) => sum + (s.durationSeconds ?? 0));
  }

  /// Elapsed timed seconds (only counting timed steps)
  int get elapsedTimedSeconds {
    int elapsed = 0;

    // Add completed timed steps
    for (int i = 0; i < currentStepIndex && i < steps.length; i++) {
      final step = steps[i];
      if (step.stepType == StepType.timed && step.durationSeconds != null) {
        elapsed += step.durationSeconds!;
      }
    }

    // Add current step if timed
    final current = currentStep;
    if (current != null && current.stepType == StepType.timed) {
      elapsed += elapsedSeconds;
    }

    return elapsed;
  }

  /// Overall progress across all timed steps (0.0 to 1.0)
  double get overallProgress {
    if (totalTimedDuration == 0) return 0.0;
    final progress = elapsedTimedSeconds / totalTimedDuration;
    return progress > 1.0 ? 1.0 : progress;
  }

  /// Format remaining seconds as mm:ss
  String get formattedRemaining {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format total elapsed as mm:ss
  String get formattedTotalElapsed {
    final minutes = totalElapsedSeconds ~/ 60;
    final seconds = totalElapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  TimerState copyWith({
    TimerStatus? status,
    int? currentStepIndex,
    int? elapsedSeconds,
    int? totalElapsedSeconds,
    List<TimerStep>? steps,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? autoAdvance,
  }) {
    return TimerState(
      status: status ?? this.status,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      totalElapsedSeconds: totalElapsedSeconds ?? this.totalElapsedSeconds,
      steps: steps ?? this.steps,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      autoAdvance: autoAdvance ?? this.autoAdvance,
    );
  }
}

/// Timer state notifier with automatic tick handling
class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _timer;
  final void Function()? onStepComplete;
  final void Function()? onTimerComplete;

  TimerNotifier({
    this.onStepComplete,
    this.onTimerComplete,
  }) : super(const TimerState());

  /// Initialize timer with steps from a TimerModel
  void initializeFromModel(TimerModel timer) {
    final steps = timer.steps.map((s) => TimerStep.fromModel(s)).toList();
    initialize(steps);
  }

  /// Initialize timer with steps
  void initialize(List<TimerStep> steps, {bool autoAdvance = true}) {
    _stopTimer();
    state = TimerState(
      status: TimerStatus.notStarted,
      steps: steps,
      autoAdvance: autoAdvance,
    );
  }

  /// Start the timer
  void start() {
    if (state.steps.isEmpty) return;
    if (state.isRunning) return;

    final firstStep = state.steps.first;

    // If first step is indeterminate, wait for user
    if (firstStep.stepType == StepType.indeterminate) {
      state = state.copyWith(
        status: TimerStatus.waitingForUser,
        startedAt: state.startedAt ?? DateTime.now(),
      );
    } else {
      state = state.copyWith(
        status: TimerStatus.running,
        startedAt: state.startedAt ?? DateTime.now(),
      );
      _startTimer();
    }
  }

  /// Advance to next step (for indeterminate steps or manual advance)
  void advanceStep() {
    if (state.isCompleted) return;

    // If last step, complete the timer
    if (state.isLastStep) {
      _complete();
      return;
    }

    final nextIndex = state.currentStepIndex + 1;
    final nextStep = state.steps[nextIndex];

    if (nextStep.stepType == StepType.indeterminate) {
      state = state.copyWith(
        status: TimerStatus.waitingForUser,
        currentStepIndex: nextIndex,
        elapsedSeconds: 0,
      );
      _stopTimer();
    } else {
      state = state.copyWith(
        status: TimerStatus.running,
        currentStepIndex: nextIndex,
        elapsedSeconds: 0,
      );
      _startTimer();
    }

    onStepComplete?.call();
  }

  /// Complete an indeterminate step (user action)
  void completeIndeterminateStep() {
    if (state.currentStep?.stepType != StepType.indeterminate) return;
    advanceStep();
  }

  /// Internal tick called by timer
  void _tick() {
    if (!state.isRunning) return;

    final newElapsed = state.elapsedSeconds + 1;
    final newTotalElapsed = state.totalElapsedSeconds + 1;

    final step = state.currentStep;

    // Check if timed step is complete
    if (step != null &&
        step.stepType == StepType.timed &&
        step.durationSeconds != null &&
        newElapsed >= step.durationSeconds!) {
      // Step complete
      _stopTimer();

      if (state.autoAdvance) {
        // Auto-advance to next step
        state = state.copyWith(
          elapsedSeconds: newElapsed,
          totalElapsedSeconds: newTotalElapsed,
        );
        advanceStep();
      } else {
        state = state.copyWith(
          status: TimerStatus.stepComplete,
          elapsedSeconds: newElapsed,
          totalElapsedSeconds: newTotalElapsed,
        );
        onStepComplete?.call();
      }
    } else {
      state = state.copyWith(
        elapsedSeconds: newElapsed,
        totalElapsedSeconds: newTotalElapsed,
      );
    }
  }

  void _complete() {
    _stopTimer();
    state = state.copyWith(
      status: TimerStatus.completed,
      completedAt: DateTime.now(),
    );
    onTimerComplete?.call();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reset timer to beginning (keeps same steps)
  void reset() {
    _stopTimer();
    state = TimerState(
      steps: state.steps,
      autoAdvance: state.autoAdvance,
    );
  }

  /// Skip to a specific step
  void skipToStep(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= state.steps.length) return;

    _stopTimer();
    final step = state.steps[stepIndex];

    if (step.stepType == StepType.indeterminate) {
      state = state.copyWith(
        status: TimerStatus.waitingForUser,
        currentStepIndex: stepIndex,
        elapsedSeconds: 0,
      );
    } else {
      state = state.copyWith(
        status: TimerStatus.running,
        currentStepIndex: stepIndex,
        elapsedSeconds: 0,
      );
      _startTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

/// Current brew configuration
class CurrentBrew {
  final TimerModel? timer;
  final double? dryWeight;
  final double? waterWeight;

  const CurrentBrew({
    this.timer,
    this.dryWeight,
    this.waterWeight,
  });

  bool get hasTimer => timer != null;

  /// Calculate water weight from dry weight and ratio
  double? get calculatedWaterWeight {
    if (timer?.ratio == null || dryWeight == null) return null;
    return dryWeight! * timer!.ratio!;
  }

  CurrentBrew copyWith({
    TimerModel? timer,
    double? dryWeight,
    double? waterWeight,
    bool clearTimer = false,
  }) {
    return CurrentBrew(
      timer: clearTimer ? null : (timer ?? this.timer),
      dryWeight: dryWeight ?? this.dryWeight,
      waterWeight: waterWeight ?? this.waterWeight,
    );
  }
}

/// Current brew notifier
class CurrentBrewNotifier extends StateNotifier<CurrentBrew> {
  CurrentBrewNotifier() : super(const CurrentBrew());

  /// Set the current timer
  void setTimer(TimerModel timer) {
    state = state.copyWith(timer: timer);
  }

  /// Set the dry weight (grams)
  void setDryWeight(double weight) {
    state = state.copyWith(dryWeight: weight);
  }

  /// Set the water weight (ml)
  void setWaterWeight(double weight) {
    state = state.copyWith(waterWeight: weight);
  }

  /// Set dry weight and auto-calculate water from ratio
  void setDryWeightWithRatio(double dryWeight) {
    final waterWeight = state.calculatedWaterWeight;
    state = state.copyWith(
      dryWeight: dryWeight,
      waterWeight: waterWeight,
    );
  }

  /// Clear the current brew
  void clear() {
    state = const CurrentBrew();
  }

  /// Reset weights but keep timer
  void resetWeights() {
    state = CurrentBrew(timer: state.timer);
  }
}

/// Provider for timer state
final timerStateProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier();
});

/// Provider for current step
final currentStepProvider = Provider<TimerStep?>((ref) {
  return ref.watch(timerStateProvider).currentStep;
});

/// Provider for step progress (0.0 to 1.0)
final stepProgressProvider = Provider<double>((ref) {
  return ref.watch(timerStateProvider).stepProgress;
});

/// Provider for overall progress (0.0 to 1.0)
final overallProgressProvider = Provider<double>((ref) {
  return ref.watch(timerStateProvider).overallProgress;
});

/// Provider for remaining seconds in current step
final remainingSecondsProvider = Provider<int>((ref) {
  return ref.watch(timerStateProvider).remainingSeconds;
});

/// Provider for formatted remaining time
final formattedRemainingProvider = Provider<String>((ref) {
  return ref.watch(timerStateProvider).formattedRemaining;
});

/// Provider for timer status
final timerStatusProvider = Provider<TimerStatus>((ref) {
  return ref.watch(timerStateProvider).status;
});

/// Provider for current brew configuration
final currentBrewProvider =
    StateNotifierProvider<CurrentBrewNotifier, CurrentBrew>((ref) {
  return CurrentBrewNotifier();
});

/// Provider for whether a brew is configured
final hasCurrentBrewProvider = Provider<bool>((ref) {
  return ref.watch(currentBrewProvider).hasTimer;
});

/// Convenience provider - is timer running?
final isTimerRunningProvider = Provider<bool>((ref) {
  return ref.watch(timerStateProvider).isRunning;
});

/// Convenience provider - is timer completed?
final isTimerCompletedProvider = Provider<bool>((ref) {
  return ref.watch(timerStateProvider).isCompleted;
});

// Legacy provider name for backwards compatibility
final timerProgressProvider = stepProgressProvider;
