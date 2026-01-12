import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/theme/typography.dart';

void main() {
  group('BrewTypography', () {
    group('getTextTheme', () {
      test('returns valid TextTheme for light mode', () {
        final textTheme = BrewTypography.getTextTheme(isDark: false);

        expect(textTheme.displayLarge, isNotNull);
        expect(textTheme.displayMedium, isNotNull);
        expect(textTheme.displaySmall, isNotNull);
        expect(textTheme.headlineLarge, isNotNull);
        expect(textTheme.headlineMedium, isNotNull);
        expect(textTheme.headlineSmall, isNotNull);
        expect(textTheme.titleLarge, isNotNull);
        expect(textTheme.titleMedium, isNotNull);
        expect(textTheme.titleSmall, isNotNull);
        expect(textTheme.bodyLarge, isNotNull);
        expect(textTheme.bodyMedium, isNotNull);
        expect(textTheme.bodySmall, isNotNull);
        expect(textTheme.labelLarge, isNotNull);
        expect(textTheme.labelMedium, isNotNull);
        expect(textTheme.labelSmall, isNotNull);
      });

      test('returns valid TextTheme for dark mode', () {
        final textTheme = BrewTypography.getTextTheme(isDark: true);

        expect(textTheme.displayLarge, isNotNull);
        expect(textTheme.bodyLarge, isNotNull);
        expect(textTheme.labelLarge, isNotNull);
      });

      test('light mode uses dark text color', () {
        final textTheme = BrewTypography.getTextTheme(isDark: false);

        // Primary text should be dark
        expect(textTheme.bodyLarge!.color, const Color(0xFF1A1612));
      });

      test('dark mode uses light text color', () {
        final textTheme = BrewTypography.getTextTheme(isDark: true);

        // Primary text should be light
        expect(textTheme.bodyLarge!.color, const Color(0xFFF5F0E8));
      });

      test('display styles have correct font sizes', () {
        final textTheme = BrewTypography.getTextTheme(isDark: false);

        expect(textTheme.displayLarge!.fontSize, 57);
        expect(textTheme.displayMedium!.fontSize, 45);
        expect(textTheme.displaySmall!.fontSize, 36);
      });

      test('headline styles have correct font sizes', () {
        final textTheme = BrewTypography.getTextTheme(isDark: false);

        expect(textTheme.headlineLarge!.fontSize, 32);
        expect(textTheme.headlineMedium!.fontSize, 28);
        expect(textTheme.headlineSmall!.fontSize, 24);
      });

      test('title styles have correct font sizes and weight', () {
        final textTheme = BrewTypography.getTextTheme(isDark: false);

        expect(textTheme.titleLarge!.fontSize, 22);
        expect(textTheme.titleLarge!.fontWeight, FontWeight.w600);
        expect(textTheme.titleMedium!.fontSize, 16);
        expect(textTheme.titleSmall!.fontSize, 14);
      });

      test('body styles have correct font sizes', () {
        final textTheme = BrewTypography.getTextTheme(isDark: false);

        expect(textTheme.bodyLarge!.fontSize, 16);
        expect(textTheme.bodyMedium!.fontSize, 14);
        expect(textTheme.bodySmall!.fontSize, 12);
      });
    });

    group('haikuStyle', () {
      test('returns italic style for light mode', () {
        final style = BrewTypography.haikuStyle(isDark: false);

        expect(style.fontStyle, FontStyle.italic);
        expect(style.fontSize, 20);
        expect(style.height, 1.8);
        expect(style.letterSpacing, 0.5);
        expect(style.color, const Color(0xFF1A1612));
      });

      test('returns italic style for dark mode', () {
        final style = BrewTypography.haikuStyle(isDark: true);

        expect(style.fontStyle, FontStyle.italic);
        expect(style.color, const Color(0xFFF5F0E8));
      });

      test('allows custom font size', () {
        final style = BrewTypography.haikuStyle(isDark: false, fontSize: 24);

        expect(style.fontSize, 24);
      });
    });

    group('timerStyle', () {
      test('returns large thin style for light mode', () {
        final style = BrewTypography.timerStyle(isDark: false);

        expect(style.fontSize, 64);
        expect(style.fontWeight, FontWeight.w300);
        expect(style.letterSpacing, -2);
        expect(style.color, const Color(0xFF1A1612));
      });

      test('returns large thin style for dark mode', () {
        final style = BrewTypography.timerStyle(isDark: true);

        expect(style.color, const Color(0xFFF5F0E8));
      });

      test('allows custom font size', () {
        final style = BrewTypography.timerStyle(isDark: false, fontSize: 48);

        expect(style.fontSize, 48);
      });
    });

    group('stepInstructionStyle', () {
      test('returns secondary text style for light mode', () {
        final style = BrewTypography.stepInstructionStyle(isDark: false);

        expect(style.fontSize, 18);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.height, 1.5);
        expect(style.color, const Color(0xFF6B5E4F));
      });

      test('returns secondary text style for dark mode', () {
        final style = BrewTypography.stepInstructionStyle(isDark: true);

        expect(style.color, const Color(0xFFB8A898));
      });

      test('allows custom font size', () {
        final style =
            BrewTypography.stepInstructionStyle(isDark: false, fontSize: 16);

        expect(style.fontSize, 16);
      });
    });
  });
}
