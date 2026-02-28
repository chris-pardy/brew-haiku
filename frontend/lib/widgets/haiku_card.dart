import 'package:flutter/material.dart';
import '../models/haiku_post.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../theme/animations.dart';

class HaikuCard extends StatefulWidget {
  final HaikuPost post;

  const HaikuCard({super.key, required this.post});

  @override
  State<HaikuCard> createState() => _HaikuCardState();
}

class _HaikuCardState extends State<HaikuCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: BrewAnimations.slow,
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.post.haikuLines;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: BrewAnimations.entryCurve,
      ),
      child: Container(
        padding: const EdgeInsets.all(BrewSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: BrewTypography.haikuLine,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: BrewSpacing.md),
            Text(
              widget.post.authorHandle != null
                  ? '@${widget.post.authorHandle}'
                  : '',
              style: BrewTypography.labelSmall.copyWith(
                color: BrewColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
