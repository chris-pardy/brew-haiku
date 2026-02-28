import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_event.dart';
import '../services/activity_service.dart';
import '../services/brew_service.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

class ActivityState {
  final List<ActivityEvent> events;
  final bool loading;
  final bool unlocked;
  final String? cursor;
  final String? error;

  const ActivityState({
    this.events = const [],
    this.loading = false,
    this.unlocked = false,
    this.cursor,
    this.error,
  });

  ActivityState copyWith({
    List<ActivityEvent>? events,
    bool? loading,
    bool? unlocked,
    String? cursor,
    String? error,
  }) {
    return ActivityState(
      events: events ?? this.events,
      loading: loading ?? this.loading,
      unlocked: unlocked ?? this.unlocked,
      cursor: cursor,
      error: error,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final ActivityService _activityService;
  final BrewService _brewService;
  final Ref _ref;

  ActivityNotifier({
    required ActivityService activityService,
    required BrewService brewService,
    required Ref ref,
  })  : _activityService = activityService,
        _brewService = brewService,
        _ref = ref,
        super(const ActivityState());

  bool get _isOnline => _ref.read(connectivityProvider);
  bool get _isAuthenticated => _ref.read(authProvider).isAuthenticated;

  /// Check if user has a brew with postUri within last 20 hours.
  Future<void> checkAccess() async {
    if (!_isOnline || !_isAuthenticated) {
      state = state.copyWith(unlocked: false);
      return;
    }

    try {
      final result = await _brewService.listBrews(limit: 10, auth: true);
      final cutoff = DateTime.now().subtract(const Duration(hours: 20));
      final hasRecentPost = result.brews.any(
        (brew) => brew.postUri != null && brew.createdAt.isAfter(cutoff),
      );
      state = state.copyWith(unlocked: hasRecentPost);
    } catch (_) {
      state = state.copyWith(unlocked: false);
    }
  }

  /// Unlock directly after posting a haiku (skip the check).
  void unlock() {
    state = state.copyWith(unlocked: true);
  }

  Future<void> loadActivity() async {
    if (!_isOnline || !_isAuthenticated || !state.unlocked) return;

    state = state.copyWith(loading: true);
    try {
      final result = await _activityService.getActivity();
      state = state.copyWith(
        events: result.events,
        cursor: result.cursor,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.cursor == null || state.loading || !_isOnline) return;

    state = state.copyWith(loading: true);
    try {
      final result =
          await _activityService.getActivity(cursor: state.cursor);
      state = state.copyWith(
        events: [...state.events, ...result.events],
        cursor: result.cursor,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService(api: ref.read(apiServiceProvider));
});

final brewServiceProvider = Provider<BrewService>((ref) {
  return BrewService(
    api: ref.read(apiServiceProvider),
    cache: ref.read(cacheServiceProvider),
  );
});

final activityProvider =
    StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  return ActivityNotifier(
    activityService: ref.read(activityServiceProvider),
    brewService: ref.read(brewServiceProvider),
    ref: ref,
  );
});
