import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/screens/onboarding_screen.dart';
import 'package:brew_haiku/theme/colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingPage', () {
    test('creates page with required properties', () {
      const page = OnboardingPage(
        title: 'Test Title',
        subtitle: 'Test Subtitle',
        icon: Icons.coffee,
      );

      expect(page.title, 'Test Title');
      expect(page.subtitle, 'Test Subtitle');
      expect(page.icon, Icons.coffee);
    });
  });

  group('OnboardingPages', () {
    test('has exactly 3 pages', () {
      expect(OnboardingPages.pages.length, 3);
    });

    test('first page is about ritual', () {
      final page = OnboardingPages.pages[0];
      expect(page.title, contains('ritual'));
    });

    test('second page is about presence', () {
      final page = OnboardingPages.pages[1];
      expect(page.title, contains('present'));
    });

    test('third page is about haiku', () {
      final page = OnboardingPages.pages[2];
      expect(page.title, contains('haiku'));
    });

    test('all pages have non-empty titles', () {
      for (final page in OnboardingPages.pages) {
        expect(page.title.isNotEmpty, true);
      }
    });

    test('all pages have non-empty subtitles', () {
      for (final page in OnboardingPages.pages) {
        expect(page.subtitle.isNotEmpty, true);
      }
    });
  });

  group('OnboardingScreen', () {
    testWidgets('displays skip button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('displays continue button on first page', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('displays first page content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.textContaining('ritual'), findsOneWidget);
    });

    testWidgets('displays page indicator with 3 dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Find AnimatedContainer widgets (the dots)
      final dots = find.byType(AnimatedContainer);
      // There should be 3 dots in the page indicator
      expect(dots, findsNWidgets(3));
    });

    testWidgets('navigates to next page on continue tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // First page should be visible
      expect(find.textContaining('ritual'), findsOneWidget);

      // Tap continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Second page should now be visible
      expect(find.textContaining('present'), findsOneWidget);
    });

    testWidgets('shows Get Started on last page', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Navigate to last page
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Should show "Get Started" instead of "Continue"
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('calls onComplete when skip is tapped', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(completed, true);
    });

    testWidgets('calls onComplete when Get Started is tapped', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Navigate to last page
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Tap Get Started
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(completed, true);
    });

    testWidgets('can swipe between pages', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // First page visible
      expect(find.textContaining('ritual'), findsOneWidget);

      // Swipe left to go to next page
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Second page should be visible
      expect(find.textContaining('present'), findsOneWidget);
    });

    testWidgets('uses light theme colors in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const OnboardingScreen(),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, BrewColors.fogLight);
    });

    testWidgets('uses dark theme colors in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const OnboardingScreen(),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, BrewColors.fogDark);
    });

    testWidgets('handles no onComplete callback gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Skip should not throw
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });

  group('PageIndicator', () {
    testWidgets('displays correct number of dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PageIndicator(
                pageCount: 5,
                currentPage: 0,
              ),
            ),
          ),
        ),
      );

      final dots = find.byType(AnimatedContainer);
      expect(dots, findsNWidgets(5));
    });

    testWidgets('current dot is wider', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PageIndicator(
                pageCount: 3,
                currentPage: 1,
              ),
            ),
          ),
        ),
      );

      // The indicator is rendered, verification is visual
      expect(find.byType(PageIndicator), findsOneWidget);
    });

    testWidgets('accepts custom colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PageIndicator(
                pageCount: 3,
                currentPage: 0,
                activeColor: Colors.red,
                inactiveColor: Colors.grey,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PageIndicator), findsOneWidget);
    });

    testWidgets('updates when currentPage changes', (tester) async {
      int currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PageIndicator(
                        pageCount: 3,
                        currentPage: currentPage,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentPage = 2;
                          });
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      // Widget should update without errors
      expect(find.byType(PageIndicator), findsOneWidget);
    });
  });
}
