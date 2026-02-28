import 'package:flutter/material.dart';
import '../models/timer_model.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../copy/strings.dart';
import 'brew_timer_display.dart';

class TimerStepView extends StatefulWidget {
  final TimerStep step;
  final int stepIndex;
  final int totalSteps;
  final int remainingSeconds;
  final double progress;
  final VoidCallback onComplete;
  final void Function(double value)? onQuantitySubmit;

  const TimerStepView({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.remainingSeconds,
    required this.progress,
    required this.onComplete,
    this.onQuantitySubmit,
  });

  @override
  State<TimerStepView> createState() => _TimerStepViewState();
}

class _TimerStepViewState extends State<TimerStepView> {
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submitQuantity() {
    final value = double.tryParse(_quantityController.text);
    if (value != null && widget.onQuantitySubmit != null) {
      widget.onQuantitySubmit!(value);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnit = widget.step.unit != null && widget.step.unit!.isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Step ${widget.stepIndex + 1} of ${widget.totalSteps}',
          style: BrewTypography.label,
        ),
        const SizedBox(height: BrewSpacing.xl),
        if (widget.step.isTimed)
          BrewTimerDisplay(
            remainingSeconds: widget.remainingSeconds,
            progress: widget.progress,
            stepName: widget.step.action,
          )
        else ...[
          Text(
            widget.step.action,
            style: BrewTypography.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BrewSpacing.xl),
          if (hasUnit) ...[
            SizedBox(
              width: 160,
              child: TextField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: BrewTypography.timer.copyWith(fontSize: 36),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: BrewTypography.timer.copyWith(
                    fontSize: 36,
                    color: BrewColors.subtle.withValues(alpha: 0.4),
                  ),
                  suffixText: widget.step.unit,
                  suffixStyle: BrewTypography.label,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: BrewSpacing.sm,
                  ),
                ),
                onSubmitted: (_) => _submitQuantity(),
              ),
            ),
            const SizedBox(height: BrewSpacing.lg),
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitQuantity,
                child: Text(S.tapWhenDone, style: BrewTypography.button),
              ),
            ),
          ] else
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton(
                onPressed: widget.onComplete,
                child: Text(S.tapWhenDone, style: BrewTypography.button),
              ),
            ),
        ],
      ],
    );
  }
}
