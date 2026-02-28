import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../copy/strings.dart';

class SaveButton extends StatelessWidget {
  final bool isAuthenticated;
  final bool? isSaved;
  final VoidCallback onSave;
  final VoidCallback onUnsave;
  final VoidCallback onSignIn;

  const SaveButton({
    super.key,
    required this.isAuthenticated,
    required this.isSaved,
    required this.onSave,
    required this.onUnsave,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return TextButton(
        onPressed: onSignIn,
        child: Text(
          S.signInToSave,
          style: BrewTypography.labelSmall.copyWith(
            color: BrewColors.warmAmber,
          ),
        ),
      );
    }

    final saved = isSaved ?? false;
    return IconButton(
      onPressed: saved ? onUnsave : onSave,
      icon: Icon(
        saved ? Icons.bookmark : Icons.bookmark_border,
        color: saved ? BrewColors.warmAmber : BrewColors.subtle,
      ),
    );
  }
}
