/// Syllable counting utility for haiku composition.
///
/// Uses a combination of:
/// 1. CMU Pronouncing Dictionary entries for common English words
/// 2. Vowel counting heuristic fallback for unknown words
/// 3. Special handling for contractions and edge cases
library syllable_counter;

/// Count syllables in a line of text.
///
/// Returns the total syllable count for all words in the text.
int countSyllables(String text) {
  if (text.trim().isEmpty) return 0;

  final words = _extractWords(text);
  return words.fold(0, (sum, word) => sum + countWordSyllables(word));
}

/// Count syllables in a single word.
///
/// Uses the CMU dictionary lookup first, then falls back to heuristic.
int countWordSyllables(String word) {
  if (word.isEmpty) return 0;

  final normalized = _normalizeWord(word);
  if (normalized.isEmpty) return 0;

  // Check CMU dictionary first
  final dictCount = _cmuDictionary[normalized];
  if (dictCount != null) return dictCount;

  // Handle contractions
  final contractionCount = _handleContraction(normalized);
  if (contractionCount != null) return contractionCount;

  // Fall back to vowel counting heuristic
  return _countSyllablesHeuristic(normalized);
}

/// Extract words from text, handling punctuation.
List<String> _extractWords(String text) {
  // Replace common punctuation with spaces, keep apostrophes for contractions
  final cleaned = text
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) return [];

  return cleaned
      .split(' ')
      .where((w) => w.isNotEmpty && w != "'")
      .toList();
}

/// Normalize a word for dictionary lookup.
String _normalizeWord(String word) {
  return word
      .toLowerCase()
      .replaceAll(RegExp(r"^['\s]+|['\s]+$"), '') // Trim quotes/spaces
      .replaceAll(RegExp(r"[^a-z']"), ''); // Keep only letters and apostrophe
}

/// Handle common contractions.
int? _handleContraction(String word) {
  // Common contractions with syllable counts
  const contractions = <String, int>{
    // 1 syllable contractions
    "i'm": 1,
    "you're": 1,
    "we're": 1,
    "they're": 1,
    "he's": 1,
    "she's": 1,
    "it's": 1,
    "that's": 1,
    "what's": 1,
    "there's": 1,
    "here's": 1,
    "who's": 1,
    "let's": 1,
    "i've": 1,
    "you've": 1,
    "we've": 1,
    "they've": 1,
    "i'll": 1,
    "you'll": 1,
    "he'll": 1,
    "she'll": 1,
    "it'll": 1,
    "we'll": 1,
    "they'll": 1,
    "i'd": 1,
    "you'd": 1,
    "he'd": 1,
    "she'd": 1,
    "we'd": 1,
    "they'd": 1,
    "isn't": 2,
    "aren't": 1,
    "wasn't": 2,
    "weren't": 1,
    "haven't": 2,
    "hasn't": 2,
    "hadn't": 2,
    "won't": 1,
    "wouldn't": 2,
    "don't": 1,
    "doesn't": 2,
    "didn't": 2,
    "can't": 1,
    "couldn't": 2,
    "shouldn't": 2,
    "mightn't": 2,
    "mustn't": 2,
    "needn't": 2,
    "shan't": 1,
    "that'll": 2,
    "who'll": 1,
    "what'll": 2,
    "where's": 1,
    "how's": 1,
    "y'all": 1,
    "ma'am": 1,
    "o'clock": 2,
    "ne'er": 1,
    "e'er": 1,
    "'twas": 1,
    "'tis": 1,
  };

  return contractions[word];
}

/// Vowel-based heuristic for syllable counting.
///
/// Rules:
/// 1. Count vowel groups (a, e, i, o, u, y)
/// 2. Subtract silent e at end
/// 3. Handle special patterns (le, es, ed endings)
/// 4. Minimum 1 syllable per word
int _countSyllablesHeuristic(String word) {
  if (word.isEmpty) return 0;

  final w = word.toLowerCase();
  int count = 0;
  bool prevVowel = false;

  // Count vowel groups
  for (int i = 0; i < w.length; i++) {
    final char = w[i];
    final isVowel = 'aeiouy'.contains(char);

    if (isVowel && !prevVowel) {
      count++;
    }
    prevVowel = isVowel;
  }

  // Adjustments for common patterns

  // Silent e at end (but not "le" which adds a syllable in some words)
  if (w.endsWith('e') && !w.endsWith('le') && w.length > 2) {
    final beforeE = w[w.length - 2];
    if (!'aeiouy'.contains(beforeE)) {
      count--;
    }
  }

  // Words ending in "le" preceded by consonant often add syllable
  if (w.endsWith('le') && w.length > 2) {
    final beforeLe = w[w.length - 3];
    if (!'aeiouy'.contains(beforeLe)) {
      // Already counted by vowel group, no change needed
    }
  }

  // "-es" ending (usually not a syllable unless after s, x, z, ch, sh)
  if (w.endsWith('es') && w.length > 2) {
    final stem = w.substring(0, w.length - 2);
    if (!stem.endsWith('s') &&
        !stem.endsWith('x') &&
        !stem.endsWith('z') &&
        !stem.endsWith('ch') &&
        !stem.endsWith('sh')) {
      // Don't double count, 'e' already may have been counted
    }
  }

  // "-ed" ending (usually not a syllable unless after t or d)
  if (w.endsWith('ed') && w.length > 2) {
    final beforeEd = w[w.length - 3];
    if (beforeEd != 't' && beforeEd != 'd') {
      count--;
    }
  }

  // "-ion" is usually one syllable, but we may have over-counted
  // (handled by vowel grouping)

  // Ensure minimum 1 syllable
  return count < 1 ? 1 : count;
}

/// CMU Pronouncing Dictionary subset for common haiku words.
///
/// This is a curated subset optimized for nature/tea/coffee/mindfulness vocabulary.
/// Format: word -> syllable count
const Map<String, int> _cmuDictionary = {
  // Common 1-syllable words
  'a': 1, 'an': 1, 'the': 1, 'and': 1, 'but': 1, 'or': 1, 'for': 1,
  'of': 1, 'to': 1, 'in': 1, 'on': 1, 'at': 1, 'by': 1, 'with': 1,
  'from': 1, 'up': 1, 'out': 1, 'as': 1, 'is': 1, 'was': 1, 'be': 1,
  'been': 1, 'are': 1, 'were': 1, 'so': 1, 'no': 1, 'not': 1, 'yes': 1,
  'all': 1, 'each': 1, 'just': 1, 'more': 1, 'most': 1, 'some': 1,
  'such': 1, 'than': 1, 'then': 1, 'too': 1, 'very': 2, 'can': 1,
  'will': 1, 'my': 1, 'me': 1, 'we': 1, 'us': 1, 'you': 1, 'your': 1,
  'he': 1, 'him': 1, 'his': 1, 'she': 1, 'her': 1, 'it': 1, 'its': 1,
  'they': 1, 'them': 1, 'their': 1, 'our': 1, 'who': 1, 'what': 1,
  'when': 1, 'where': 1, 'why': 1, 'how': 1, 'which': 1, 'this': 1,
  'that': 1, 'these': 1, 'those': 1, 'here': 1, 'there': 1, 'now': 1,
  'i': 1,

  // Nature words (common in haiku)
  'sun': 1, 'moon': 1, 'star': 1, 'stars': 1, 'sky': 1, 'cloud': 1,
  'clouds': 1, 'rain': 1, 'snow': 1, 'wind': 1, 'storm': 1, 'fog': 1,
  'mist': 1, 'dew': 1, 'frost': 1, 'ice': 1, 'earth': 1, 'ground': 1,
  'stone': 1, 'rock': 1, 'sand': 1, 'dust': 1, 'mud': 1, 'sea': 1,
  'ocean': 2, 'wave': 1, 'waves': 1, 'shore': 1, 'beach': 1, 'lake': 1,
  'pond': 1, 'stream': 1, 'river': 2, 'brook': 1, 'spring': 1,
  'summer': 2, 'autumn': 2, 'fall': 1, 'winter': 2, 'season': 2,
  'seasons': 2, 'year': 1, 'years': 1, 'day': 1, 'days': 1, 'night': 1,
  'nights': 1, 'dawn': 1, 'dusk': 1, 'morning': 2, 'evening': 2,
  'noon': 1, 'midnight': 2, 'hour': 1, 'hours': 1, 'moment': 2,
  'time': 1, 'tree': 1, 'trees': 1, 'leaf': 1, 'leaves': 1, 'branch': 1,
  'branches': 2, 'root': 1, 'roots': 1, 'bark': 1, 'wood': 1, 'forest': 2,
  'woods': 1, 'grove': 1, 'garden': 2, 'field': 1, 'fields': 1,
  'meadow': 2, 'grass': 1, 'flower': 2, 'flowers': 2, 'bloom': 1,
  'blooms': 1, 'blossom': 2, 'blossoms': 2, 'petal': 2, 'petals': 2,
  'seed': 1, 'seeds': 1, 'fruit': 1, 'fruits': 1, 'bird': 1, 'birds': 1,
  'wing': 1, 'wings': 1, 'nest': 1, 'song': 1, 'fly': 1, 'flying': 2,
  'flight': 1, 'frog': 1, 'fish': 1, 'deer': 1, 'fox': 1, 'bear': 1,
  'wolf': 1, 'crow': 1, 'crane': 1, 'swan': 1, 'owl': 1, 'hawk': 1,
  'eagle': 2, 'sparrow': 2, 'robin': 2, 'wren': 1, 'dove': 1,
  'butterfly': 3, 'dragonfly': 3, 'bee': 1, 'bees': 1, 'ant': 1,
  'spider': 2, 'cricket': 2, 'cicada': 3, 'firefly': 2, 'moth': 1,
  'snail': 1, 'path': 1, 'road': 1, 'trail': 1, 'mountain': 2,
  'mountains': 2, 'hill': 1, 'hills': 1, 'valley': 2, 'peak': 1,
  'cliff': 1, 'cave': 1, 'waterfall': 3, 'rainbow': 2, 'shadow': 2,
  'shadows': 2, 'light': 1, 'dark': 1, 'darkness': 2, 'bright': 1,
  'glow': 1, 'glowing': 2, 'shine': 1, 'shining': 2, 'shimmer': 2,
  'sparkle': 2, 'glitter': 2, 'twinkle': 2, 'fade': 1, 'fading': 2,

  // Tea and coffee words
  'tea': 1, 'teas': 1, 'coffee': 2, 'brew': 1, 'brews': 1, 'brewing': 2,
  'brewed': 1, 'cup': 1, 'cups': 1, 'mug': 1, 'pot': 1, 'kettle': 2,
  'steam': 1, 'steaming': 2, 'steep': 1, 'steeping': 2, 'steeped': 1,
  'pour': 1, 'pouring': 2, 'poured': 1, 'sip': 1, 'sipping': 2,
  'sipped': 1, 'drink': 1, 'drinking': 2, 'warm': 1, 'warmth': 1,
  'hot': 1, 'heat': 1, 'heated': 2, 'boil': 1, 'boiling': 2,
  'water': 2, 'aroma': 3, 'scent': 1, 'fragrance': 2, 'flavor': 2,
  'taste': 1, 'bitter': 2, 'sweet': 1, 'smooth': 1, 'rich': 1,
  'green': 1, 'black': 1, 'white': 1, 'oolong': 2, 'herbal': 2,
  'matcha': 2, 'chai': 1, 'espresso': 3, 'latte': 2, 'roast': 1,
  'roasted': 2, 'beans': 1, 'grounds': 1, 'filter': 2, 'drip': 1,
  'french': 1, 'press': 1, 'ritual': 3, 'ceremony': 4,

  // Mindfulness/zen words
  'peace': 1, 'peaceful': 2, 'calm': 1, 'calming': 2, 'still': 1,
  'stillness': 2, 'quiet': 2, 'silence': 2, 'silent': 2, 'breath': 1,
  'breathe': 1, 'breathing': 2, 'inhale': 2, 'exhale': 2, 'rest': 1,
  'resting': 2, 'pause': 1, 'pausing': 2, 'wait': 1, 'waiting': 2,
  'watch': 1, 'watching': 2, 'listen': 2, 'listening': 3, 'hear': 1,
  'hearing': 2, 'see': 1, 'seeing': 2, 'feel': 1, 'feeling': 2,
  'touch': 1, 'touching': 2, 'sense': 1, 'sensing': 2, 'know': 1,
  'knowing': 2, 'think': 1, 'thinking': 2, 'thought': 1, 'thoughts': 1,
  'mind': 1, 'mindful': 2, 'aware': 2, 'awareness': 3, 'present': 2,
  'presence': 2, 'being': 2, 'essence': 2, 'spirit': 2, 'soul': 1,
  'heart': 1, 'love': 1, 'loving': 2, 'gentle': 2, 'gently': 2,
  'soft': 1, 'softly': 2, 'slow': 1, 'slowly': 2, 'simple': 2,
  'simply': 2, 'pure': 1, 'purely': 2, 'empty': 2, 'emptiness': 3,
  'full': 1, 'fullness': 2, 'whole': 1, 'wholeness': 2, 'one': 1,
  'unity': 3, 'flow': 1, 'flowing': 2, 'move': 1, 'moving': 2,
  'change': 1, 'changing': 2, 'passing': 2, 'fleeting': 2,
  'eternal': 3, 'infinite': 3, 'beyond': 2, 'within': 2, 'between': 2,
  'among': 2, 'through': 1, 'across': 2, 'around': 2, 'above': 2,
  'below': 2, 'beneath': 2, 'beside': 2, 'inside': 2, 'outside': 2,

  // Common verbs
  'come': 1, 'comes': 1, 'coming': 2, 'came': 1, 'go': 1, 'goes': 1,
  'going': 2, 'went': 1, 'gone': 1, 'make': 1, 'makes': 1, 'making': 2,
  'made': 1, 'take': 1, 'takes': 1, 'taking': 2, 'took': 1, 'taken': 2,
  'give': 1, 'gives': 1, 'giving': 2, 'gave': 1, 'given': 2, 'get': 1,
  'gets': 1, 'getting': 2, 'got': 1, 'find': 1, 'finds': 1, 'finding': 2,
  'found': 1, 'keep': 1, 'keeps': 1, 'keeping': 2, 'kept': 1, 'let': 1,
  'lets': 1, 'letting': 2, 'hold': 1, 'holds': 1, 'holding': 2,
  'held': 1, 'stand': 1, 'stands': 1, 'standing': 2, 'stood': 1,
  'sit': 1, 'sits': 1, 'sitting': 2, 'sat': 1, 'lie': 1, 'lies': 1,
  'lying': 2, 'lay': 1, 'lain': 1, 'rise': 1, 'rises': 2, 'rising': 2,
  'rose': 1, 'risen': 2, 'falls': 1, 'falling': 2, 'fell': 1,
  'fallen': 2, 'turn': 1, 'turns': 1, 'turning': 2, 'turned': 1,
  'open': 2, 'opens': 2, 'opening': 3, 'opened': 2, 'close': 1,
  'closes': 2, 'closing': 2, 'closed': 1, 'begin': 2, 'begins': 2,
  'beginning': 3, 'began': 2, 'begun': 2, 'end': 1, 'ends': 1,
  'ending': 2, 'ended': 2, 'start': 1, 'starts': 1, 'starting': 2,
  'started': 2, 'stop': 1, 'stops': 1, 'stopping': 2, 'stopped': 1,
  'leave': 1, 'leaving': 2, 'left': 1, 'stay': 1,
  'stays': 1, 'staying': 2, 'stayed': 1, 'return': 2, 'returns': 2,
  'returning': 3, 'returned': 2, 'remember': 3, 'remembers': 3,
  'remembering': 4, 'remembered': 3, 'forget': 2, 'forgets': 2,
  'forgetting': 3, 'forgot': 2, 'forgotten': 3, 'dream': 1,
  'dreams': 1, 'dreaming': 2, 'dreamed': 1, 'dreamt': 1, 'wake': 1,
  'wakes': 1, 'waking': 2, 'woke': 1, 'woken': 2, 'sleep': 1,
  'sleeps': 1, 'sleeping': 2, 'slept': 1,

  // Common adjectives
  'old': 1, 'older': 2, 'oldest': 2, 'new': 1, 'newer': 2, 'newest': 2,
  'young': 1, 'younger': 2, 'youngest': 2, 'big': 1, 'bigger': 2,
  'biggest': 2, 'small': 1, 'smaller': 2, 'smallest': 2, 'little': 2,
  'large': 1, 'larger': 2, 'largest': 2, 'great': 1, 'greater': 2,
  'greatest': 2, 'good': 1, 'better': 2, 'best': 1, 'bad': 1, 'worse': 1,
  'worst': 1, 'high': 1, 'higher': 2, 'highest': 2, 'low': 1, 'lower': 2,
  'lowest': 2, 'long': 1, 'longer': 2, 'longest': 2, 'short': 1,
  'shorter': 2, 'shortest': 2, 'first': 1, 'last': 1, 'next': 1,
  'early': 2, 'earlier': 3, 'earliest': 3, 'late': 1, 'later': 2,
  'latest': 2, 'near': 1, 'nearer': 2, 'nearest': 2, 'far': 1,
  'farther': 2, 'farthest': 2, 'deep': 1, 'deeper': 2, 'deepest': 2,
  'wide': 1, 'wider': 2, 'widest': 2, 'narrow': 2, 'thin': 1,
  'thick': 1, 'heavy': 2, 'heavier': 3, 'heaviest': 3,
  'lighter': 2, 'lightest': 2, 'hard': 1, 'harder': 2, 'hardest': 2,
  'easy': 2, 'easier': 3, 'easiest': 3, 'fast': 1, 'faster': 2,
  'fastest': 2, 'quick': 1, 'quicker': 2, 'quickest': 2, 'cold': 1,
  'colder': 2, 'coldest': 2, 'cool': 1, 'cooler': 2, 'coolest': 2,
  'wet': 1, 'wetter': 2, 'wettest': 2, 'dry': 1, 'drier': 2,
  'driest': 2, 'clear': 1, 'clearer': 2, 'clearest': 2, 'clean': 1,
  'cleaner': 2, 'cleanest': 2, 'fresh': 1, 'fresher': 2, 'freshest': 2,
  'free': 1, 'freer': 2, 'freest': 2, 'true': 1, 'truer': 2, 'truest': 2,
  'real': 1, 'single': 2, 'alone': 2, 'only': 2, 'own': 1, 'same': 1,
  'different': 3, 'other': 2, 'another': 3, 'any': 2, 'every': 2,
  'both': 1, 'few': 1, 'many': 2, 'much': 1, 'several': 3, 'certain': 2,
  'enough': 2, 'half': 1, 'beautiful': 3, 'lovely': 2,
  'pretty': 2, 'ancient': 2, 'sacred': 2, 'holy': 2, 'perfect': 2,
  'complete': 2, 'final': 2, 'sudden': 2, 'constant': 2,

  // Numbers
  'zero': 2, 'two': 1, 'three': 1, 'four': 1, 'five': 1,
  'six': 1, 'seven': 2, 'eight': 1, 'nine': 1, 'ten': 1, 'eleven': 3,
  'twelve': 1, 'thirteen': 2, 'fourteen': 2, 'fifteen': 2, 'sixteen': 2,
  'seventeen': 3, 'eighteen': 2, 'nineteen': 2, 'twenty': 2, 'thirty': 2,
  'forty': 2, 'fifty': 2, 'sixty': 2, 'seventy': 3, 'eighty': 2,
  'ninety': 2, 'hundred': 2, 'thousand': 2, 'million': 2,

  // Haiku-specific
  'haiku': 2, 'poem': 2, 'poems': 2, 'poetry': 3, 'verse': 1, 'verses': 2,
  'word': 1, 'words': 1, 'line': 1, 'lines': 1, 'syllable': 3,
  'syllables': 3, 'write': 1, 'writes': 1, 'writing': 2, 'wrote': 1,
  'written': 2, 'read': 1, 'reads': 1, 'reading': 2, 'ink': 1, 'pen': 1,
  'paper': 2, 'page': 1, 'pages': 2, 'book': 1, 'books': 1,
};
