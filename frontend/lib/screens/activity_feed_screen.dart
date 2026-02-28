import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../theme/gradients.dart';
import '../copy/strings.dart';
import '../providers/activity_provider.dart';
import '../providers/brew_session_provider.dart';
import '../widgets/gradient_scaffold.dart';
import 'timer_selection_screen.dart';

class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() =>
      _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(activityProvider.notifier).loadActivity();
  }

  void _backToTimers() {
    ref.read(brewSessionProvider.notifier).reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TimerSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider);

    if (!activity.unlocked) {
      return GradientScaffold(
        gradient: BrewGradients.surface,
        appBar: AppBar(
          title: Text(S.activityTitle, style: BrewTypography.heading),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(BrewSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.activityLocked,
                  style: BrewTypography.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BrewSpacing.xl),
                TextButton(
                  onPressed: _backToTimers,
                  child: Text(S.backToTimers, style: BrewTypography.label),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GradientScaffold(
      gradient: BrewGradients.surface,
      appBar: AppBar(
        title: Text(S.activityTitle, style: BrewTypography.heading),
        actions: [
          TextButton(
            onPressed: _backToTimers,
            child: Text(S.backToTimers, style: BrewTypography.labelSmall),
          ),
        ],
      ),
      body: activity.loading && activity.events.isEmpty
          ? Center(child: Text(S.gathering, style: BrewTypography.body))
          : activity.events.isEmpty
              ? Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(BrewSpacing.screenPadding),
                    child: Text(
                      S.activityEmpty,
                      style: BrewTypography.body,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification &&
                        notification.metrics.extentAfter < 200) {
                      ref.read(activityProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(BrewSpacing.screenPadding),
                    itemCount: activity.events.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: BrewSpacing.sm),
                    itemBuilder: (context, index) {
                      final event = activity.events[index];
                      return _ActivityEventCard(event: event);
                    },
                  ),
                ),
    );
  }
}

class _ActivityEventCard extends StatelessWidget {
  final dynamic event;
  const _ActivityEventCard({required this.event});

  String get _icon {
    switch (event.eventType) {
      case 'brew':
        return '\u2615'; // coffee emoji
      case 'save':
        return '\ud83d\udccc'; // pin emoji
      case 'create':
        return '\u2728'; // sparkles emoji
      default:
        return '\u2022';
    }
  }

  String get _label {
    final handle = event.handle ?? event.did;
    switch (event.eventType) {
      case 'brew':
        return '$handle brewed';
      case 'save':
        return '$handle saved a recipe';
      case 'create':
        return '$handle shared a recipe';
      default:
        return handle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(event.createdAt);

    return Container(
      padding: const EdgeInsets.all(BrewSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(_icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: BrewSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label, style: BrewTypography.body),
                Text(timeAgo, style: BrewTypography.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat.MMMd().format(date);
  }
}
