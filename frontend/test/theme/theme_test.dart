import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/theme/theme.dart';
import 'package:brew_haiku/theme/colors.dart';

void main() {
  group('BrewTheme', () {
    group('light', () {
      late ThemeData theme;

      setUp(() {
        theme = BrewTheme.light();
      });

      test('uses Material 3', () {
        expect(theme.useMaterial3, isTrue);
      });

      test('has light brightness', () {
        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      test('uses warmBrown as primary color', () {
        expect(theme.colorScheme.primary, BrewColors.warmBrown);
      });

      test('uses accentGold as secondary color', () {
        expect(theme.colorScheme.secondary, BrewColors.accentGold);
      });

      test('uses accentSage as tertiary color', () {
        expect(theme.colorScheme.tertiary, BrewColors.accentSage);
      });

      test('uses fogLight as scaffold background', () {
        expect(theme.scaffoldBackgroundColor, BrewColors.fogLight);
      });

      test('appBar has no elevation', () {
        expect(theme.appBarTheme.elevation, 0);
      });

      test('appBar is centered', () {
        expect(theme.appBarTheme.centerTitle, isTrue);
      });

      test('cards have no elevation with border', () {
        expect(theme.cardTheme.elevation, 0);
        expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
        final shape = theme.cardTheme.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(16));
      });

      test('elevated buttons use warmBrown', () {
        final style = theme.elevatedButtonTheme.style!;
        final bgColor = style.backgroundColor!.resolve({});
        expect(bgColor, BrewColors.warmBrown);
      });

      test('input fields are filled', () {
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.inputDecorationTheme.fillColor, BrewColors.surfaceLight);
      });

      test('snackbar is floating', () {
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      });

      test('has complete text theme', () {
        expect(theme.textTheme.displayLarge, isNotNull);
        expect(theme.textTheme.bodyMedium, isNotNull);
        expect(theme.textTheme.labelLarge, isNotNull);
      });

      test('icons use correct size', () {
        expect(theme.iconTheme.size, 24);
      });
    });

    group('dark', () {
      late ThemeData theme;

      setUp(() {
        theme = BrewTheme.dark();
      });

      test('uses Material 3', () {
        expect(theme.useMaterial3, isTrue);
      });

      test('has dark brightness', () {
        expect(theme.brightness, Brightness.dark);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });

      test('uses accentGold as primary color', () {
        expect(theme.colorScheme.primary, BrewColors.accentGold);
      });

      test('uses warmBrown as secondary color', () {
        expect(theme.colorScheme.secondary, BrewColors.warmBrown);
      });

      test('uses accentSage as tertiary color', () {
        expect(theme.colorScheme.tertiary, BrewColors.accentSage);
      });

      test('uses fogDark as scaffold background', () {
        expect(theme.scaffoldBackgroundColor, BrewColors.fogDark);
      });

      test('appBar has no elevation', () {
        expect(theme.appBarTheme.elevation, 0);
      });

      test('elevated buttons use accentGold', () {
        final style = theme.elevatedButtonTheme.style!;
        final bgColor = style.backgroundColor!.resolve({});
        expect(bgColor, BrewColors.accentGold);
      });

      test('input fields are filled with dark surface', () {
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.inputDecorationTheme.fillColor, BrewColors.surfaceDark);
      });

      test('snackbar uses dark mist background', () {
        expect(theme.snackBarTheme.backgroundColor, BrewColors.mistDark);
      });
    });

    group('light and dark consistency', () {
      test('both themes have same button padding', () {
        final lightStyle = BrewTheme.light().elevatedButtonTheme.style!;
        final darkStyle = BrewTheme.dark().elevatedButtonTheme.style!;

        expect(lightStyle.padding, darkStyle.padding);
      });

      test('both themes have same border radius', () {
        final lightCard = BrewTheme.light().cardTheme.shape as RoundedRectangleBorder;
        final darkCard = BrewTheme.dark().cardTheme.shape as RoundedRectangleBorder;

        expect(lightCard.borderRadius, darkCard.borderRadius);
      });

      test('both themes have same icon size', () {
        expect(
          BrewTheme.light().iconTheme.size,
          BrewTheme.dark().iconTheme.size,
        );
      });
    });
  });
}
