import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FocusGuardState {
  final bool isAway;
  final int interruptions;
  final DateTime? lastInterruptedAt;
  final Duration totalAwayTime;

  const FocusGuardState({
    this.isAway = false,
    this.interruptions = 0,
    this.lastInterruptedAt,
    this.totalAwayTime = Duration.zero,
  });

  FocusGuardState copyWith({
    bool? isAway,
    int? interruptions,
    DateTime? lastInterruptedAt,
    Duration? totalAwayTime,
  }) {
    return FocusGuardState(
      isAway: isAway ?? this.isAway,
      interruptions: interruptions ?? this.interruptions,
      lastInterruptedAt: lastInterruptedAt ?? this.lastInterruptedAt,
      totalAwayTime: totalAwayTime ?? this.totalAwayTime,
    );
  }
}

class FocusGuardNotifier extends StateNotifier<FocusGuardState>
    with WidgetsBindingObserver {
  FocusGuardNotifier() : super(const FocusGuardState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive) {
      state = state.copyWith(
        isAway: true,
        interruptions: state.interruptions + 1,
        lastInterruptedAt: DateTime.now(),
      );
    } else if (appState == AppLifecycleState.resumed) {
      final awayDuration = state.lastInterruptedAt != null
          ? DateTime.now().difference(state.lastInterruptedAt!)
          : Duration.zero;
      state = state.copyWith(
        isAway: false,
        totalAwayTime: state.totalAwayTime + awayDuration,
      );
    }
  }

  void dismiss() {
    state = state.copyWith(isAway: false);
  }

  void reset() {
    state = const FocusGuardState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final focusGuardProvider =
    StateNotifierProvider<FocusGuardNotifier, FocusGuardState>((ref) {
  return FocusGuardNotifier();
});
