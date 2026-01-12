import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/theme/colors.dart';

void main() {
  group('BrewColors', () {
    test('primary colors have correct values', () {
      expect(BrewColors.warmBrown.value, 0xFF8B7355);
      expect(BrewColors.softCream.value, 0xFFF5F0E8);
      expect(BrewColors.deepEspresso.value, 0xFF3D2914);
    });

    test('background colors have correct values', () {
      expect(BrewColors.fogLight.value, 0xFFFAF8F5);
      expect(BrewColors.fogDark.value, 0xFF1A1612);
      expect(BrewColors.mistLight.value, 0xFFEDE8E0);
      expect(BrewColors.mistDark.value, 0xFF2D2520);
    });

    test('surface colors have correct values', () {
      expect(BrewColors.surfaceLight.value, 0xFFFFFFFF);
      expect(BrewColors.surfaceDark.value, 0xFF252019);
    });

    test('accent colors have correct values', () {
      expect(BrewColors.accentGold.value, 0xFFD4A574);
      expect(BrewColors.accentSage.value, 0xFF8FA87E);
      expect(BrewColors.accentSky.value, 0xFF7BA3C4);
    });

    test('status colors have correct values', () {
      expect(BrewColors.success.value, 0xFF5E8B5A);
      expect(BrewColors.warning.value, 0xFFD4A054);
      expect(BrewColors.error.value, 0xFFB85450);
    });

    test('timer colors have correct values', () {
      expect(BrewColors.timerActive.value, 0xFF8B7355);
      expect(BrewColors.timerPaused.value, 0xFF6B5E4F);
      expect(BrewColors.timerComplete.value, 0xFF5E8B5A);
    });
  });

  group('BrewCategoryColors', () {
    test('forCategory returns correct colors for lightTea', () {
      final colors = BrewCategoryColors.forCategory(BrewCategory.lightTea);
      expect(colors.primary.value, 0xFF7D9B76);
      expect(colors.secondary.value, 0xFFA8C49A);
      expect(colors.surface.value, 0xFFF5F8F3);
      expect(colors.accent.value, 0xFFD4C86A);
    });

    test('forCategory returns correct colors for darkTea', () {
      final colors = BrewCategoryColors.forCategory(BrewCategory.darkTea);
      expect(colors.primary.value, 0xFF8B5A2B);
      expect(colors.secondary.value, 0xFFB87333);
      expect(colors.surface.value, 0xFFFAF5EF);
      expect(colors.accent.value, 0xFFCD853F);
    });

    test('forCategory returns correct colors for lightCoffee', () {
      final colors = BrewCategoryColors.forCategory(BrewCategory.lightCoffee);
      expect(colors.primary.value, 0xFF9C7B5C);
      expect(colors.secondary.value, 0xFFBFA078);
      expect(colors.surface.value, 0xFFF8F4EF);
      expect(colors.accent.value, 0xFFD4A574);
    });

    test('forCategory returns correct colors for darkCoffee', () {
      final colors = BrewCategoryColors.forCategory(BrewCategory.darkCoffee);
      expect(colors.primary.value, 0xFF5C4033);
      expect(colors.secondary.value, 0xFF8B7355);
      expect(colors.surface.value, 0xFFF5F0E8);
      expect(colors.accent.value, 0xFF3D2914);
    });

    test('categoryFromBrewType identifies green tea as lightTea', () {
      expect(
        BrewCategoryColors.categoryFromBrewType('green tea'),
        BrewCategory.lightTea,
      );
      expect(
        BrewCategoryColors.categoryFromBrewType('Green Tea'),
        BrewCategory.lightTea,
      );
    });

    test('categoryFromBrewType identifies white tea as lightTea', () {
      expect(
        BrewCategoryColors.categoryFromBrewType('white tea'),
        BrewCategory.lightTea,
      );
    });

    test('categoryFromBrewType identifies black tea as darkTea', () {
      expect(
        BrewCategoryColors.categoryFromBrewType('black tea'),
        BrewCategory.darkTea,
      );
      expect(
        BrewCategoryColors.categoryFromBrewType('oolong tea'),
        BrewCategory.darkTea,
      );
    });

    test('categoryFromBrewType identifies filter coffee as lightCoffee', () {
      expect(
        BrewCategoryColors.categoryFromBrewType('filter coffee'),
        BrewCategory.lightCoffee,
      );
      expect(
        BrewCategoryColors.categoryFromBrewType('light roast coffee'),
        BrewCategory.lightCoffee,
      );
    });

    test('categoryFromBrewType identifies espresso as darkCoffee', () {
      expect(
        BrewCategoryColors.categoryFromBrewType('espresso'),
        BrewCategory.darkCoffee,
      );
      expect(
        BrewCategoryColors.categoryFromBrewType('dark coffee'),
        BrewCategory.darkCoffee,
      );
    });

    test('categoryFromBrewType defaults to lightCoffee for unknown types', () {
      expect(
        BrewCategoryColors.categoryFromBrewType('unknown brew'),
        BrewCategory.lightCoffee,
      );
    });
  });
}
