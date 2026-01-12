import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/widgets/haiku_composer.dart';

void main() {
  group('HaikuComposerState', () {
    test('initial state has empty lines', () {
      const state = HaikuComposerState();
      expect(state.lines, ['', '', '']);
      expect(state.currentLine, 0);
      expect(state.isComplete, false);
    });

    test('syllableCounts returns counts for each line', () {
      const state = HaikuComposerState(
        lines: ['the old pond', 'a frog jumps in', 'splash'],
      );
      final counts = state.syllableCounts;
      expect(counts.length, 3);
    });

    test('text returns joined lines', () {
      const state = HaikuComposerState(
        lines: ['line one', 'line two', 'line three'],
      );
      expect(state.text, 'line one\nline two\nline three');
    });

    test('copyWith creates new state with changes', () {
      const state = HaikuComposerState();
      final newState = state.copyWith(currentLine: 1);
      expect(newState.currentLine, 1);
      expect(newState.lines, state.lines);
    });
  });

  group('HaikuComposerNotifier', () {
    test('updateLine changes specific line', () {
      final notifier = HaikuComposerNotifier();

      notifier.updateLine(0, 'first line');
      expect(notifier.state.lines[0], 'first line');
      expect(notifier.state.lines[1], '');
      expect(notifier.state.lines[2], '');
    });

    test('nextLine advances current line', () {
      final notifier = HaikuComposerNotifier();
      expect(notifier.state.currentLine, 0);

      notifier.nextLine();
      expect(notifier.state.currentLine, 1);

      notifier.nextLine();
      expect(notifier.state.currentLine, 2);

      // Should not go beyond line 2
      notifier.nextLine();
      expect(notifier.state.currentLine, 2);
    });

    test('previousLine goes back', () {
      final notifier = HaikuComposerNotifier();
      notifier.setCurrentLine(2);

      notifier.previousLine();
      expect(notifier.state.currentLine, 1);

      notifier.previousLine();
      expect(notifier.state.currentLine, 0);

      // Should not go below 0
      notifier.previousLine();
      expect(notifier.state.currentLine, 0);
    });

    test('setCurrentLine sets valid line', () {
      final notifier = HaikuComposerNotifier();

      notifier.setCurrentLine(1);
      expect(notifier.state.currentLine, 1);

      notifier.setCurrentLine(2);
      expect(notifier.state.currentLine, 2);

      // Invalid lines should be ignored
      notifier.setCurrentLine(3);
      expect(notifier.state.currentLine, 2);

      notifier.setCurrentLine(-1);
      expect(notifier.state.currentLine, 2);
    });

    test('reset clears all state', () {
      final notifier = HaikuComposerNotifier();
      notifier.updateLine(0, 'some text');
      notifier.setCurrentLine(2);
      notifier.complete();

      notifier.reset();
      expect(notifier.state.lines, ['', '', '']);
      expect(notifier.state.currentLine, 0);
      expect(notifier.state.isComplete, false);
    });

    test('complete marks haiku as complete', () {
      final notifier = HaikuComposerNotifier();
      expect(notifier.state.isComplete, false);

      notifier.complete();
      expect(notifier.state.isComplete, true);
    });
  });

  group('HaikuComposer Widget', () {
    Widget createTestWidget({void Function(String)? onSubmit}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HaikuComposer(onSubmit: onSubmit),
          ),
        ),
      );
    }

    testWidgets('renders three text fields', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('shows hint text for each line', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('First line (5 syllables)'), findsOneWidget);
      expect(find.text('Second line (7 syllables)'), findsOneWidget);
      expect(find.text('Third line (5 syllables)'), findsOneWidget);
    });

    testWidgets('shows syllable indicators', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initial state shows 0/5, 0/7, 0/5
      expect(find.text('0/5'), findsNWidgets(2));
      expect(find.text('0/7'), findsOneWidget);
    });

    testWidgets('updates syllable count on text input', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find first text field and enter text
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'the');
      await tester.pump();

      // 'the' is 1 syllable
      expect(find.text('1/5'), findsOneWidget);
    });

    testWidgets('shows progress bars', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should have 3 progress bars
      expect(find.byType(FractionallySizedBox), findsNWidgets(3));
    });

    testWidgets('shows status text', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Keep writing...'), findsOneWidget);
    });

    testWidgets('text fields accept input', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final textFields = find.byType(TextField);

      await tester.enterText(textFields.at(0), 'first line text');
      await tester.pump();

      await tester.enterText(textFields.at(1), 'second line text');
      await tester.pump();

      await tester.enterText(textFields.at(2), 'third line');
      await tester.pump();

      // Verify text was entered
      final firstController = tester.widget<TextField>(textFields.at(0)).controller;
      expect(firstController?.text, 'first line text');
    });
  });

  group('haikuComposerProvider', () {
    test('provider creates notifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(haikuComposerProvider);
      expect(state.lines, ['', '', '']);
    });

    test('provider notifier can be accessed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(haikuComposerProvider.notifier);
      notifier.updateLine(0, 'test');

      final state = container.read(haikuComposerProvider);
      expect(state.lines[0], 'test');
    });
  });

  group('haikuTargets', () {
    test('has correct values', () {
      expect(haikuTargets, [5, 7, 5]);
    });
  });
}
