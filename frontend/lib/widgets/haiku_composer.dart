import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/syllable_counter.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Target syllables for each line of a haiku
const List<int> haikuTargets = [5, 7, 5];

/// State for the haiku composer
class HaikuComposerState {
  final List<String> lines;
  final int currentLine;
  final bool isComplete;

  const HaikuComposerState({
    this.lines = const ['', '', ''],
    this.currentLine = 0,
    this.isComplete = false,
  });

  /// Get syllable counts for each line
  List<int> get syllableCounts => lines.map(countSyllablesInLine).toList();

  /// Get the full haiku text
  String get text => lines.join('\n');

  /// Check if haiku follows 5-7-5 structure
  bool get isValidStructure {
    final counts = syllableCounts;
    return counts[0] == haikuTargets[0] &&
        counts[1] == haikuTargets[1] &&
        counts[2] == haikuTargets[2];
  }

  HaikuComposerState copyWith({
    List<String>? lines,
    int? currentLine,
    bool? isComplete,
  }) {
    return HaikuComposerState(
      lines: lines ?? this.lines,
      currentLine: currentLine ?? this.currentLine,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Notifier for haiku composer state
class HaikuComposerNotifier extends StateNotifier<HaikuComposerState> {
  HaikuComposerNotifier() : super(const HaikuComposerState());

  /// Update a line's text
  void updateLine(int lineIndex, String text) {
    if (lineIndex < 0 || lineIndex > 2) return;

    final newLines = List<String>.from(state.lines);
    newLines[lineIndex] = text;

    state = state.copyWith(
      lines: newLines,
      isComplete: false,
    );
  }

  /// Move to next line
  void nextLine() {
    if (state.currentLine < 2) {
      state = state.copyWith(currentLine: state.currentLine + 1);
    }
  }

  /// Move to previous line
  void previousLine() {
    if (state.currentLine > 0) {
      state = state.copyWith(currentLine: state.currentLine - 1);
    }
  }

  /// Set current line
  void setCurrentLine(int line) {
    if (line >= 0 && line <= 2) {
      state = state.copyWith(currentLine: line);
    }
  }

  /// Mark as complete
  void complete() {
    state = state.copyWith(isComplete: true);
  }

  /// Reset the composer
  void reset() {
    state = const HaikuComposerState();
  }

  /// Handle text change with auto-line breaking
  void handleTextChange(String text, int lineIndex) {
    updateLine(lineIndex, text);

    // Check for auto-line break on word completion
    if (lineIndex < 2 && text.isNotEmpty) {
      final lastChar = text[text.length - 1];
      final isWordComplete = lastChar == ' ' ||
          lastChar == ',' ||
          lastChar == '.' ||
          lastChar == '!' ||
          lastChar == '?';

      if (isWordComplete) {
        final syllables = countSyllablesInLine(text.trim());
        final target = haikuTargets[lineIndex];

        if (syllables >= target) {
          // Auto-advance to next line
          nextLine();
        }
      }
    }
  }
}

/// Provider for haiku composer state
final haikuComposerProvider =
    StateNotifierProvider<HaikuComposerNotifier, HaikuComposerState>((ref) {
  return HaikuComposerNotifier();
});

/// Haiku composer widget with soft 5-7-5 format
class HaikuComposer extends ConsumerStatefulWidget {
  /// Called when the haiku is submitted
  final void Function(String haiku)? onSubmit;

  /// Whether the composer is read-only
  final bool readOnly;

  const HaikuComposer({
    super.key,
    this.onSubmit,
    this.readOnly = false,
  });

  @override
  ConsumerState<HaikuComposer> createState() => _HaikuComposerState();
}

class _HaikuComposerState extends ConsumerState<HaikuComposer> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (_) => TextEditingController());
    _focusNodes = List.generate(3, (_) => FocusNode());

    // Listen to focus changes
    for (int i = 0; i < 3; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          ref.read(haikuComposerProvider.notifier).setCurrentLine(i);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleTextChange(int lineIndex, String text) {
    final notifier = ref.read(haikuComposerProvider.notifier);
    notifier.handleTextChange(text, lineIndex);

    // Check if we should auto-advance
    final state = ref.read(haikuComposerProvider);
    if (state.currentLine != lineIndex && lineIndex < 2) {
      // Focus moved to next line
      _focusNodes[state.currentLine].requestFocus();
    }
  }

  void _handleKeyEvent(int lineIndex, KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final notifier = ref.read(haikuComposerProvider.notifier);

    // Enter key - manual line break
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (lineIndex < 2) {
        notifier.nextLine();
        _focusNodes[lineIndex + 1].requestFocus();
      } else if (widget.onSubmit != null) {
        // On last line, submit
        final state = ref.read(haikuComposerProvider);
        widget.onSubmit!(state.text);
      }
    }

    // Backspace at start of line - go to previous line
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[lineIndex].text.isEmpty && lineIndex > 0) {
        notifier.previousLine();
        _focusNodes[lineIndex - 1].requestFocus();
        // Move cursor to end of previous line
        final prevText = _controllers[lineIndex - 1].text;
        _controllers[lineIndex - 1].selection = TextSelection.collapsed(
          offset: prevText.length,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(haikuComposerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);

    // Sync controllers with state
    for (int i = 0; i < 3; i++) {
      if (_controllers[i].text != state.lines[i]) {
        _controllers[i].text = state.lines[i];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Haiku input lines
        for (int i = 0; i < 3; i++) ...[
          _HaikuLine(
            lineIndex: i,
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            target: haikuTargets[i],
            current: state.syllableCounts[i],
            isActive: state.currentLine == i,
            readOnly: widget.readOnly,
            textStyle: textTheme.headlineSmall?.copyWith(
              fontFamily: 'Playfair Display',
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
            onChanged: (text) => _handleTextChange(i, text),
            onKeyEvent: (event) => _handleKeyEvent(i, event),
            isDark: isDark,
          ),
          if (i < 2) const SizedBox(height: 8),
        ],

        const SizedBox(height: 16),

        // Overall progress indicator
        _HaikuProgress(
          counts: state.syllableCounts,
          targets: haikuTargets,
          isDark: isDark,
        ),
      ],
    );
  }
}

/// Individual haiku line with syllable indicator
class _HaikuLine extends StatelessWidget {
  final int lineIndex;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int target;
  final int current;
  final bool isActive;
  final bool readOnly;
  final TextStyle? textStyle;
  final void Function(String) onChanged;
  final void Function(KeyEvent) onKeyEvent;
  final bool isDark;

  const _HaikuLine({
    required this.lineIndex,
    required this.controller,
    required this.focusNode,
    required this.target,
    required this.current,
    required this.isActive,
    required this.readOnly,
    required this.textStyle,
    required this.onChanged,
    required this.onKeyEvent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = current == target;
    final isOver = current > target;

    final indicatorColor = isComplete
        ? BrewColors.success
        : isOver
            ? BrewColors.warning
            : (isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight);

    final borderColor = isActive
        ? (isDark ? BrewColors.accentGold : BrewColors.warmBrown)
        : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text input
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: onKeyEvent,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                style: textStyle?.copyWith(
                  color: isDark
                      ? BrewColors.textPrimaryDark
                      : BrewColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: _getHintText(lineIndex),
                  hintStyle: textStyle?.copyWith(
                    color: isDark
                        ? BrewColors.textSecondaryDark.withOpacity(0.5)
                        : BrewColors.textSecondaryLight.withOpacity(0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: onChanged,
                textInputAction: lineIndex < 2
                    ? TextInputAction.next
                    : TextInputAction.done,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Syllable indicator
          _SyllableIndicator(
            current: current,
            target: target,
            color: indicatorColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  String _getHintText(int line) {
    switch (line) {
      case 0:
        return 'First line (5 syllables)';
      case 1:
        return 'Second line (7 syllables)';
      case 2:
        return 'Third line (5 syllables)';
      default:
        return '';
    }
  }
}

/// Syllable count indicator
class _SyllableIndicator extends StatelessWidget {
  final int current;
  final int target;
  final Color color;
  final bool isDark;

  const _SyllableIndicator({
    required this.current,
    required this.target,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = current == target;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$current/$target',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          if (isComplete) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.check,
              size: 14,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

/// Overall haiku progress display
class _HaikuProgress extends StatelessWidget {
  final List<int> counts;
  final List<int> targets;
  final bool isDark;

  const _HaikuProgress({
    required this.counts,
    required this.targets,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = counts[0] == targets[0] &&
        counts[1] == targets[1] &&
        counts[2] == targets[2];

    final progressColor = isValid
        ? BrewColors.success
        : (isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Progress bars for each line
        for (int i = 0; i < 3; i++) ...[
          _LineProgressBar(
            current: counts[i],
            target: targets[i],
            isDark: isDark,
          ),
          if (i < 2) const SizedBox(width: 8),
        ],

        const SizedBox(width: 16),

        // Status text
        Text(
          isValid ? 'Perfect haiku!' : 'Keep writing...',
          style: TextStyle(
            fontSize: 12,
            color: progressColor,
            fontStyle: isValid ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

/// Progress bar for a single line
class _LineProgressBar extends StatelessWidget {
  final int current;
  final int target;
  final bool isDark;

  const _LineProgressBar({
    required this.current,
    required this.target,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / target).clamp(0.0, 1.0);
    final isComplete = current == target;
    final isOver = current > target;

    final fillColor = isComplete
        ? BrewColors.success
        : isOver
            ? BrewColors.warning
            : (isDark ? BrewColors.accentGold : BrewColors.warmBrown);

    final bgColor = isDark
        ? BrewColors.mistDark
        : BrewColors.mistLight;

    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
