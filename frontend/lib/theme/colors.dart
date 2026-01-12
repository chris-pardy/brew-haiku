import 'package:flutter/material.dart';

/// Brew Haiku color palette - "Morning Fog" theme
/// Inspired by the quiet moments of morning rituals
class BrewColors {
  BrewColors._();

  // Primary colors - warm earth tones
  static const Color warmBrown = Color(0xFF8B7355);
  static const Color softCream = Color(0xFFF5F0E8);
  static const Color deepEspresso = Color(0xFF3D2914);

  // Background colors
  static const Color fogLight = Color(0xFFFAF8F5);
  static const Color fogDark = Color(0xFF1A1612);
  static const Color mistLight = Color(0xFFEDE8E0);
  static const Color mistDark = Color(0xFF2D2520);

  // Surface colors
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF252019);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF1A1612);
  static const Color textPrimaryDark = Color(0xFFF5F0E8);
  static const Color textSecondaryLight = Color(0xFF6B5E4F);
  static const Color textSecondaryDark = Color(0xFFB8A898);

  // Accent colors
  static const Color accentGold = Color(0xFFD4A574);
  static const Color accentSage = Color(0xFF8FA87E);
  static const Color accentSky = Color(0xFF7BA3C4);

  // Status colors
  static const Color success = Color(0xFF5E8B5A);
  static const Color warning = Color(0xFFD4A054);
  static const Color error = Color(0xFFB85450);

  // Timer-specific colors
  static const Color timerActive = Color(0xFF8B7355);
  static const Color timerPaused = Color(0xFF6B5E4F);
  static const Color timerComplete = Color(0xFF5E8B5A);
}

/// Brew category color themes
/// Each brew type has its own color palette for visual distinction
enum BrewCategory {
  lightTea,
  darkTea,
  lightCoffee,
  darkCoffee,
}

class BrewCategoryColors {
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color accent;

  const BrewCategoryColors({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.accent,
  });

  /// Light tea - fresh greens and soft yellows
  static const lightTea = BrewCategoryColors(
    primary: Color(0xFF7D9B76),    // Sage green
    secondary: Color(0xFFA8C49A),  // Light sage
    surface: Color(0xFFF5F8F3),    // Soft green-white
    accent: Color(0xFFD4C86A),     // Warm yellow
  );

  /// Dark tea - deep ambers and rich browns
  static const darkTea = BrewCategoryColors(
    primary: Color(0xFF8B5A2B),    // Dark amber
    secondary: Color(0xFFB87333),  // Copper
    surface: Color(0xFFFAF5EF),    // Warm cream
    accent: Color(0xFFCD853F),     // Peru
  );

  /// Light coffee - soft browns and cream
  static const lightCoffee = BrewCategoryColors(
    primary: Color(0xFF9C7B5C),    // Medium brown
    secondary: Color(0xFFBFA078),  // Tan
    surface: Color(0xFFF8F4EF),    // Light cream
    accent: Color(0xFFD4A574),     // Gold
  );

  /// Dark coffee - rich espresso tones
  static const darkCoffee = BrewCategoryColors(
    primary: Color(0xFF5C4033),    // Dark brown
    secondary: Color(0xFF8B7355),  // Warm brown
    surface: Color(0xFFF5F0E8),    // Soft cream
    accent: Color(0xFF3D2914),     // Deep espresso
  );

  /// Get colors for a brew category
  static BrewCategoryColors forCategory(BrewCategory category) {
    switch (category) {
      case BrewCategory.lightTea:
        return lightTea;
      case BrewCategory.darkTea:
        return darkTea;
      case BrewCategory.lightCoffee:
        return lightCoffee;
      case BrewCategory.darkCoffee:
        return darkCoffee;
    }
  }

  /// Get category from brew type string
  static BrewCategory? categoryFromBrewType(String brewType) {
    final normalized = brewType.toLowerCase();
    if (normalized.contains('tea')) {
      // Determine if light or dark tea based on common types
      if (normalized.contains('green') ||
          normalized.contains('white') ||
          normalized.contains('yellow') ||
          normalized.contains('light')) {
        return BrewCategory.lightTea;
      }
      return BrewCategory.darkTea;
    }
    if (normalized.contains('coffee') || normalized.contains('espresso')) {
      // Light roast vs dark roast
      if (normalized.contains('light') || normalized.contains('filter')) {
        return BrewCategory.lightCoffee;
      }
      return BrewCategory.darkCoffee;
    }
    // Default to light coffee for unknown
    return BrewCategory.lightCoffee;
  }
}
