import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/gradients.dart';
import '../providers/brew_session_provider.dart';
import '../providers/haiku_feed_provider.dart';
import '../providers/focus_guard_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/timer_step_view.dart';
import '../widgets/haiku_card.dart';
import '../widgets/steam_animation.dart';
import '../widgets/interrupted_overlay.dart';
import 'brew_complete_screen.dart';

class BrewSessionScreen extends ConsumerStatefulWidget {
  const BrewSessionScreen({super.key});

  @override
  ConsumerState<BrewSessionScreen> createState() => _BrewSessionScreenState();
}

class _BrewSessionScreenState extends ConsumerState<BrewSessionScreen> {
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Prefetch haiku feed (deferred to avoid modifying state during build)
    Future.microtask(() {
      final isOnline = ref.read(connectivityProvider);
      if (isOnline) {
        final brewType = ref.read(brewSessionProvider).timer?.brewType;
        ref.read(haikuFeedProvider.notifier).loadFeed(brewType: brewType);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(brewSessionProvider);
    final focusGuard = ref.watch(focusGuardProvider);
    final isOnline = ref.watch(connectivityProvider);
    final feedState = ref.watch(haikuFeedProvider);

    // Navigate to complete when done
    if (session.phase == BrewPhase.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const BrewCompleteScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    }

    final step = session.currentStep;
    if (step == null) return const SizedBox.shrink();

    final gradient = session.timer?.brewType == 'tea'
        ? BrewGradients.tea
        : session.timer?.brewType == 'coffee'
            ? BrewGradients.coffee
            : BrewGradients.defaultBackground;

    final showHaiku = isOnline &&
        (feedState.posts.isNotEmpty || feedState.loading);

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          GradientScaffold(
            gradient: gradient,
            body: Column(
              children: [
                const SizedBox(height: BrewSpacing.xxl),
                // Timer / step view
                Expanded(
                  flex: showHaiku ? 3 : 5,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (step.isTimed) const SteamAnimation(height: 60),
                        const SizedBox(height: BrewSpacing.base),
                        TimerStepView(
                          step: step,
                          stepIndex: session.currentStepIndex,
                          totalSteps: session.timer!.steps.length,
                          remainingSeconds: session.stepRemainingSeconds,
                          progress: session.stepProgress,
                          onComplete: () => ref
                              .read(brewSessionProvider.notifier)
                              .completeCurrentStep(),
                          onQuantitySubmit: (value) => ref
                              .read(brewSessionProvider.notifier)
                              .completeCurrentStep(value: value),
                        ),
                      ],
                    ),
                  ),
                ),
                // Haiku feed during timed waits
                if (showHaiku)
                  Expanded(
                    flex: 2,
                    child: feedState.posts.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BrewColors.warmAmber,
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: feedState.posts.length,
                            onPageChanged: (index) {
                              if (index >= feedState.posts.length - 3) {
                                ref.read(haikuFeedProvider.notifier).loadMore();
                              }
                            },
                            itemBuilder: (_, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: BrewSpacing.screenPadding,
                                ),
                                child: HaikuCard(
                                    post: feedState.posts[index]),
                              );
                            },
                          ),
                  ),
                const SizedBox(height: BrewSpacing.lg),
              ],
            ),
          ),
          // Focus guard overlay
          if (focusGuard.isAway && session.phase == BrewPhase.brewing)
            Positioned.fill(
              child: InterruptedOverlay(
                onDismiss: () =>
                    ref.read(focusGuardProvider.notifier).dismiss(),
              ),
            ),
        ],
      ),
    );
  }
}
