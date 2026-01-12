import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/widgets/share_card.dart';

void main() {
  group('BrewContext', () {
    test('formattedTime formats correctly', () {
      const context = BrewContext(
        vessel: 'V60',
        brewTime: Duration(minutes: 3, seconds: 30),
      );
      expect(context.formattedTime, '3:30');
    });

    test('formattedTime handles single digit seconds', () {
      const context = BrewContext(
        vessel: 'V60',
        brewTime: Duration(minutes: 2, seconds: 5),
      );
      expect(context.formattedTime, '2:05');
    });

    test('formattedRatio returns empty when null', () {
      const context = BrewContext(
        vessel: 'V60',
        brewTime: Duration(minutes: 3),
      );
      expect(context.formattedRatio, '');
    });

    test('formattedRatio formats correctly', () {
      const context = BrewContext(
        vessel: 'V60',
        brewTime: Duration(minutes: 3),
        ratio: 16,
      );
      expect(context.formattedRatio, '1:16');
    });

    test('formattedRatio rounds decimal', () {
      const context = BrewContext(
        vessel: 'V60',
        brewTime: Duration(minutes: 3),
        ratio: 15.5,
      );
      expect(context.formattedRatio, '1:16');
    });
  });

  group('ShareCard Widget', () {
    const testHaiku = 'an old silent pond\na frog jumps into the pond\nsplash silence again';

    Widget createTestWidget({
      String haiku = testHaiku,
      BrewContext? brewContext,
      GlobalKey? repaintKey,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ShareCard(
            haiku: haiku,
            brewContext: brewContext,
            repaintKey: repaintKey,
          ),
        ),
      );
    }

    testWidgets('renders haiku text', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('an old silent pond'), findsOneWidget);
      expect(find.text('a frog jumps into the pond'), findsOneWidget);
      expect(find.text('splash silence again'), findsOneWidget);
    });

    testWidgets('renders app signature', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('brew-haiku.app'), findsOneWidget);
    });

    testWidgets('renders brew context when provided', (tester) async {
      const context = BrewContext(
        vessel: 'Hario V60',
        brewTime: Duration(minutes: 3),
        ratio: 16,
      );

      await tester.pumpWidget(createTestWidget(brewContext: context));

      expect(find.text('Hario V60'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);
      expect(find.text('1:16'), findsOneWidget);
    });

    testWidgets('does not render brew context when not provided', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should not find brew time format without context
      expect(find.text('3:00'), findsNothing);
    });

    testWidgets('wraps content in RepaintBoundary', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(RepaintBoundary), findsOneWidget);
    });

    testWidgets('uses provided repaint key', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(createTestWidget(repaintKey: key));

      final boundary = tester.widget<RepaintBoundary>(
        find.byType(RepaintBoundary),
      );
      expect(boundary.key, key);
    });
  });

  group('ShareCardController', () {
    test('repaintKey returns GlobalKey', () {
      final controller = ShareCardController();
      expect(controller.repaintKey, isA<GlobalKey>());
    });

    test('getShareText adds signature', () {
      final controller = ShareCardController();
      const haiku = 'line one\nline two\nline three';

      final result = controller.getShareText(haiku);

      expect(result, 'line one\nline two\nline three\n\nvia @brew-haiku.app');
    });

    testWidgets('copyText copies to clipboard', (tester) async {
      final controller = ShareCardController();
      const haiku = 'test haiku';

      // Set up clipboard mock
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        },
      );

      await controller.copyText(haiku);

      // If no exception, clipboard was set successfully
    });
  });

  group('ShareOptionsSheet', () {
    Widget createTestSheet({
      VoidCallback? onShareToBluesky,
      VoidCallback? onSaveToDevice,
      VoidCallback? onCopyText,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ShareOptionsSheet(
            haiku: 'test haiku',
            controller: ShareCardController(),
            onShareToBluesky: onShareToBluesky,
            onSaveToDevice: onSaveToDevice,
            onCopyText: onCopyText,
          ),
        ),
      );
    }

    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(createTestSheet());

      expect(find.text('Share Haiku'), findsOneWidget);
    });

    testWidgets('renders all share options', (tester) async {
      await tester.pumpWidget(createTestSheet());

      expect(find.text('Share to Bluesky'), findsOneWidget);
      expect(find.text('Save to Device'), findsOneWidget);
      expect(find.text('Copy Text'), findsOneWidget);
    });

    testWidgets('renders option descriptions', (tester) async {
      await tester.pumpWidget(createTestSheet());

      expect(find.text('Post your haiku to your feed'), findsOneWidget);
      expect(find.text('Download as image'), findsOneWidget);
      expect(find.text('Copy haiku to clipboard'), findsOneWidget);
    });

    testWidgets('calls onShareToBluesky when tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(createTestSheet(
        onShareToBluesky: () => called = true,
      ));

      await tester.tap(find.text('Share to Bluesky'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('calls onSaveToDevice when tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(createTestSheet(
        onSaveToDevice: () => called = true,
      ));

      await tester.tap(find.text('Save to Device'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('calls onCopyText when tapped', (tester) async {
      var called = false;

      // Mock clipboard
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async => null,
      );

      await tester.pumpWidget(createTestSheet(
        onCopyText: () => called = true,
      ));

      await tester.tap(find.text('Copy Text'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('renders icons for each option', (tester) async {
      await tester.pumpWidget(createTestSheet());

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.save_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });
  });
}
