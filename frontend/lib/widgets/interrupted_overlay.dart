import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../copy/strings.dart';

class InterruptedOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const InterruptedOverlay({super.key, required this.onDismiss});

  @override
  State<InterruptedOverlay> createState() => _InterruptedOverlayState();
}

class _InterruptedOverlayState extends State<InterruptedOverlay> {
  bool _pressing = false;
  double _holdProgress = 0;

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _pressing = true);
    _animateHold();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _pressing = false;
      _holdProgress = 0;
    });
  }

  Future<void> _animateHold() async {
    const steps = 20;
    for (var i = 0; i <= steps; i++) {
      if (!_pressing || !mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _holdProgress = i / steps);
    }
    if (_pressing && mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: BrewColors.darkInk.withValues(alpha: 0.4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.returnToRitual,
                style: BrewTypography.heading.copyWith(
                  color: BrewColors.warmCream,
                ),
              ),
              const SizedBox(height: BrewSpacing.lg),
              GestureDetector(
                onLongPressStart: _onLongPressStart,
                onLongPressEnd: _onLongPressEnd,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: BrewColors.warmCream.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: _holdProgress,
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            BrewColors.warmAmber,
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: BrewColors.warmCream,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BrewSpacing.base),
              Text(
                S.longPressToReturn,
                style: BrewTypography.bodySmall.copyWith(
                  color: BrewColors.warmCream.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
