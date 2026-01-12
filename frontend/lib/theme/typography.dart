import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography for Brew Haiku
///
/// Uses two font families:
/// - Playfair Display: Elegant serif for headings and haiku text
/// - Inter: Clean sans-serif for body text and UI elements
class BrewTypography {
  BrewTypography._();

  /// Get the text theme for the app
  static TextTheme getTextTheme({required bool isDark}) {
    final Color textColor = isDark
        ? const Color(0xFFF5F0E8)
        : const Color(0xFF1A1612);

    final Color secondaryTextColor = isDark
        ? const Color(0xFFB8A898)
        : const Color(0xFF6B5E4F);

    return TextTheme(
      // Display styles - Playfair Display
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textColor,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),

      // Headline styles - Playfair Display
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),

      // Title styles - Inter (semi-bold)
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: textColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textColor,
      ),

      // Body styles - Inter
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: secondaryTextColor,
      ),

      // Label styles - Inter
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: secondaryTextColor,
      ),
    );
  }

  /// Special text style for haiku display
  static TextStyle haikuStyle({
    required bool isDark,
    double fontSize = 20,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      height: 1.8,
      letterSpacing: 0.5,
      color: isDark
          ? const Color(0xFFF5F0E8)
          : const Color(0xFF1A1612),
    );
  }

  /// Text style for timer countdown display
  static TextStyle timerStyle({
    required bool isDark,
    double fontSize = 64,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      letterSpacing: -2,
      color: isDark
          ? const Color(0xFFF5F0E8)
          : const Color(0xFF1A1612),
    );
  }

  /// Text style for step instructions
  static TextStyle stepInstructionStyle({
    required bool isDark,
    double fontSize = 18,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: isDark
          ? const Color(0xFFB8A898)
          : const Color(0xFF6B5E4F),
    );
  }
}
