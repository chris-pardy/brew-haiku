import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../copy/strings.dart';
import '../providers/auth_provider.dart';
import '../providers/timer_list_provider.dart';
import '../providers/saved_timers_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/activity_provider.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/timer_card.dart';
import '../widgets/search_bar.dart';
import 'brew_config_screen.dart';
import 'sign_in_screen.dart';
import 'activity_feed_screen.dart';

class TimerSelectionScreen extends ConsumerStatefulWidget {
  const TimerSelectionScreen({super.key});

  @override
  ConsumerState<TimerSelectionScreen> createState() =>
      _TimerSelectionScreenState();
}

class _TimerSelectionScreenState extends ConsumerState<TimerSelectionScreen> {
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(activityProvider.notifier).checkAccess();
      ref.read(savedTimersProvider.notifier).refresh();
    });
  }

  void _onTimerTap(timer) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => BrewConfigScreen(timer: timer),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  void _openActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActivityFeedScreen()),
    );
  }

  void _onSave(String uri) {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      _openSettings();
      return;
    }
    ref.read(savedTimersProvider.notifier).saveTimer(uri);
  }

  void _onUnsave(String uri) {
    ref.read(savedTimersProvider.notifier).forgetTimer(uri);
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      return;
    }
    setState(() => _isSearching = true);
    ref.read(timerListProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isOnline = ref.watch(connectivityProvider);
    final activity = ref.watch(activityProvider);

    return GradientScaffold(
      appBar: AppBar(
        title: Text('Brew Haiku', style: BrewTypography.heading),
        actions: [
          if (activity.unlocked)
            IconButton(
              icon: const Icon(Icons.people_outline),
              onPressed: _openActivity,
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: BrewSpacing.screenPadding,
                vertical: BrewSpacing.sm,
              ),
              color: BrewColors.warmAmber.withValues(alpha: 0.2),
              child: Text(
                S.offlineMode,
                style: BrewTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BrewSpacing.screenPadding,
              BrewSpacing.sm,
              BrewSpacing.screenPadding,
              0,
            ),
            child: BrewSearchBar(
              onSearch: _onSearch,
              enabled: isOnline,
            ),
          ),
          const SizedBox(height: BrewSpacing.sm),
          Expanded(
            child: _isSearching
                ? _SearchResultsList(
                    isAuthenticated: auth.isAuthenticated,
                    onTimerTap: _onTimerTap,
                    onSave: _onSave,
                    onUnsave: _onUnsave,
                  )
                : _SavedTimersList(
                    isAuthenticated: auth.isAuthenticated,
                    onTimerTap: _onTimerTap,
                    onSave: _onSave,
                    onUnsave: _onUnsave,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends ConsumerWidget {
  final bool isAuthenticated;
  final void Function(dynamic timer) onTimerTap;
  final void Function(String uri) onSave;
  final void Function(String uri) onUnsave;

  const _SearchResultsList({
    required this.isAuthenticated,
    required this.onTimerTap,
    required this.onSave,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timerListProvider);

    if (state.loading && state.timers.isEmpty) {
      return Center(
        child: Text(S.loading, style: BrewTypography.body),
      );
    }

    if (state.timers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(BrewSpacing.screenPadding),
          child: Text(S.searchEmpty, style: BrewTypography.body),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          ref.read(timerListProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: EdgeInsets.only(
          left: BrewSpacing.screenPadding,
          right: BrewSpacing.screenPadding,
          top: BrewSpacing.sm,
          bottom: BrewSpacing.sm + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: state.timers.length + (state.loading ? 1 : 0),
        separatorBuilder: (_, __) =>
            const SizedBox(height: BrewSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= state.timers.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(BrewSpacing.base),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BrewColors.warmAmber,
                ),
              ),
            );
          }

          final timer = state.timers[index];
          final saved = timer.saved ?? false;
          return TimerCard(
            timer: timer,
            onTap: () => onTimerTap(timer),
            onPin: () => saved ? onUnsave(timer.uri) : onSave(timer.uri),
          );
        },
      ),
    );
  }
}

class _SavedTimersList extends ConsumerWidget {
  final bool isAuthenticated;
  final void Function(dynamic timer) onTimerTap;
  final void Function(String uri) onSave;
  final void Function(String uri) onUnsave;

  const _SavedTimersList({
    required this.isAuthenticated,
    required this.onTimerTap,
    required this.onSave,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedTimersProvider);

    if (state.loading && state.timers.isEmpty) {
      return Center(
        child: Text(S.loading, style: BrewTypography.body),
      );
    }

    if (state.timers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(BrewSpacing.screenPadding),
          child: Text(S.savedEmpty, style: BrewTypography.body),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(
        left: BrewSpacing.screenPadding,
        right: BrewSpacing.screenPadding,
        top: BrewSpacing.sm,
        bottom: BrewSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: state.timers.length,
      separatorBuilder: (_, __) => const SizedBox(height: BrewSpacing.sm),
      itemBuilder: (context, index) {
        final timer = state.timers[index];
        final saved = timer.saved ?? false;
        return TimerCard(
          timer: timer,
          onTap: () => onTimerTap(timer),
          pinned: true,
          onPin: () => saved ? onUnsave(timer.uri) : onSave(timer.uri),
        );
      },
    );
  }
}
