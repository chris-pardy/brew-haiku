import 'package:flutter/material.dart';

class BrewAnimations {
  BrewAnimations._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 500);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve entryCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
}
