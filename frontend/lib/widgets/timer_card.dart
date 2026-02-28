import 'package:flutter/material.dart';
import '../models/timer_model.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class TimerCard extends StatelessWidget {
  final BrewTimer timer;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final bool pinned;

  const TimerCard({
    super.key,
    required this.timer,
    required this.onTap,
    this.onPin,
    this.pinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSaved = pinned || (timer.saved ?? false);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(BrewSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timer.name,
                style: BrewTypography.headingSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: BrewSpacing.sm),
              Row(
                children: [
                  _Badge(label: timer.vessel),
                  const SizedBox(width: BrewSpacing.sm),
                  _Badge(label: timer.brewType),
                ],
              ),
              if (onPin != null) ...[
                const SizedBox(height: BrewSpacing.sm),
                GestureDetector(
                  onTap: onPin,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: isSaved
                              ? BrewColors.warmAmber
                              : BrewColors.subtle,
                          size: 18,
                        ),
                        if (timer.saveCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${timer.saveCount}',
                            style: BrewTypography.labelSmall.copyWith(
                              color: isSaved
                                  ? BrewColors.warmAmber
                                  : BrewColors.subtle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrewSpacing.sm,
        vertical: BrewSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: BrewColors.warmAmber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: BrewTypography.labelSmall.copyWith(
          color: BrewColors.darkInk,
        ),
      ),
    );
  }
}
