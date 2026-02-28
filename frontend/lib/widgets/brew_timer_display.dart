import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class BrewTimerDisplay extends StatelessWidget {
  final int remainingSeconds;
  final double progress;
  final String stepName;

  const BrewTimerDisplay({
    super.key,
    required this.remainingSeconds,
    required this.progress,
    required this.stepName,
  });

  String get _formatted {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: BrewColors.warmAmber.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    BrewColors.warmAmber,
                  ),
                ),
              ),
              Text(_formatted, style: BrewTypography.timer),
            ],
          ),
        ),
        const SizedBox(height: BrewSpacing.base),
        Text(
          stepName,
          style: BrewTypography.body,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
