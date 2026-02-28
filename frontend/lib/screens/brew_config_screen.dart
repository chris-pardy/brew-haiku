import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/timer_model.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../copy/strings.dart';
import '../providers/brew_session_provider.dart';
import '../widgets/gradient_scaffold.dart';
import '../theme/gradients.dart';
import 'brew_session_screen.dart';

class BrewConfigScreen extends ConsumerWidget {
  final BrewTimer timer;

  const BrewConfigScreen({super.key, required this.timer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = timer.brewType == 'tea'
        ? BrewGradients.tea
        : timer.brewType == 'coffee'
            ? BrewGradients.coffee
            : BrewGradients.defaultBackground;

    return GradientScaffold(
      gradient: gradient,
      appBar: AppBar(
        title: Text(S.configTitle, style: BrewTypography.heading),
      ),
      body: Padding(
        padding: const EdgeInsets.all(BrewSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: BrewSpacing.lg),
            Text(timer.name, style: BrewTypography.heading),
            const SizedBox(height: BrewSpacing.sm),
            Row(
              children: [
                _InfoChip(label: timer.vessel),
                const SizedBox(width: BrewSpacing.sm),
                _InfoChip(label: timer.brewType),
                if (timer.ratio != null) ...[
                  const SizedBox(width: BrewSpacing.sm),
                  _InfoChip(label: '1:${timer.ratio!.toStringAsFixed(0)}'),
                ],
              ],
            ),
            if (timer.notes != null && timer.notes!.isNotEmpty) ...[
              const SizedBox(height: BrewSpacing.base),
              Text(
                timer.notes!,
                style: BrewTypography.body.copyWith(
                  color: BrewColors.darkInk.withValues(alpha: 0.85),
                ),
              ),
            ],
            const SizedBox(height: BrewSpacing.lg),
            Text('Steps', style: BrewTypography.label),
            const SizedBox(height: BrewSpacing.sm),
            Expanded(
              child: ListView.separated(
                itemCount: timer.steps.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: BrewSpacing.sm),
                itemBuilder: (context, index) {
                  final step = timer.steps[index];
                  return Container(
                    padding: const EdgeInsets.all(BrewSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: BrewColors.warmAmber.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: BrewTypography.labelSmall,
                          ),
                        ),
                        const SizedBox(width: BrewSpacing.md),
                        Expanded(
                          child: Text(step.action, style: BrewTypography.body),
                        ),
                        if (step.isTimed)
                          Text(
                            _formatDuration(step.durationSeconds ?? 0),
                            style: BrewTypography.label,
                          ),
                        if (step.isIndeterminate)
                          const Icon(
                            Icons.touch_app_outlined,
                            color: BrewColors.subtle,
                            size: 20,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: BrewSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(brewSessionProvider.notifier).configure(timer);
                  ref.read(brewSessionProvider.notifier).startBrew();
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const BrewSessionScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(
                            opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 500),
                    ),
                  );
                },
                child: Text(S.startBrew, style: BrewTypography.button),
              ),
            ),
            const SizedBox(height: BrewSpacing.base),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BrewSpacing.md,
        vertical: BrewSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: BrewTypography.labelSmall),
    );
  }
}
