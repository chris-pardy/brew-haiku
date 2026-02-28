import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_model.dart';
import '../services/timer_service.dart';
import '../services/cache_service.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

enum TimerListMode { browse, search, saved }

class TimerListState {
  final TimerListMode mode;
  final List<BrewTimer> timers;
  final bool loading;
  final String? error;
  final String? cursor;
  final String searchQuery;
  final String? brewTypeFilter;

  const TimerListState({
    this.mode = TimerListMode.browse,
    this.timers = const [],
    this.loading = false,
    this.error,
    this.cursor,
    this.searchQuery = '',
    this.brewTypeFilter,
  });

  bool get hasMore => cursor != null;

  TimerListState copyWith({
    TimerListMode? mode,
    List<BrewTimer>? timers,
    bool? loading,
    String? error,
    String? cursor,
    String? searchQuery,
    String? brewTypeFilter,
  }) {
    return TimerListState(
      mode: mode ?? this.mode,
      timers: timers ?? this.timers,
      loading: loading ?? this.loading,
      error: error,
      cursor: cursor,
      searchQuery: searchQuery ?? this.searchQuery,
      brewTypeFilter: brewTypeFilter ?? this.brewTypeFilter,
    );
  }
}

class TimerListNotifier extends StateNotifier<TimerListState> {
  final TimerService _timerService;
  final CacheService _cacheService;
  final Ref _ref;

  static const _cacheKey = 'timer_list';

  TimerListNotifier({
    required TimerService timerService,
    required CacheService cacheService,
    required Ref ref,
  })  : _timerService = timerService,
        _cacheService = cacheService,
        _ref = ref,
        super(const TimerListState()) {
    _loadInitial();
  }

  bool get _isOnline => _ref.read(connectivityProvider);
  bool get _isAuthenticated => _ref.read(authProvider).isAuthenticated;

  Future<void> _loadInitial() async {
    // Load cached timers first
    final cached = await _cacheService.read<List<dynamic>>(_cacheKey);
    if (cached != null) {
      final timers = cached
          .map((t) => BrewTimer.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      state = state.copyWith(timers: timers);
    }

    // Then refresh from server
    await refresh();
  }

  Future<void> refresh() async {
    if (!_isOnline) return;

    state = state.copyWith(loading: true);
    try {
      final result = await _timerService.listTimers(auth: _isAuthenticated);
      state = state.copyWith(
        timers: result.timers,
        cursor: result.cursor,
        loading: false,
      );
      // Cache results
      await _cacheService.write(
        _cacheKey,
        result.timers.map((t) => t.toJson()).toList(),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading || !_isOnline) return;

    state = state.copyWith(loading: true);
    try {
      final result = state.mode == TimerListMode.search
          ? await _timerService.searchTimers(
              state.searchQuery,
              cursor: state.cursor,
              brewType: state.brewTypeFilter,
              auth: _isAuthenticated,
            )
          : await _timerService.listTimers(
              cursor: state.cursor,
              auth: _isAuthenticated,
            );

      state = state.copyWith(
        timers: [...state.timers, ...result.timers],
        cursor: result.cursor,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(
        mode: TimerListMode.browse,
        searchQuery: '',
      );
      await refresh();
      return;
    }

    if (!_isOnline) return;

    state = state.copyWith(
      mode: TimerListMode.search,
      searchQuery: query,
      loading: true,
      timers: [],
      cursor: null,
    );

    try {
      final result = await _timerService.searchTimers(
        query,
        brewType: state.brewTypeFilter,
        auth: _isAuthenticated,
      );
      state = state.copyWith(
        timers: result.timers,
        cursor: result.cursor,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setMode(TimerListMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode, timers: [], cursor: null);
    if (mode == TimerListMode.browse) {
      refresh();
    }
  }

  void updateTimerSaved(String uri, bool saved, int saveCountDelta) {
    final updated = state.timers.map((t) {
      if (t.uri == uri) {
        return t.copyWith(
          saved: saved,
          saveCount: t.saveCount + saveCountDelta,
        );
      }
      return t;
    }).toList();
    state = state.copyWith(timers: updated);
  }
}

final timerServiceProvider = Provider<TimerService>((ref) {
  return TimerService(api: ref.read(apiServiceProvider));
});

final timerListProvider =
    StateNotifierProvider<TimerListNotifier, TimerListState>((ref) {
  return TimerListNotifier(
    timerService: ref.read(timerServiceProvider),
    cacheService: ref.read(cacheServiceProvider),
    ref: ref,
  );
});
