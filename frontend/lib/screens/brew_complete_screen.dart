import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../theme/gradients.dart';
import '../copy/strings.dart';
import '../providers/brew_session_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/focus_guard_provider.dart';
import '../widgets/gradient_scaffold.dart';
import 'haiku_composer_screen.dart';
import 'timer_selection_screen.dart';

class BrewCompleteScreen extends ConsumerStatefulWidget {
  const BrewCompleteScreen({super.key});

  @override
  ConsumerState<BrewCompleteScreen> createState() =>
      _BrewCompleteScreenState();
}

class _BrewCompleteScreenState extends ConsumerState<BrewCompleteScreen> {
  @override
  void initState() {
    super.initState();
    _recordBrew();
  }

  Future<void> _recordBrew() async {
    final session = ref.read(brewSessionProvider);
    if (session.timer == null) return;

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      final brewService = ref.read(brewServiceProvider);
      await brewService.createBrew(
        timerUri: session.timer!.uri,
        stepValues: session.stepValuesList.isNotEmpty
            ? session.stepValuesList
            : null,
      );
    }
  }

  void _composeHaiku() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HaikuComposerScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _backToTimers() {
    ref.read(brewSessionProvider.notifier).reset();
    ref.read(focusGuardProvider.notifier).reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TimerSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(brewSessionProvider);

    final totalMinutes = session.totalDuration?.inMinutes ?? 0;
    final totalSeconds = (session.totalDuration?.inSeconds ?? 0) % 60;

    return GradientScaffold(
      gradient: BrewGradients.surface,
      body: Padding(
        padding: const EdgeInsets.all(BrewSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(S.brewComplete, style: BrewTypography.heading),
            const SizedBox(height: BrewSpacing.xl),
            Text(
              '${totalMinutes}m ${totalSeconds}s',
              style: BrewTypography.timer.copyWith(fontSize: 48),
            ),
            const SizedBox(height: BrewSpacing.sm),
            if (session.interruptions > 0)
              Text(
                '${session.interruptions} interruption${session.interruptions == 1 ? '' : 's'}',
                style: BrewTypography.bodySmall,
              ),
            const Spacer(),
            // Compose haiku always available — offline posts queue
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _composeHaiku,
                child: Text(S.composeHaiku, style: BrewTypography.button),
              ),
            ),
            const SizedBox(height: BrewSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _backToTimers,
                child: Text(S.backToTimers, style: BrewTypography.label),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
