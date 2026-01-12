import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// Morning Fog theme for Brew Haiku
///
/// An adaptive theme system that adjusts to light and dark mode,
/// with special color palettes for different brew categories.
class BrewTheme {
  BrewTheme._();

  /// Light theme - Morning Fog Light
  static ThemeData light() {
    final textTheme = BrewTypography.getTextTheme(isDark: false);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Colors
      colorScheme: const ColorScheme.light(
        primary: BrewColors.warmBrown,
        onPrimary: BrewColors.softCream,
        primaryContainer: BrewColors.mistLight,
        onPrimaryContainer: BrewColors.deepEspresso,
        secondary: BrewColors.accentGold,
        onSecondary: BrewColors.deepEspresso,
        secondaryContainer: BrewColors.softCream,
        onSecondaryContainer: BrewColors.warmBrown,
        tertiary: BrewColors.accentSage,
        onTertiary: BrewColors.fogLight,
        tertiaryContainer: Color(0xFFE8F0E6),
        onTertiaryContainer: Color(0xFF1A2D18),
        error: BrewColors.error,
        onError: Colors.white,
        errorContainer: Color(0xFFFFDAD6),
        onErrorContainer: Color(0xFF410002),
        surface: BrewColors.surfaceLight,
        onSurface: BrewColors.textPrimaryLight,
        surfaceContainerHighest: BrewColors.mistLight,
        onSurfaceVariant: BrewColors.textSecondaryLight,
        outline: Color(0xFFD0C4B4),
        outlineVariant: Color(0xFFE8DED0),
        shadow: Colors.black12,
        scrim: Colors.black54,
        inverseSurface: BrewColors.fogDark,
        onInverseSurface: BrewColors.softCream,
        inversePrimary: BrewColors.accentGold,
      ),

      // Scaffold
      scaffoldBackgroundColor: BrewColors.fogLight,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: BrewColors.fogLight,
        foregroundColor: BrewColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: BrewColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFE8DED0),
            width: 1,
          ),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrewColors.warmBrown,
          foregroundColor: BrewColors.softCream,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrewColors.warmBrown,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrewColors.warmBrown,
          side: const BorderSide(color: BrewColors.warmBrown),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrewColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0C4B4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0C4B4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrewColors.warmBrown, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8DED0),
        thickness: 1,
        space: 1,
      ),

      // Text
      textTheme: textTheme,

      // Icons
      iconTheme: const IconThemeData(
        color: BrewColors.textPrimaryLight,
        size: 24,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BrewColors.deepEspresso,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: BrewColors.softCream,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Dark theme - Morning Fog Dark
  static ThemeData dark() {
    final textTheme = BrewTypography.getTextTheme(isDark: true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Colors
      colorScheme: const ColorScheme.dark(
        primary: BrewColors.accentGold,
        onPrimary: BrewColors.deepEspresso,
        primaryContainer: Color(0xFF4D3D28),
        onPrimaryContainer: BrewColors.softCream,
        secondary: BrewColors.warmBrown,
        onSecondary: BrewColors.softCream,
        secondaryContainer: Color(0xFF3D2914),
        onSecondaryContainer: BrewColors.accentGold,
        tertiary: BrewColors.accentSage,
        onTertiary: Color(0xFF1A2D18),
        tertiaryContainer: Color(0xFF3D4D3A),
        onTertiaryContainer: Color(0xFFCCDCC9),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: BrewColors.surfaceDark,
        onSurface: BrewColors.textPrimaryDark,
        surfaceContainerHighest: BrewColors.mistDark,
        onSurfaceVariant: BrewColors.textSecondaryDark,
        outline: Color(0xFF5C5046),
        outlineVariant: Color(0xFF3D352C),
        shadow: Colors.black38,
        scrim: Colors.black87,
        inverseSurface: BrewColors.fogLight,
        onInverseSurface: BrewColors.deepEspresso,
        inversePrimary: BrewColors.warmBrown,
      ),

      // Scaffold
      scaffoldBackgroundColor: BrewColors.fogDark,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: BrewColors.fogDark,
        foregroundColor: BrewColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: BrewColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF3D352C),
            width: 1,
          ),
        ),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrewColors.accentGold,
          foregroundColor: BrewColors.deepEspresso,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrewColors.accentGold,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrewColors.accentGold,
          side: const BorderSide(color: BrewColors.accentGold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrewColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C5046)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C5046)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrewColors.accentGold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3D352C),
        thickness: 1,
        space: 1,
      ),

      // Text
      textTheme: textTheme,

      // Icons
      iconTheme: const IconThemeData(
        color: BrewColors.textPrimaryDark,
        size: 24,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BrewColors.mistDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: BrewColors.softCream,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
