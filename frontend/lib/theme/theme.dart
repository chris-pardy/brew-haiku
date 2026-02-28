import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class BrewTheme {
  BrewTheme._();

  static ThemeData get data => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: BrewColors.warmAmber,
          onPrimary: BrewColors.warmCream,
          secondary: BrewColors.dustyLavender,
          onSecondary: BrewColors.darkInk,
          surface: BrewColors.warmCream,
          onSurface: BrewColors.darkInk,
          error: BrewColors.error,
        ),
        scaffoldBackgroundColor: BrewColors.warmCream,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: BrewColors.darkInk),
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: BrewColors.darkInk,
          displayColor: BrewColors.darkInk,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        dividerTheme: const DividerThemeData(
          color: BrewColors.divider,
          thickness: 0.5,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: BrewColors.darkInk,
            foregroundColor: BrewColors.warmCream,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: BrewColors.darkInk,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
      );
}
