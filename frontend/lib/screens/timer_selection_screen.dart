import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/default_timers.dart';
import '../data/vessels.dart';
import '../models/timer_model.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Screen for selecting a timer or vessel to start brewing.
///
/// Displays:
/// - Default timers grouped by brew type (coffee/tea)
/// - Pre-configured vessels for custom timer creation
/// - Option to create a fully custom timer
class TimerSelectionScreen extends ConsumerStatefulWidget {
  /// Callback when a timer is selected
  final void Function(TimerModel timer)? onTimerSelected;

  /// Callback when a vessel is selected for custom timer creation
  final void Function(Vessel vessel)? onVesselSelected;

  /// Callback when custom timer creation is requested
  final VoidCallback? onCreateCustom;

  const TimerSelectionScreen({
    super.key,
    this.onTimerSelected,
    this.onVesselSelected,
    this.onCreateCustom,
  });

  @override
  ConsumerState<TimerSelectionScreen> createState() =>
      _TimerSelectionScreenState();
}

class _TimerSelectionScreenState extends ConsumerState<TimerSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Start a Brew',
          style: textTheme.titleLarge?.copyWith(color: textColor),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor:
              isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight,
          indicatorColor: accentColor,
          tabs: const [
            Tab(text: 'Coffee'),
            Tab(text: 'Tea'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BrewTypeTab(
            brewType: 'coffee',
            timers: DefaultTimers.coffeeTimers,
            vessels: Vessels.coffeeVessels,
            onTimerSelected: widget.onTimerSelected,
            onVesselSelected: widget.onVesselSelected,
            isDark: isDark,
          ),
          _BrewTypeTab(
            brewType: 'tea',
            timers: DefaultTimers.teaTimers,
            vessels: Vessels.teaVessels,
            onTimerSelected: widget.onTimerSelected,
            onVesselSelected: widget.onVesselSelected,
            isDark: isDark,
          ),
        ],
      ),
      floatingActionButton: widget.onCreateCustom != null
          ? FloatingActionButton.extended(
              onPressed: widget.onCreateCustom,
              backgroundColor: accentColor,
              foregroundColor:
                  isDark ? BrewColors.deepEspresso : BrewColors.softCream,
              icon: const Icon(Icons.add),
              label: const Text('Custom Timer'),
            )
          : null,
    );
  }
}

/// Tab content for a specific brew type (coffee or tea)
class _BrewTypeTab extends StatelessWidget {
  final String brewType;
  final List<TimerModel> timers;
  final List<Vessel> vessels;
  final void Function(TimerModel timer)? onTimerSelected;
  final void Function(Vessel vessel)? onVesselSelected;
  final bool isDark;

  const _BrewTypeTab({
    required this.brewType,
    required this.timers,
    required this.vessels,
    this.onTimerSelected,
    this.onVesselSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final sectionColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Start section (default timers)
        if (timers.isNotEmpty) ...[
          _SectionHeader(
            title: 'Quick Start',
            subtitle: 'Ready-to-use recipes',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          ...timers.map((timer) => _TimerCard(
                timer: timer,
                onTap: () => onTimerSelected?.call(timer),
                isDark: isDark,
              )),
          const SizedBox(height: 24),
        ],

        // Vessels section
        if (vessels.isNotEmpty) ...[
          _SectionHeader(
            title: 'Choose a Vessel',
            subtitle: 'Start with a template',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: vessels.length,
            itemBuilder: (context, index) {
              final vessel = vessels[index];
              return _VesselCard(
                vessel: vessel,
                onTap: () => onVesselSelected?.call(vessel),
                isDark: isDark,
              );
            },
          ),
        ],

        // Bottom padding for FAB
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Section header with title and subtitle
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: secondaryColor),
        ),
      ],
    );
  }
}

/// Card displaying a timer recipe
class _TimerCard extends StatelessWidget {
  final TimerModel timer;
  final VoidCallback? onTap;
  final bool isDark;

  const _TimerCard({
    required this.timer,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final cardColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? BrewColors.mistDark
              : BrewColors.mistLight,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  timer.brewType == 'coffee'
                      ? Icons.coffee_outlined
                      : Icons.emoji_food_beverage_outlined,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timer.name,
                      style: textTheme.titleSmall?.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${timer.vessel} • ${timer.formattedDuration}',
                      style:
                          textTheme.bodySmall?.copyWith(color: secondaryColor),
                    ),
                  ],
                ),
              ),

              // Ratio badge
              if (timer.ratio != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${timer.ratio!.toStringAsFixed(timer.ratio! == timer.ratio!.truncateToDouble() ? 0 : 1)}:1',
                    style: textTheme.labelSmall?.copyWith(color: accentColor),
                  ),
                ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: secondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card displaying a vessel for custom timer creation
class _VesselCard extends StatelessWidget {
  final Vessel vessel;
  final VoidCallback? onTap;
  final bool isDark;

  const _VesselCard({
    required this.vessel,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final cardColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  vessel.category == 'coffee'
                      ? Icons.coffee_outlined
                      : Icons.emoji_food_beverage_outlined,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),

              // Name
              Text(
                vessel.name,
                style: textTheme.titleSmall?.copyWith(color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Details
              Text(
                '${vessel.formattedRatio} • ${vessel.defaultDurationSeconds > 0 ? vessel.formattedDuration : 'Variable'}',
                style: textTheme.bodySmall?.copyWith(color: secondaryColor),
              ),

              const Spacer(),

              // Description
              Text(
                vessel.description,
                style: textTheme.bodySmall?.copyWith(
                  color: secondaryColor,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standalone timer card widget for use in other screens
class TimerCard extends StatelessWidget {
  final TimerModel timer;
  final VoidCallback? onTap;

  const TimerCard({
    super.key,
    required this.timer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _TimerCard(
      timer: timer,
      onTap: onTap,
      isDark: isDark,
    );
  }
}

/// Standalone vessel card widget for use in other screens
class VesselCard extends StatelessWidget {
  final Vessel vessel;
  final VoidCallback? onTap;

  const VesselCard({
    super.key,
    required this.vessel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _VesselCard(
      vessel: vessel,
      onTap: onTap,
      isDark: isDark,
    );
  }
}
