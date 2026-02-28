import 'package:flutter/material.dart';
import '../theme/gradients.dart';

class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final LinearGradient gradient;

  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.gradient = BrewGradients.defaultBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(child: body),
      ),
    );
  }
}
