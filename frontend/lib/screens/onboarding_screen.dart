import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Data model for an onboarding page
class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

/// The three onboarding pages for Brew Haiku
class OnboardingPages {
  OnboardingPages._();

  static const List<OnboardingPage> pages = [
    OnboardingPage(
      title: 'Transform your brew\ninto a ritual',
      subtitle: 'Elevate your daily tea or coffee into a moment of mindfulness',
      icon: Icons.local_cafe_outlined,
    ),
    OnboardingPage(
      title: 'Stay present.\nNo distractions.',
      subtitle: 'Our focus guard gently encourages you to stay with your brew',
      icon: Icons.self_improvement_outlined,
    ),
    OnboardingPage(
      title: 'Complete your ritual.\nWrite a haiku.',
      subtitle: 'Capture your moment in 5-7-5 syllables and share with the community',
      icon: Icons.edit_note_outlined,
    ),
  ];
}

/// Onboarding carousel with 3 screens, navigation dots, and skip option.
///
/// This screen is shown on first launch to introduce users to Brew Haiku.
class OnboardingScreen extends StatefulWidget {
  /// Callback when onboarding is completed or skipped
  final VoidCallback? onComplete;

  const OnboardingScreen({
    super.key,
    this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < OnboardingPages.pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  void _complete() {
    widget.onComplete?.call();
  }

  bool get _isLastPage => _currentPage == OnboardingPages.pages.length - 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _complete,
                  child: Text(
                    'Skip',
                    style: textTheme.labelLarge?.copyWith(
                      color: isDark
                          ? BrewColors.textSecondaryDark
                          : BrewColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: OnboardingPages.pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageContent(
                    page: OnboardingPages.pages[index],
                    isDark: isDark,
                  );
                },
              ),
            ),

            // Navigation dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: _PageIndicator(
                pageCount: OnboardingPages.pages.length,
                currentPage: _currentPage,
                isDark: isDark,
              ),
            ),

            // Continue/Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? BrewColors.accentGold : BrewColors.warmBrown,
                    foregroundColor:
                        isDark ? BrewColors.deepEspresso : BrewColors.softCream,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLastPage ? 'Get Started' : 'Continue',
                    style: textTheme.labelLarge?.copyWith(
                      color: isDark
                          ? BrewColors.deepEspresso
                          : BrewColors.softCream,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Content for a single onboarding page
class _OnboardingPageContent extends StatelessWidget {
  final OnboardingPage page;
  final bool isDark;

  const _OnboardingPageContent({
    required this.page,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final primaryColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryTextColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 56,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation dots indicator
class _PageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final bool isDark;

  const _PageIndicator({
    required this.pageCount,
    required this.currentPage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final inactiveColor = isDark
        ? BrewColors.textSecondaryDark.withOpacity(0.3)
        : BrewColors.textSecondaryLight.withOpacity(0.3);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentPage ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == currentPage ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Standalone page indicator widget for use in other screens
class PageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final Color? activeColor;
  final Color? inactiveColor;

  const PageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultActiveColor =
        isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final defaultInactiveColor = isDark
        ? BrewColors.textSecondaryDark.withOpacity(0.3)
        : BrewColors.textSecondaryLight.withOpacity(0.3);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentPage ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == currentPage
                ? (activeColor ?? defaultActiveColor)
                : (inactiveColor ?? defaultInactiveColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
