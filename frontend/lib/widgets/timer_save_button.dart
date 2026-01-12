import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_model.dart';
import '../services/timer_save_service.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';

/// Provider for the timer save service
final timerSaveServiceProvider = Provider<TimerSaveService>((ref) {
  return TimerSaveService();
});

/// State for saved timer URIs (cached for quick lookup)
class SavedTimersState {
  final Set<String> savedUris;
  final bool isLoading;
  final String? error;

  const SavedTimersState({
    this.savedUris = const {},
    this.isLoading = false,
    this.error,
  });

  bool isSaved(String timerUri) => savedUris.contains(timerUri);

  SavedTimersState copyWith({
    Set<String>? savedUris,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SavedTimersState(
      savedUris: savedUris ?? this.savedUris,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for saved timers state
class SavedTimersNotifier extends StateNotifier<SavedTimersState> {
  final Ref _ref;

  SavedTimersNotifier(this._ref) : super(const SavedTimersState());

  /// Load saved timer URIs from user's PDS
  Future<void> loadSavedTimers() async {
    final authState = _ref.read(authStateProvider);
    final session = authState.session;

    if (session == null) {
      state = const SavedTimersState();
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = _ref.read(timerSaveServiceProvider);
      final uris = await service.getSavedTimerUris(session: session);
      state = state.copyWith(
        savedUris: uris.toSet(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Save a timer (optimistic update)
  Future<bool> saveTimer(String timerUri) async {
    final authState = _ref.read(authStateProvider);
    final session = authState.session;

    if (session == null) {
      return false;
    }

    // Optimistic update
    final oldSaved = state.savedUris;
    state = state.copyWith(savedUris: {...oldSaved, timerUri});

    try {
      final service = _ref.read(timerSaveServiceProvider);
      await service.saveTimer(session: session, timerUri: timerUri);
      return true;
    } catch (e) {
      // Revert on failure
      state = state.copyWith(savedUris: oldSaved, error: e.toString());
      return false;
    }
  }

  /// Unsave a timer (optimistic update)
  Future<bool> unsaveTimer(String timerUri) async {
    final authState = _ref.read(authStateProvider);
    final session = authState.session;

    if (session == null) {
      return false;
    }

    // Optimistic update
    final oldSaved = state.savedUris;
    state = state.copyWith(
      savedUris: oldSaved.where((uri) => uri != timerUri).toSet(),
    );

    try {
      final service = _ref.read(timerSaveServiceProvider);
      await service.unsaveTimer(session: session, timerUri: timerUri);
      return true;
    } catch (e) {
      // Revert on failure
      state = state.copyWith(savedUris: oldSaved, error: e.toString());
      return false;
    }
  }

  /// Toggle save status for a timer
  Future<bool> toggleSave(String timerUri) async {
    if (state.isSaved(timerUri)) {
      return unsaveTimer(timerUri);
    } else {
      return saveTimer(timerUri);
    }
  }

  /// Clear saved timers (e.g., on logout)
  void clear() {
    state = const SavedTimersState();
  }
}

/// Provider for saved timers
final savedTimersProvider =
    StateNotifierProvider<SavedTimersNotifier, SavedTimersState>((ref) {
  return SavedTimersNotifier(ref);
});

/// Button widget for saving/unsaving a timer
class TimerSaveButton extends ConsumerWidget {
  final TimerModel timer;
  final bool showLabel;
  final double iconSize;

  const TimerSaveButton({
    super.key,
    required this.timer,
    this.showLabel = false,
    this.iconSize = 24,
  });

  Future<void> _handleTap(WidgetRef ref, bool isAuthenticated) async {
    if (!isAuthenticated) {
      // Could show a login prompt here
      return;
    }

    // Haptic feedback
    HapticFeedback.lightImpact();

    await ref.read(savedTimersProvider.notifier).toggleSave(timer.uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final savedState = ref.watch(savedTimersProvider);
    final isAuthenticated = authState.isAuthenticated;
    final isSaved = savedState.isSaved(timer.uri);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    final color = isSaved ? accentColor : secondaryColor;

    if (showLabel) {
      return TextButton.icon(
        onPressed: isAuthenticated ? () => _handleTap(ref, true) : null,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            key: ValueKey(isSaved),
            size: iconSize,
            color: isAuthenticated ? color : secondaryColor.withOpacity(0.5),
          ),
        ),
        label: Text(
          isSaved ? 'Saved' : 'Save',
          style: TextStyle(
            color: isAuthenticated ? color : secondaryColor.withOpacity(0.5),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: isAuthenticated ? () => _handleTap(ref, true) : null,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          key: ValueKey(isSaved),
          size: iconSize,
          color: isAuthenticated ? color : secondaryColor.withOpacity(0.5),
        ),
      ),
      tooltip: isSaved ? 'Remove from collection' : 'Save to collection',
    );
  }
}

/// Widget showing the user's saved timers collection
class SavedTimersCollection extends ConsumerStatefulWidget {
  /// Callback when a timer is selected
  final void Function(TimerModel timer)? onTimerSelected;

  const SavedTimersCollection({
    super.key,
    this.onTimerSelected,
  });

  @override
  ConsumerState<SavedTimersCollection> createState() =>
      _SavedTimersCollectionState();
}

class _SavedTimersCollectionState extends ConsumerState<SavedTimersCollection> {
  @override
  void initState() {
    super.initState();
    // Load saved timers on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(savedTimersProvider.notifier).loadSavedTimers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedState = ref.watch(savedTimersProvider);
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    if (!authState.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: secondaryColor),
            const SizedBox(height: 16),
            Text(
              'Sign in to save timers',
              style: TextStyle(color: secondaryColor),
            ),
          ],
        ),
      );
    }

    if (savedState.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(
            isDark ? BrewColors.accentGold : BrewColors.warmBrown,
          ),
        ),
      );
    }

    if (savedState.savedUris.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: secondaryColor),
            const SizedBox(height: 16),
            Text(
              'No saved timers yet',
              style: TextStyle(color: secondaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Save timers to access them quickly',
              style: TextStyle(
                color: secondaryColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Note: In a full implementation, you would fetch the full timer details
    // for each saved URI from the API. For now, we just show the count.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark,
            size: 48,
            color: isDark ? BrewColors.accentGold : BrewColors.warmBrown,
          ),
          const SizedBox(height: 16),
          Text(
            '${savedState.savedUris.length} saved timer${savedState.savedUris.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: isDark
                  ? BrewColors.textPrimaryDark
                  : BrewColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
