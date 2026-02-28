import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SteamAnimation extends StatefulWidget {
  final double height;

  const SteamAnimation({super.key, this.height = 120});

  @override
  State<SteamAnimation> createState() => _SteamAnimationState();
}

class _SteamAnimationState extends State<SteamAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(80, widget.height),
          painter: _SteamPainter(_controller.value),
        );
      },
    );
  }
}

class _SteamPainter extends CustomPainter {
  final double progress;
  _SteamPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final offset = i * 0.33;
      final t = (progress + offset) % 1.0;
      final opacity = (1 - t) * 0.75;

      paint.color = BrewColors.darkInk.withValues(alpha: opacity);

      final x = size.width / 2 + sin(t * pi * 2 + i) * 10;
      final startY = size.height;
      final endY = size.height * (1 - t);

      final path = Path();
      path.moveTo(x, startY);
      path.cubicTo(
        x + sin(t * pi * 3) * 15,
        startY - (startY - endY) * 0.33,
        x - sin(t * pi * 2) * 15,
        startY - (startY - endY) * 0.66,
        x + sin(t * pi) * 5,
        endY,
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SteamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
