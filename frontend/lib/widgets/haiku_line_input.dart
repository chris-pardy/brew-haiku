import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class HaikuLineInput extends StatelessWidget {
  final int lineNumber;
  final int currentSyllables;
  final int targetSyllables;
  final bool isActive;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;

  const HaikuLineInput({
    super.key,
    required this.lineNumber,
    required this.currentSyllables,
    required this.targetSyllables,
    required this.isActive,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = targetSyllables > 0
        ? (currentSyllables / targetSyllables).clamp(0.0, 1.0)
        : 0.0;
    final isComplete = currentSyllables == targetSyllables;
    final isOver = currentSyllables > targetSyllables;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: BrewTypography.haikuLine.copyWith(
              color: isActive ? BrewColors.darkInk : BrewColors.subtle,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Line ${lineNumber + 1}',
              hintStyle: BrewTypography.haikuLine.copyWith(
                color: BrewColors.subtle.withValues(alpha: 0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: BrewSpacing.sm,
              ),
            ),
          ),
          const SizedBox(height: BrewSpacing.xs),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: BrewColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOver
                          ? BrewColors.error
                          : isComplete
                              ? BrewColors.success
                              : BrewColors.warmAmber,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: BrewSpacing.sm),
              Text(
                '$currentSyllables/$targetSyllables',
                style: BrewTypography.labelSmall.copyWith(
                  color: isOver
                      ? BrewColors.error
                      : isComplete
                          ? BrewColors.success
                          : BrewColors.subtle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
