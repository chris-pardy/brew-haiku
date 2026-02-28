import '../data/syllable_dictionary.dart';

/// Count syllables for a single word using dictionary + heuristic.
/// Port of ingest/src/services/haiku-detector.ts:101-158
int countWordSyllables(String word) {
  if (word.isEmpty) return 0;

  final normalized = word.toLowerCase().replaceAll(RegExp(r"[^a-z']"), '');
  if (normalized.isEmpty) return 0;

  // Dictionary lookup
  final dictCount = syllableWords[normalized];
  if (dictCount != null) return dictCount;

  // Contraction lookup
  final contrCount = syllableContractions[normalized];
  if (contrCount != null) return contrCount;

  // Vowel-counting heuristic
  return _countSyllablesHeuristic(normalized);
}

/// Vowel-based heuristic fallback for syllable counting.
int _countSyllablesHeuristic(String word) {
  if (word.isEmpty) return 0;

  final w = word.toLowerCase();
  var count = 0;
  var prevVowel = false;
  const vowels = 'aeiouy';

  // Count vowel groups
  for (var i = 0; i < w.length; i++) {
    final isVowel = vowels.contains(w[i]);
    if (isVowel && !prevVowel) {
      count++;
    }
    prevVowel = isVowel;
  }

  // Silent e at end (but not "le" which may add syllable)
  if (w.endsWith('e') && !w.endsWith('le') && w.length > 2) {
    final beforeE = w[w.length - 2];
    if (!vowels.contains(beforeE)) {
      count--;
    }
  }

  // "-ed" ending: silent unless after t or d
  if (w.endsWith('ed') && w.length > 2) {
    final beforeEd = w[w.length - 3];
    if (beforeEd != 't' && beforeEd != 'd') {
      count--;
    }
  }

  // "-eous"/"-ious" over-count
  if (w.contains('eous') || w.contains('ious')) {
    count--;
  }

  return count < 1 ? 1 : count;
}

/// Count syllables for an entire line of text.
int countLineSyllables(String line) {
  final words = line
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  return words.fold(0, (sum, word) => sum + countWordSyllables(word));
}

// --- Haiku line splitting ---

const _haikuSignature = 'via @brew-haiku.app';

/// Split post text into 3 haiku lines based on syllable counting.
/// Strips the signature and emoji, finds the 5-7-5 split, then maps
/// the split back onto the original words (preserving punctuation etc).
/// Returns null if no valid split is found.
List<String>? splitHaikuLines(String text) {
  // Strip signature
  var body = text;
  final sigIdx = body.lastIndexOf(_haikuSignature);
  if (sigIdx != -1) body = body.substring(0, sigIdx);
  body = body.trim();
  if (body.isEmpty) return null;

  // Split into whitespace-delimited tokens (preserving original text)
  final tokens = body.split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  // For each token, get syllable count from the alphabetic core
  // Skip pure-emoji tokens (no letters)
  final countableIndices = <int>[];
  final syllableCounts = <int>[];

  for (var i = 0; i < tokens.length; i++) {
    final letters = tokens[i].replaceAll(RegExp(r"[^a-zA-Z']"), '');
    if (letters.isEmpty) continue;
    countableIndices.add(i);
    syllableCounts.add(countWordSyllables(letters));
  }

  if (countableIndices.length < 3) return null;

  // Find 5-7-5 split (±1 grace) using prefix sums
  final n = syllableCounts.length;
  final prefix = List<int>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + syllableCounts[i];
  }
  final total = prefix[n];
  if (total < 14 || total > 20) return null;

  for (var i = 1; i < n; i++) {
    final line1 = prefix[i];
    if (line1 < 4) continue;
    if (line1 > 6) break;
    for (var j = i + 1; j < n; j++) {
      final line2 = prefix[j] - prefix[i];
      if (line2 < 6) continue;
      if (line2 > 8) break;
      final line3 = prefix[n] - prefix[j];
      if (line3 >= 4 && line3 <= 6) {
        // Map split indices back to original token indices
        // Line 1: tokens 0..split1Token (inclusive)
        // Line 2: tokens split1Token+1..split2Token (inclusive)
        // Line 3: tokens split2Token+1..end
        final split1Token = countableIndices[i - 1];
        final split2Token = countableIndices[j - 1];
        return [
          tokens.sublist(0, split1Token + 1).join(' '),
          tokens.sublist(split1Token + 1, split2Token + 1).join(' '),
          tokens.sublist(split2Token + 1).join(' '),
        ];
      }
    }
  }

  return null;
}
