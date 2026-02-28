import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../theme/gradients.dart';
import '../copy/strings.dart';
import '../providers/haiku_composer_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/brew_session_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/gradient_scaffold.dart';
import 'sign_in_screen.dart';
import 'activity_feed_screen.dart';
import 'timer_selection_screen.dart';

class HaikuComposerScreen extends ConsumerStatefulWidget {
  const HaikuComposerScreen({super.key});

  @override
  ConsumerState<HaikuComposerScreen> createState() =>
      _HaikuComposerScreenState();
}

class _HaikuComposerScreenState extends ConsumerState<HaikuComposerScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _posting = false;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (_updating) return;
    _updating = true;

    final display = ref.read(haikuComposerProvider.notifier).updateText(text);

    // Update the text field with linebreaks inserted, preserving cursor
    if (display != _controller.text) {
      // Place cursor at end since we're reformatting
      _controller.value = TextEditingValue(
        text: display,
        selection: TextSelection.collapsed(offset: display.length),
      );
    }

    _updating = false;
  }

  Future<void> _post() async {
    final composer = ref.read(haikuComposerProvider);
    if (!composer.isComplete) return;

    final auth = ref.read(authProvider);
    final isOnline = ref.read(connectivityProvider);

    if (!auth.isAuthenticated) {
      if (!isOnline) {
        await ref.read(haikuComposerProvider.notifier).queueOfflinePost();
        _showSnackBar(S.offlineComposer);
        _goToTimers();
        return;
      }
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const SignInScreen(returnAfterAuth: true),
        ),
      );
      if (!ref.read(authProvider).isAuthenticated) return;
    }

    setState(() => _posting = true);
    try {
      if (!isOnline) {
        await ref.read(haikuComposerProvider.notifier).queueOfflinePost();
        _showSnackBar(S.offlineComposer);
        _goToTimers();
        return;
      }

      final bluesky = ref.read(blueskyServiceProvider);
      final authNotifier = ref.read(authProvider.notifier);
      final pdsUrl = await authNotifier.getPdsUrl();

      final postUri = await bluesky.postHaiku(
        lines: composer.lines,
        session: ref.read(authProvider).session!,
        pdsUrl: pdsUrl,
      );

      final session = ref.read(brewSessionProvider);
      if (session.timer != null) {
        final brewService = ref.read(brewServiceProvider);
        await brewService.createBrew(
          timerUri: session.timer!.uri,
          postUri: postUri,
          stepValues: session.stepValuesList.isNotEmpty
              ? session.stepValuesList
              : null,
        );
      }

      ref.read(activityProvider.notifier).unlock();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActivityFeedScreen()),
        );
      }
    } catch (e) {
      _showSnackBar(S.postFailed);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _goToTimers() {
    ref.read(haikuComposerProvider.notifier).reset();
    ref.read(brewSessionProvider.notifier).reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TimerSelectionScreen()),
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: BrewTypography.bodySmall),
        backgroundColor: BrewColors.darkInk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final composer = ref.watch(haikuComposerProvider);
    final isOnline = ref.watch(connectivityProvider);

    return GradientScaffold(
      gradient: BrewGradients.surface,
      appBar: AppBar(
        title: Text(S.composeHaiku, style: BrewTypography.heading),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(BrewSpacing.screenPadding),
        child: Column(
          children: [
            const Spacer(),
            // The haiku — a single text field with auto linebreaks
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onTextChanged,
              style: BrewTypography.haikuLine,
              maxLines: 5,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: S.composerHint,
                hintStyle: BrewTypography.haikuLine.copyWith(
                  color: BrewColors.subtle.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: BrewSpacing.base,
                  horizontal: BrewSpacing.base,
                ),
              ),
            ),
            const SizedBox(height: BrewSpacing.lg),
            // Subtle syllable dots: filled for each syllable reached
            _SyllableDots(counts: composer.syllableCounts),
            if (!isOnline) ...[
              const SizedBox(height: BrewSpacing.base),
              Text(
                S.offlineComposer,
                style: BrewTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: composer.isComplete && !_posting ? _post : null,
                child: _posting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrewColors.warmCream,
                        ),
                      )
                    : Text(S.postHaiku, style: BrewTypography.button),
              ),
            ),
            const SizedBox(height: BrewSpacing.md),
            TextButton(
              onPressed: _goToTimers,
              child: Text(S.notNow, style: BrewTypography.label),
            ),
            const SizedBox(height: BrewSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Subtle dots showing syllable progress for each line.
/// 5 dots / 7 dots / 5 dots, separated by small gaps.
class _SyllableDots extends StatelessWidget {
  final List<int> counts;

  const _SyllableDots({required this.counts});

  @override
  Widget build(BuildContext context) {
    const targets = HaikuComposerState.targetSyllables;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var line = 0; line < 3; line++) ...[
          if (line > 0)
            const SizedBox(width: BrewSpacing.md),
          for (var dot = 0; dot < targets[line]; dot++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dot < counts[line]
                      ? BrewColors.warmAmber
                      : BrewColors.warmAmber.withValues(alpha: 0.2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
