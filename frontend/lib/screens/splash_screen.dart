import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Minimalist splash screen with Brew Haiku logo and app name.
///
/// This screen is displayed while the app initializes. It shows a
/// simple animated logo with the app name and tagline.
class SplashScreen extends StatefulWidget {
  /// Callback invoked when splash animation completes
  final VoidCallback? onComplete;

  /// Duration to display the splash screen
  final Duration duration;

  const SplashScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    _controller.forward();

    // Schedule navigation after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final primaryColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryTextColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    final textTheme = BrewTypography.getTextTheme(isDark: isDark);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo - Steam rising from cup
              SplashLogo(
                size: 120,
                color: primaryColor,
              ),
              const SizedBox(height: 32),
              // App name
              Text(
                'Brew Haiku',
                style: textTheme.displayMedium?.copyWith(
                  color: textColor,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              // Tagline
              Text(
                'mindful moments',
                style: textTheme.bodyLarge?.copyWith(
                  color: secondaryTextColor,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom logo widget depicting a stylized tea/coffee cup with rising steam.
///
/// This is drawn using CustomPainter for a minimalist, scalable look.
class SplashLogo extends StatelessWidget {
  final double size;
  final Color color;

  const SplashLogo({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SplashLogoPainter(color: color),
    );
  }
}

class _SplashLogoPainter extends CustomPainter {
  final Color color;

  _SplashLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final cupWidth = size.width * 0.5;
    final cupHeight = size.height * 0.35;

    // Cup body (rounded rectangle)
    final cupRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + size.height * 0.15),
        width: cupWidth,
        height: cupHeight,
      ),
      Radius.circular(cupWidth * 0.15),
    );

    // Draw cup fill
    canvas.drawRRect(cupRect, fillPaint);
    // Draw cup outline
    canvas.drawRRect(cupRect, paint);

    // Cup handle
    final handlePath = Path();
    final handleStartY = center.dy + size.height * 0.05;
    final handleEndY = center.dy + size.height * 0.25;
    final handleX = center.dx + cupWidth * 0.5;

    handlePath.moveTo(handleX, handleStartY);
    handlePath.quadraticBezierTo(
      handleX + size.width * 0.12,
      center.dy + size.height * 0.15,
      handleX,
      handleEndY,
    );
    canvas.drawPath(handlePath, paint);

    // Steam lines - three wavy lines rising from the cup
    final steamPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round;

    final steamBaseY = center.dy - size.height * 0.05;
    final steamTopY = center.dy - size.height * 0.35;
    final steamSpacing = cupWidth * 0.25;

    for (int i = -1; i <= 1; i++) {
      final steamPath = Path();
      final startX = center.dx + (i * steamSpacing);
      steamPath.moveTo(startX, steamBaseY);

      // Wavy line using cubic bezier curves
      final waveHeight = (steamBaseY - steamTopY) / 3;
      final waveAmplitude = size.width * 0.04 * (i == 0 ? 1.2 : 1.0);

      steamPath.cubicTo(
        startX + waveAmplitude,
        steamBaseY - waveHeight * 0.5,
        startX - waveAmplitude,
        steamBaseY - waveHeight * 1.5,
        startX + waveAmplitude * 0.5,
        steamBaseY - waveHeight * 2,
      );
      steamPath.cubicTo(
        startX + waveAmplitude * 0.8,
        steamBaseY - waveHeight * 2.3,
        startX - waveAmplitude * 0.3,
        steamBaseY - waveHeight * 2.7,
        startX,
        steamTopY,
      );

      canvas.drawPath(steamPath, steamPaint);
    }

    // Saucer - simple line under the cup
    final saucerY = center.dy + size.height * 0.35;
    final saucerWidth = cupWidth * 1.3;
    canvas.drawLine(
      Offset(center.dx - saucerWidth / 2, saucerY),
      Offset(center.dx + saucerWidth / 2, saucerY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
