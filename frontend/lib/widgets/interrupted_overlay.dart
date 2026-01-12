import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/focus_guard_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Overlay displayed when the user returns to the app after backgrounding.
///
/// Features:
/// - BackdropFilter blur effect
/// - Shows time spent away
/// - Requires 2-second long-press to dismiss
/// - Haptic feedback on completion
class InterruptedOverlay extends ConsumerStatefulWidget {
  /// Child widget to display behind the overlay
  final Widget child;

  const InterruptedOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<InterruptedOverlay> createState() => _InterruptedOverlayState();
}

class _InterruptedOverlayState extends ConsumerState<InterruptedOverlay>
    with SingleTickerProviderStateMixin {
  /// Timer for updating the time display
  Timer? _updateTimer;

  /// Animation controller for the long-press progress
  late AnimationController _progressController;

  /// Whether the user is currently pressing
  bool _isPressing = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _completeReturn();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startUpdate() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopUpdate() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void _startPress() {
    setState(() => _isPressing = true);
    HapticFeedback.lightImpact();
    _progressController.forward(from: 0.0);
  }

  void _cancelPress() {
    setState(() => _isPressing = false);
    _progressController.stop();
    _progressController.reset();
  }

  void _completeReturn() {
    HapticFeedback.heavyImpact();
    ref.read(focusGuardProvider.notifier).acknowledgeReturn();
    setState(() => _isPressing = false);
    _progressController.reset();
    _stopUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final focusGuard = ref.watch(focusGuardProvider);
    final isInterrupted = focusGuard.isInterrupted && focusGuard.isActive;

    // Start/stop timer updates based on interruption state
    if (isInterrupted && _updateTimer == null) {
      _startUpdate();
    } else if (!isInterrupted && _updateTimer != null) {
      _stopUpdate();
    }

    return Stack(
      children: [
        widget.child,
        if (isInterrupted)
          _InterruptedOverlayContent(
            focusGuard: focusGuard,
            isPressing: _isPressing,
            progressController: _progressController,
            onPressStart: _startPress,
            onPressCancel: _cancelPress,
          ),
      ],
    );
  }
}

/// The actual overlay content
class _InterruptedOverlayContent extends StatelessWidget {
  final FocusGuardState focusGuard;
  final bool isPressing;
  final AnimationController progressController;
  final VoidCallback onPressStart;
  final VoidCallback onPressCancel;

  const _InterruptedOverlayContent({
    required this.focusGuard,
    required this.isPressing,
    required this.progressController,
    required this.onPressStart,
    required this.onPressCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  'Ritual Interrupted',
                  style: textTheme.headlineMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),

                // Time away message
                Text(
                  'You were away for',
                  style: textTheme.bodyLarge?.copyWith(color: secondaryColor),
                ),

                const SizedBox(height: 8),

                // Time display
                Text(
                  focusGuard.formattedCurrentInterruption,
                  style: textTheme.displayMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 8),

                // Interruption count
                if (focusGuard.interruptionCount > 1)
                  Text(
                    '${focusGuard.interruptionCount} interruptions this session',
                    style: textTheme.bodySmall?.copyWith(color: secondaryColor),
                  ),

                const SizedBox(height: 48),

                // Instruction
                Text(
                  'Long-press to return',
                  style: textTheme.bodyMedium?.copyWith(color: secondaryColor),
                ),

                const SizedBox(height: 16),

                // Return button with progress
                _ReturnButton(
                  isPressing: isPressing,
                  progressController: progressController,
                  onPressStart: onPressStart,
                  onPressCancel: onPressCancel,
                  accentColor: accentColor,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // Encouraging message
                Text(
                  'The brew continues...',
                  style: textTheme.bodySmall?.copyWith(
                    color: secondaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The return button with long-press progress indicator
class _ReturnButton extends StatelessWidget {
  final bool isPressing;
  final AnimationController progressController;
  final VoidCallback onPressStart;
  final VoidCallback onPressCancel;
  final Color accentColor;
  final bool isDark;

  const _ReturnButton({
    required this.isPressing,
    required this.progressController,
    required this.onPressStart,
    required this.onPressCancel,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final buttonTextColor =
        isDark ? BrewColors.deepEspresso : BrewColors.softCream;

    return GestureDetector(
      onLongPressStart: (_) => onPressStart(),
      onLongPressEnd: (_) => onPressCancel(),
      onLongPressCancel: onPressCancel,
      child: AnimatedBuilder(
        animation: progressController,
        builder: (context, child) {
          return Container(
            width: 200,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: accentColor,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  // Progress fill
                  FractionallySizedBox(
                    widthFactor: progressController.value,
                    child: Container(
                      color: accentColor,
                    ),
                  ),
                  // Button text
                  Center(
                    child: Text(
                      'Return to Ritual',
                      style: textTheme.titleMedium?.copyWith(
                        color: progressController.value > 0.5
                            ? buttonTextColor
                            : accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Standalone widget that can wrap any screen to add interruption handling
class FocusGuardWrapper extends ConsumerWidget {
  /// The child widget to wrap
  final Widget child;

  /// Whether to activate focus guard on mount
  final bool autoActivate;

  const FocusGuardWrapper({
    super.key,
    required this.child,
    this.autoActivate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InterruptedOverlay(child: child);
  }
}
