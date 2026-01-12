import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Focus Guard state tracking interruptions during brewing
class FocusGuardState {
  /// Number of times the user left the app during this session
  final int interruptionCount;

  /// Total time spent away from the app (in seconds)
  final int totalSecondsAway;

  /// When the current interruption started (null if not interrupted)
  final DateTime? interruptedAt;

  /// Whether the app is currently in an interrupted state
  final bool isInterrupted;

  /// Whether focus guarding is currently active
  final bool isActive;

  const FocusGuardState({
    this.interruptionCount = 0,
    this.totalSecondsAway = 0,
    this.interruptedAt,
    this.isInterrupted = false,
    this.isActive = false,
  });

  /// Duration of the current interruption (if interrupted)
  Duration get currentInterruptionDuration {
    if (!isInterrupted || interruptedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(interruptedAt!);
  }

  /// Total time away including current interruption
  Duration get totalTimeAway {
    return Duration(seconds: totalSecondsAway) + currentInterruptionDuration;
  }

  /// Format total time away as mm:ss
  String get formattedTotalTimeAway {
    final total = totalTimeAway;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format current interruption as mm:ss
  String get formattedCurrentInterruption {
    final duration = currentInterruptionDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  FocusGuardState copyWith({
    int? interruptionCount,
    int? totalSecondsAway,
    DateTime? interruptedAt,
    bool? isInterrupted,
    bool? isActive,
    bool clearInterruptedAt = false,
  }) {
    return FocusGuardState(
      interruptionCount: interruptionCount ?? this.interruptionCount,
      totalSecondsAway: totalSecondsAway ?? this.totalSecondsAway,
      interruptedAt:
          clearInterruptedAt ? null : (interruptedAt ?? this.interruptedAt),
      isInterrupted: isInterrupted ?? this.isInterrupted,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Focus Guard notifier that monitors app lifecycle
class FocusGuardNotifier extends StateNotifier<FocusGuardState>
    with WidgetsBindingObserver {
  FocusGuardNotifier() : super(const FocusGuardState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Activate focus guarding (call when timer starts)
  void activate() {
    state = state.copyWith(
      isActive: true,
      interruptionCount: 0,
      totalSecondsAway: 0,
      isInterrupted: false,
      clearInterruptedAt: true,
    );
  }

  /// Deactivate focus guarding (call when timer completes or is reset)
  void deactivate() {
    // If we're interrupted when deactivating, finalize the interruption
    if (state.isInterrupted && state.interruptedAt != null) {
      final duration = DateTime.now().difference(state.interruptedAt!);
      state = state.copyWith(
        totalSecondsAway: state.totalSecondsAway + duration.inSeconds,
        isInterrupted: false,
        clearInterruptedAt: true,
      );
    }
    state = state.copyWith(isActive: false);
  }

  /// Acknowledge the interruption and return to the ritual
  void acknowledgeReturn() {
    if (!state.isInterrupted || state.interruptedAt == null) return;

    // Calculate time away and add to total
    final duration = DateTime.now().difference(state.interruptedAt!);
    state = state.copyWith(
      totalSecondsAway: state.totalSecondsAway + duration.inSeconds,
      isInterrupted: false,
      clearInterruptedAt: true,
    );
  }

  /// Reset all tracking (call when starting a new brew)
  void reset() {
    state = const FocusGuardState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (!state.isActive) return;

    // Detect when app goes to background
    if (appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.hidden ||
        appState == AppLifecycleState.paused) {
      _recordInterruption();
    }
  }

  void _recordInterruption() {
    // Don't record if already interrupted or not active
    if (state.isInterrupted || !state.isActive) return;

    state = state.copyWith(
      interruptionCount: state.interruptionCount + 1,
      interruptedAt: DateTime.now(),
      isInterrupted: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Provider for focus guard state
final focusGuardProvider =
    StateNotifierProvider<FocusGuardNotifier, FocusGuardState>((ref) {
  return FocusGuardNotifier();
});

/// Provider for whether the app is currently interrupted
final isInterruptedProvider = Provider<bool>((ref) {
  return ref.watch(focusGuardProvider).isInterrupted;
});

/// Provider for interruption count
final interruptionCountProvider = Provider<int>((ref) {
  return ref.watch(focusGuardProvider).interruptionCount;
});

/// Provider for whether focus guard is active
final isFocusGuardActiveProvider = Provider<bool>((ref) {
  return ref.watch(focusGuardProvider).isActive;
});
