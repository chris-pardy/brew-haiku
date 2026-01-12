import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Brew context for the share card
class BrewContext {
  final String vessel;
  final Duration brewTime;
  final double? ratio;
  final String brewType;

  const BrewContext({
    required this.vessel,
    required this.brewTime,
    this.ratio,
    this.brewType = 'coffee',
  });

  String get formattedTime {
    final minutes = brewTime.inMinutes;
    final seconds = brewTime.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedRatio => ratio != null ? '1:${ratio!.toStringAsFixed(0)}' : '';
}

/// Share card widget that can be exported as an image
class ShareCard extends StatelessWidget {
  final String haiku;
  final BrewContext? brewContext;
  final GlobalKey? repaintKey;

  const ShareCard({
    super.key,
    required this.haiku,
    this.brewContext,
    this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      key: repaintKey,
      child: _ShareCardContent(
        haiku: haiku,
        brewContext: brewContext,
        isDark: isDark,
      ),
    );
  }
}

/// Internal content of the share card
class _ShareCardContent extends StatelessWidget {
  final String haiku;
  final BrewContext? brewContext;
  final bool isDark;

  const _ShareCardContent({
    required this.haiku,
    this.brewContext,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final bgColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final textColor = isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor = isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    final lines = haiku.split('\n');

    return Container(
      width: 350,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Decorative top element
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          const SizedBox(height: 24),

          // Haiku text
          for (int i = 0; i < lines.length; i++) ...[
            Text(
              lines[i],
              style: textTheme.headlineSmall?.copyWith(
                fontFamily: 'Playfair Display',
                fontStyle: FontStyle.italic,
                color: textColor,
                height: 1.8,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (i < lines.length - 1) const SizedBox(height: 4),
          ],

          const SizedBox(height: 24),

          // Decorative bottom element
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          // Brew context if provided
          if (brewContext != null) ...[
            const SizedBox(height: 20),
            _BrewContextDisplay(
              context: brewContext!,
              textColor: secondaryColor,
              textTheme: textTheme,
            ),
          ],

          const SizedBox(height: 16),

          // App signature
          Text(
            'brew-haiku.app',
            style: textTheme.bodySmall?.copyWith(
              color: secondaryColor.withOpacity(0.6),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Brew context display
class _BrewContextDisplay extends StatelessWidget {
  final BrewContext context;
  final Color textColor;
  final TextTheme textTheme;

  const _BrewContextDisplay({
    required this.context,
    required this.textColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      this.context.vessel,
      this.context.formattedTime,
    ];

    if (this.context.formattedRatio.isNotEmpty) {
      items.add(this.context.formattedRatio);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Text(
            items[i],
            style: textTheme.bodySmall?.copyWith(
              color: textColor,
            ),
          ),
          if (i < items.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '·',
                style: textTheme.bodySmall?.copyWith(
                  color: textColor,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Controller for share card actions
class ShareCardController {
  final GlobalKey _repaintKey = GlobalKey();

  GlobalKey get repaintKey => _repaintKey;

  /// Capture the share card as PNG bytes
  Future<Uint8List?> captureAsPng({double pixelRatio = 3.0}) async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Copy haiku text to clipboard
  Future<void> copyText(String haiku) async {
    final text = '$haiku\n\nvia @brew-haiku.app';
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Get the haiku text with signature for sharing
  String getShareText(String haiku) {
    return '$haiku\n\nvia @brew-haiku.app';
  }
}

/// Share options bottom sheet
class ShareOptionsSheet extends StatelessWidget {
  final String haiku;
  final ShareCardController controller;
  final VoidCallback? onShareToBluesky;
  final VoidCallback? onSaveToDevice;
  final VoidCallback? onCopyText;

  const ShareOptionsSheet({
    super.key,
    required this.haiku,
    required this.controller,
    this.onShareToBluesky,
    this.onSaveToDevice,
    this.onCopyText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor = isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final bgColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              'Share Haiku',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),

            const SizedBox(height: 24),

            // Options
            _ShareOption(
              icon: Icons.send_rounded,
              label: 'Share to Bluesky',
              description: 'Post your haiku to your feed',
              onTap: onShareToBluesky,
              isDark: isDark,
            ),

            _ShareOption(
              icon: Icons.save_alt_rounded,
              label: 'Save to Device',
              description: 'Download as image',
              onTap: onSaveToDevice,
              isDark: isDark,
            ),

            _ShareOption(
              icon: Icons.copy_rounded,
              label: 'Copy Text',
              description: 'Copy haiku to clipboard',
              onTap: () {
                controller.copyText(haiku);
                onCopyText?.call();
              },
              isDark: isDark,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Individual share option
class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onTap;
  final bool isDark;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.description,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor = isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: secondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show the share options bottom sheet
Future<void> showShareOptions({
  required BuildContext context,
  required String haiku,
  required ShareCardController controller,
  VoidCallback? onShareToBluesky,
  VoidCallback? onSaveToDevice,
  VoidCallback? onCopyText,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => ShareOptionsSheet(
      haiku: haiku,
      controller: controller,
      onShareToBluesky: onShareToBluesky,
      onSaveToDevice: onSaveToDevice,
      onCopyText: onCopyText,
    ),
  );
}
