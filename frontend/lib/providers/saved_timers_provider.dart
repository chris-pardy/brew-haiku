import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_model.dart';
import '../services/timer_service.dart';
import '../services/cache_service.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'timer_list_provider.dart';

class SavedTimersState {
  final List<BrewTimer> timers;
  final bool loading;
  final String? error;
  final String? cursor;

  const SavedTimersState({
    this.timers = const [],
    this.loading = false,
    this.error,
    this.cursor,
  });

  bool get hasMore => cursor != null;

  SavedTimersState copyWith({
    List<BrewTimer>? timers,
    bool? loading,
    String? error,
    String? cursor,
  }) {
    return SavedTimersState(
      timers: timers ?? this.timers,
      loading: loading ?? this.loading,
      error: error,
      cursor: cursor,
    );
  }
}

class SavedTimersNotifier extends StateNotifier<SavedTimersState> {
  final TimerService _timerService;
  final CacheService _cacheService;
  final Ref _ref;

  static const _cacheKey = 'saved_timers';

  SavedTimersNotifier({
    required TimerService timerService,
    required CacheService cacheService,
    required Ref ref,
  })  : _timerService = timerService,
        _cacheService = cacheService,
        _ref = ref,
        super(const SavedTimersState()) {
    _loadInitial();
  }

  bool get _isOnline => _ref.read(connectivityProvider);
  bool get _isAuthenticated => _ref.read(authProvider).isAuthenticated;

  Future<void> _loadInitial() async {
    final cached = await _cacheService.read<List<dynamic>>(_cacheKey);
    if (cached != null) {
      final timers = cached
          .map((t) => BrewTimer.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      state = state.copyWith(timers: timers);
    }
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
      await _cacheService.write(
        _cacheKey,
        result.timers.map((t) => t.toJson()).toList(),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> saveTimer(String timerUri) async {
    try {
      await _timerService.saveTimer(timerUri);
      await refresh();
      _ref.read(timerListProvider.notifier).updateTimerSaved(timerUri, true, 1);
    } catch (_) {}
  }

  Future<void> forgetTimer(String timerUri) async {
    try {
      await _timerService.forgetTimer(timerUri);
      state = state.copyWith(
        timers: state.timers.where((t) => t.uri != timerUri).toList(),
      );
      _ref.read(timerListProvider.notifier).updateTimerSaved(timerUri, false, -1);
    } catch (_) {}
  }
}

final savedTimersProvider =
    StateNotifierProvider<SavedTimersNotifier, SavedTimersState>((ref) {
  return SavedTimersNotifier(
    timerService: ref.read(timerServiceProvider),
    cacheService: ref.read(cacheServiceProvider),
    ref: ref,
  );
});
