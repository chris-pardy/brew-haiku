import 'package:flutter/material.dart';
import 'colors.dart';

class BrewGradients {
  BrewGradients._();

  static const defaultBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      BrewColors.warmAmber,
      BrewColors.dustyLavender,
      BrewColors.slateBlue,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const coffee = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFD4A574),
      Color(0xFFC09060),
      Color(0xFF8B7355),
    ],
  );

  static const tea = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFC8D4A0),
      Color(0xFFB8C490),
      Color(0xFF8A9A6A),
    ],
  );

  static const surface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      BrewColors.warmCream,
      Color(0xFFF0E8E0),
    ],
  );
}
