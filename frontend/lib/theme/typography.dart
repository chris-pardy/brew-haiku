import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class BrewTypography {
  BrewTypography._();

  // Haiku / headings — Playfair Display
  static TextStyle get haikuLine => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.6,
        color: BrewColors.darkInk,
      );

  static TextStyle get heading => GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: BrewColors.darkInk,
      );

  static TextStyle get headingSmall => GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: BrewColors.darkInk,
      );

  // Body / labels — Inter
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: BrewColors.darkInk,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: BrewColors.subtle,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: BrewColors.darkInk,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: BrewColors.subtle,
      );

  static TextStyle get timer => GoogleFonts.inter(
        fontSize: 64,
        fontWeight: FontWeight.w300,
        height: 1.0,
        color: BrewColors.darkInk,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.0,
        color: BrewColors.warmCream,
      );
}
