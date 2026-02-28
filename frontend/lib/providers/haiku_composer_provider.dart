import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/syllable_counter.dart';
import '../services/cache_service.dart';
import '../services/bluesky_service.dart';
import 'auth_provider.dart';

class HaikuComposerState {
  /// The displayed text with linebreaks inserted.
  final String displayText;
  final List<String> lines;
  final List<int> syllableCounts;
  final bool posting;
  final bool posted;
  final String? postUri;
  final String? error;
  final bool pendingOfflinePost;

  const HaikuComposerState({
    this.displayText = '',
    this.lines = const ['', '', ''],
    this.syllableCounts = const [0, 0, 0],
    this.posting = false,
    this.posted = false,
    this.postUri,
    this.error,
    this.pendingOfflinePost = false,
  });

  static const targetSyllables = [5, 7, 5];
  static const totalTarget = 17;

  bool get isComplete {
    final total = syllableCounts[0] + syllableCounts[1] + syllableCounts[2];
    return total == totalTarget &&
        lines[0].isNotEmpty &&
        lines[1].isNotEmpty &&
        lines[2].isNotEmpty;
  }

  int get totalSyllables =>
      syllableCounts[0] + syllableCounts[1] + syllableCounts[2];

  HaikuComposerState copyWith({
    String? displayText,
    List<String>? lines,
    List<int>? syllableCounts,
    bool? posting,
    bool? posted,
    String? postUri,
    String? error,
    bool? pendingOfflinePost,
  }) {
    return HaikuComposerState(
      displayText: displayText ?? this.displayText,
      lines: lines ?? this.lines,
      syllableCounts: syllableCounts ?? this.syllableCounts,
      posting: posting ?? this.posting,
      posted: posted ?? this.posted,
      postUri: postUri,
      error: error,
      pendingOfflinePost: pendingOfflinePost ?? this.pendingOfflinePost,
    );
  }
}

class HaikuComposerNotifier extends StateNotifier<HaikuComposerState> {
  final Ref _ref;

  static const _pendingHaikuKey = 'pending_haiku';

  HaikuComposerNotifier({required Ref ref})
      : _ref = ref,
        super(const HaikuComposerState());

  /// Called with the raw text from the TextField. Strips any existing
  /// newlines, splits into words, re-flows into 5-7-5 lines, then
  /// returns the display text with newlines inserted.
  String updateText(String rawInput) {
    // Strip newlines the user didn't type (we insert them)
    final flat = rawInput.replaceAll('\n', ' ');
    final hasTrailingSpace = flat.endsWith(' ');
    final words = flat.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    const targets = HaikuComposerState.targetSyllables;
    final lines = ['', '', ''];
    final counts = [0, 0, 0];
    var lineIndex = 0;

    for (final word in words) {
      if (lineIndex > 2) break;

      final wordSyllables = countWordSyllables(word);

      // Move to next line if current line has reached its target
      if (counts[lineIndex] >= targets[lineIndex] && lineIndex < 2) {
        lineIndex++;
      }

      if (lineIndex > 2) break;

      if (lines[lineIndex].isNotEmpty) {
        lines[lineIndex] += ' ';
      }
      lines[lineIndex] += word;
      counts[lineIndex] += wordSyllables;
    }

    // Build display text with newlines between lines
    var display = lines.where((l) => l.isNotEmpty).join('\n');

    // Preserve trailing space so the user can keep typing
    if (hasTrailingSpace && words.isNotEmpty) {
      display += ' ';
    }

    state = state.copyWith(
      displayText: display,
      lines: lines,
      syllableCounts: counts,
    );

    return display;
  }

  /// Queue haiku for offline posting.
  Future<void> queueOfflinePost() async {
    final cache = _ref.read(cacheServiceProvider);
    final pending = await cache.read<List<dynamic>>(_pendingHaikuKey) ?? [];
    pending.add({
      'lines': state.lines,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await cache.write(_pendingHaikuKey, pending);
    state = state.copyWith(pendingOfflinePost: true);
  }

  /// Sync any pending offline haiku posts.
  static Future<void> syncPendingPosts({
    required CacheService cache,
    required AuthState auth,
    required BlueskyService bluesky,
    required AuthNotifier authNotifier,
  }) async {
    if (!auth.isAuthenticated) return;

    final pending = await cache.read<List<dynamic>>(_pendingHaikuKey);
    if (pending == null || pending.isEmpty) return;

    final remaining = <dynamic>[];
    for (final item in pending) {
      try {
        final lines = (item as Map)['lines'] as List;
        final pdsUrl = await authNotifier.getPdsUrl();
        await bluesky.postHaiku(
          lines: lines.cast<String>(),
          session: auth.session!,
          pdsUrl: pdsUrl,
        );
      } catch (_) {
        remaining.add(item);
      }
    }

    if (remaining.isEmpty) {
      await cache.delete(_pendingHaikuKey);
    } else {
      await cache.write(_pendingHaikuKey, remaining);
    }
  }

  void reset() {
    state = const HaikuComposerState();
  }
}

final haikuComposerProvider =
    StateNotifierProvider<HaikuComposerNotifier, HaikuComposerState>((ref) {
  return HaikuComposerNotifier(ref: ref);
});
