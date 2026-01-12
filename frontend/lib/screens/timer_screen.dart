import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_model.dart';
import '../providers/timer_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Active timer screen displaying the brew in progress.
///
/// Features:
/// - CustomPainter timer animation (steam rising / circular progress)
/// - Current step display with countdown
/// - Total time remaining
/// - Step indicator for multi-step brews
/// - Optional audio chimes for step transitions
class TimerScreen extends ConsumerStatefulWidget {
  /// The timer being run
  final TimerModel timer;

  /// Callback when timer completes
  final VoidCallback? onComplete;

  /// Callback to go back/cancel
  final VoidCallback? onCancel;

  /// Enable audio chimes for step transitions
  final bool enableChimes;

  const TimerScreen({
    super.key,
    required this.timer,
    this.onComplete,
    this.onCancel,
    this.enableChimes = true,
  });

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _lastStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Initialize timer with the timer model
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(timerStateProvider.notifier).initializeFromModel(widget.timer);
      ref.read(timerStateProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _playChime() {
    if (widget.enableChimes) {
      HapticFeedback.mediumImpact();
      // Audio chime would be played here with audioplayers package
      // For now, just haptic feedback
    }
  }

  void _handleStepChange(int newStepIndex) {
    if (newStepIndex != _lastStepIndex) {
      _playChime();
      _lastStepIndex = newStepIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    // Detect step changes for chime
    _handleStepChange(timerState.currentStepIndex);

    // Handle completion
    if (timerState.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete?.call();
      });
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: widget.onCancel != null
            ? IconButton(
                icon: Icon(Icons.close, color: textColor),
                onPressed: widget.onCancel,
              )
            : null,
        title: Text(
          widget.timer.name,
          style: textTheme.titleMedium?.copyWith(color: textColor),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            if (timerState.steps.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: StepIndicator(
                  totalSteps: timerState.steps.length,
                  currentStep: timerState.currentStepIndex,
                  isDark: isDark,
                ),
              ),

            // Timer visualization
            Expanded(
              flex: 3,
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return TimerVisualization(
                      progress: timerState.stepProgress,
                      isRunning: timerState.isRunning,
                      brewType: widget.timer.brewType,
                      animationValue: _animationController.value,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            ),

            // Current step action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                timerState.currentStep?.action ?? 'Preparing...',
                style: textTheme.titleLarge?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Time display
            _TimeDisplay(
              remainingSeconds: timerState.remainingSeconds,
              totalElapsedSeconds: timerState.totalElapsedSeconds,
              isIndeterminate:
                  timerState.currentStep?.stepType == StepType.indeterminate,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Action button (for indeterminate steps)
            if (timerState.isWaitingForUser)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(timerStateProvider.notifier).completeIndeterminateStep();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor:
                        isDark ? BrewColors.deepEspresso : BrewColors.softCream,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? BrewColors.deepEspresso
                          : BrewColors.softCream,
                    ),
                  ),
                ),
              ),

            // Total time remaining
            if (timerState.totalTimedDuration > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      'Total Remaining',
                      style: textTheme.labelSmall?.copyWith(color: secondaryColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(
                        timerState.totalTimedDuration -
                            timerState.elapsedTimedSeconds,
                      ),
                      style: textTheme.bodyLarge?.copyWith(color: secondaryColor),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Circular timer visualization with steam/fill animation
class TimerVisualization extends StatelessWidget {
  final double progress;
  final bool isRunning;
  final String brewType;
  final double animationValue;
  final bool isDark;

  const TimerVisualization({
    super.key,
    required this.progress,
    required this.isRunning,
    required this.brewType,
    required this.animationValue,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.6;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TimerPainter(
          progress: progress,
          isRunning: isRunning,
          brewType: brewType,
          animationValue: animationValue,
          isDark: isDark,
        ),
      ),
    );
  }
}

/// CustomPainter for the timer animation
class _TimerPainter extends CustomPainter {
  final double progress;
  final bool isRunning;
  final String brewType;
  final double animationValue;
  final bool isDark;

  _TimerPainter({
    required this.progress,
    required this.isRunning,
    required this.brewType,
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    // Colors based on brew type and theme
    final Color baseColor;
    final Color accentColor;
    final Color steamColor;

    if (brewType == 'coffee') {
      baseColor = isDark ? BrewColors.warmBrown : const Color(0xFF9C7B5C);
      accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
      steamColor = isDark
          ? BrewColors.softCream.withOpacity(0.3)
          : BrewColors.warmBrown.withOpacity(0.2);
    } else {
      baseColor = isDark ? BrewColors.accentSage : const Color(0xFF7D9B76);
      accentColor = isDark ? BrewColors.accentSage : const Color(0xFF5E8B5A);
      steamColor = isDark
          ? BrewColors.accentSage.withOpacity(0.3)
          : BrewColors.accentSage.withOpacity(0.2);
    }

    // Background circle
    final bgPaint = Paint()
      ..color = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc (background track)
    final trackPaint = Paint()
      ..color = isDark ? BrewColors.mistDark : BrewColors.mistLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 20, trackPaint);

    // Progress arc (filled portion)
    final progressPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 20),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );

    // Draw steam particles when running
    if (isRunning) {
      _drawSteam(canvas, center, radius, steamColor);
    }

    // Center vessel icon
    _drawVesselIcon(canvas, center, baseColor);
  }

  void _drawSteam(Canvas canvas, Offset center, double radius, Color color) {
    final steamPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Multiple steam particles rising with wave motion
    for (int i = 0; i < 5; i++) {
      final baseOffset = (animationValue + i * 0.2) % 1.0;
      final y = center.dy - 20 - (baseOffset * radius * 0.6);
      final xWave = math.sin((animationValue + i * 0.5) * math.pi * 2) * 15;
      final x = center.dx + xWave + (i - 2) * 12;
      final opacity = (1.0 - baseOffset) * 0.7;
      final particleRadius = 6.0 + (1.0 - baseOffset) * 8;

      steamPaint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), particleRadius, steamPaint);
    }
  }

  void _drawVesselIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Simple cup/mug outline
    final cupWidth = 40.0;
    final cupHeight = 35.0;
    final cupTop = center.dy + 10;
    final cupLeft = center.dx - cupWidth / 2;

    // Cup body
    final cupPath = Path()
      ..moveTo(cupLeft, cupTop)
      ..lineTo(cupLeft + 5, cupTop + cupHeight)
      ..lineTo(cupLeft + cupWidth - 5, cupTop + cupHeight)
      ..lineTo(cupLeft + cupWidth, cupTop);

    canvas.drawPath(cupPath, paint);

    // Handle
    final handlePath = Path()
      ..moveTo(cupLeft + cupWidth, cupTop + 8)
      ..quadraticBezierTo(
        cupLeft + cupWidth + 15,
        cupTop + cupHeight / 2,
        cupLeft + cupWidth,
        cupTop + cupHeight - 8,
      );

    canvas.drawPath(handlePath, paint);
  }

  @override
  bool shouldRepaint(covariant _TimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.isDark != isDark;
  }
}

/// Time display showing countdown or elapsed time
class _TimeDisplay extends StatelessWidget {
  final int remainingSeconds;
  final int totalElapsedSeconds;
  final bool isIndeterminate;
  final bool isDark;

  const _TimeDisplay({
    required this.remainingSeconds,
    required this.totalElapsedSeconds,
    required this.isIndeterminate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    final displayTime = isIndeterminate
        ? _formatDuration(totalElapsedSeconds)
        : _formatDuration(remainingSeconds);

    final label = isIndeterminate ? 'Elapsed' : 'Remaining';

    return Column(
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          displayTime,
          style: textTheme.displayMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) seconds = 0;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Step indicator showing progress through multi-step brews
class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final bool isDark;

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final completedColor =
        isDark ? BrewColors.timerComplete : BrewColors.success;

    return Column(
      children: [
        // Step text
        Text(
          'Step ${currentStep + 1} of $totalSteps',
          style: textTheme.labelSmall?.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 8),
        // Step dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalSteps, (index) {
            final isCompleted = index < currentStep;
            final isCurrent = index == currentStep;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isCurrent ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isCompleted
                    ? completedColor
                    : isCurrent
                        ? accentColor
                        : (isDark ? BrewColors.mistDark : BrewColors.mistLight),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Standalone timer progress widget for embedding in other screens
class TimerProgress extends StatelessWidget {
  final double progress;
  final String brewType;
  final bool isDark;

  const TimerProgress({
    super.key,
    required this.progress,
    required this.brewType,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return TimerVisualization(
      progress: progress,
      isRunning: true,
      brewType: brewType,
      animationValue: 0,
      isDark: isDark,
    );
  }
}
