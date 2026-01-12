import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/services/syllable_counter.dart';

void main() {
  group('countSyllablesInWord', () {
    test('counts single syllable words correctly', () {
      expect(countSyllablesInWord('tea'), 1);
      expect(countSyllablesInWord('cup'), 1);
      expect(countSyllablesInWord('steam'), 1);
      expect(countSyllablesInWord('brew'), 1);
      expect(countSyllablesInWord('leaf'), 1);
      expect(countSyllablesInWord('peace'), 1);
      expect(countSyllablesInWord('dream'), 1);
    });

    test('counts two syllable words correctly', () {
      expect(countSyllablesInWord('coffee'), 2);
      expect(countSyllablesInWord('water'), 2);
      expect(countSyllablesInWord('morning'), 2);
      expect(countSyllablesInWord('evening'), 2);
      expect(countSyllablesInWord('silence'), 2);
      expect(countSyllablesInWord('gentle'), 2);
      expect(countSyllablesInWord('flower'), 2);
    });

    test('counts three syllable words correctly', () {
      expect(countSyllablesInWord('beautiful'), 3);
      expect(countSyllablesInWord('harmony'), 3);
      expect(countSyllablesInWord('ritual'), 3);
      expect(countSyllablesInWord('syllable'), 3);
      expect(countSyllablesInWord('poetry'), 3);
    });

    test('counts four+ syllable words correctly', () {
      expect(countSyllablesInWord('ceremony'), 4);
      expect(countSyllablesInWord('cappuccino'), 4);
      expect(countSyllablesInWord('meditation'), 4);
      expect(countSyllablesInWord('appreciation'), 5);
      expect(countSyllablesInWord('tranquility'), 5);
    });

    test('handles empty string', () {
      expect(countSyllablesInWord(''), 0);
    });

    test('handles punctuation', () {
      expect(countSyllablesInWord('tea,'), 1);
      expect(countSyllablesInWord('coffee.'), 2);
      expect(countSyllablesInWord('water!'), 2);
      expect(countSyllablesInWord('"morning"'), 2);
    });

    test('is case insensitive', () {
      expect(countSyllablesInWord('Tea'), 1);
      expect(countSyllablesInWord('TEA'), 1);
      expect(countSyllablesInWord('Coffee'), 2);
      expect(countSyllablesInWord('COFFEE'), 2);
    });

    test('handles contractions', () {
      expect(countSyllablesInWord("I'm"), 1);
      expect(countSyllablesInWord("you're"), 1);
      expect(countSyllablesInWord("don't"), 1);
      expect(countSyllablesInWord("isn't"), 2);
      expect(countSyllablesInWord("wouldn't"), 2);
      expect(countSyllablesInWord("o'clock"), 2);
    });

    test('handles informal contractions', () {
      expect(countSyllablesInWord("gonna"), 2);
      expect(countSyllablesInWord("wanna"), 2);
      expect(countSyllablesInWord("gotta"), 2);
    });
  });

  group('countSyllablesInLine', () {
    test('counts syllables in a simple line', () {
      expect(countSyllablesInLine('the tea is hot'), 4);
      expect(countSyllablesInLine('morning coffee steam'), 5);
      expect(countSyllablesInLine('a cup of water'), 5);
    });

    test('handles empty line', () {
      expect(countSyllablesInLine(''), 0);
      expect(countSyllablesInLine('   '), 0);
    });

    test('handles extra whitespace', () {
      expect(countSyllablesInLine('  the   tea   is   hot  '), 4);
    });

    test('counts classic haiku lines', () {
      // "An old silent pond" - 5 syllables
      expect(countSyllablesInLine('an old silent pond'), 5);
      // "A frog jumps into the pond" - 7 syllables
      expect(countSyllablesInLine('a frog jumps into the pond'), 7);
      // "Splash! Silence again" - 5 syllables
      expect(countSyllablesInLine('splash silence again'), 5);
    });
  });

  group('countHaikuSyllables', () {
    test('counts syllables per line', () {
      const haiku = 'morning tea steam rises\n'
          'silence fills the quiet room\n'
          'peace in every sip';

      final counts = countHaikuSyllables(haiku);
      expect(counts.length, 3);
    });

    test('handles single line', () {
      final counts = countHaikuSyllables('morning coffee');
      expect(counts.length, 1);
      expect(counts[0], 4);
    });

    test('handles empty string', () {
      final counts = countHaikuSyllables('');
      expect(counts.length, 1);
      expect(counts[0], 0);
    });
  });

  group('isValidHaikuStructure', () {
    test('validates correct 5-7-5 structure', () {
      // Create a haiku with exactly 5-7-5 syllables
      const haiku = 'an old silent pond\n'
          'a frog jumps into the pond\n'
          'splash silence again';

      expect(isValidHaikuStructure(haiku), true);
    });

    test('rejects incorrect line count', () {
      expect(isValidHaikuStructure('one line only'), false);
      expect(isValidHaikuStructure('line one\nline two'), false);
      expect(isValidHaikuStructure('one\ntwo\nthree\nfour'), false);
    });

    test('rejects incorrect syllable counts', () {
      const wrongFirst = 'too many syllables here now\n'
          'a frog jumps into the pond\n'
          'splash silence again';
      expect(isValidHaikuStructure(wrongFirst), false);

      const wrongSecond = 'an old silent pond\n'
          'short line\n'
          'splash silence again';
      expect(isValidHaikuStructure(wrongSecond), false);

      const wrongThird = 'an old silent pond\n'
          'a frog jumps into the pond\n'
          'way too many words in this line';
      expect(isValidHaikuStructure(wrongThird), false);
    });
  });

  group('vowel counting fallback', () {
    test('handles unknown words with vowel counting', () {
      // Made up words should use vowel counting
      final count = countSyllablesInWord('flurble');
      expect(count, greaterThan(0));
    });

    test('handles words ending in silent e', () {
      // Words like 'make', 'take', 'bake' should be 1 syllable
      expect(countSyllablesInWord('make'), 1);
      expect(countSyllablesInWord('take'), 1);
      expect(countSyllablesInWord('bake'), 1);
      expect(countSyllablesInWord('like'), 1);
    });

    test('handles words ending in le', () {
      expect(countSyllablesInWord('simple'), 2);
      expect(countSyllablesInWord('humble'), 2);
      expect(countSyllablesInWord('gentle'), 2);
    });
  });

  group('tea and coffee vocabulary', () {
    test('counts tea varieties correctly', () {
      expect(countSyllablesInWord('matcha'), 2);
      expect(countSyllablesInWord('oolong'), 2);
      expect(countSyllablesInWord('sencha'), 2);
      expect(countSyllablesInWord('gyokuro'), 3);
      expect(countSyllablesInWord('darjeeling'), 3);
    });

    test('counts coffee terms correctly', () {
      expect(countSyllablesInWord('espresso'), 3);
      expect(countSyllablesInWord('cappuccino'), 4);
      expect(countSyllablesInWord('americano'), 4);
      expect(countSyllablesInWord('latte'), 2);
      expect(countSyllablesInWord('mocha'), 2);
    });

    test('counts brewing equipment correctly', () {
      expect(countSyllablesInWord('chemex'), 2);
      expect(countSyllablesInWord('aeropress'), 3);
      expect(countSyllablesInWord('gaiwan'), 2);
      expect(countSyllablesInWord('kyusu'), 2);
      expect(countSyllablesInWord('kettle'), 2);
      expect(countSyllablesInWord('teapot'), 2);
    });

    test('counts flavor descriptors correctly', () {
      expect(countSyllablesInWord('bitter'), 2);
      expect(countSyllablesInWord('floral'), 2);
      expect(countSyllablesInWord('earthy'), 2);
      expect(countSyllablesInWord('caramel'), 3);
      expect(countSyllablesInWord('chocolate'), 3);
      expect(countSyllablesInWord('vanilla'), 3);
    });
  });

  group('nature vocabulary for haiku', () {
    test('counts nature words correctly', () {
      expect(countSyllablesInWord('mountain'), 2);
      expect(countSyllablesInWord('river'), 2);
      expect(countSyllablesInWord('ocean'), 2);
      expect(countSyllablesInWord('forest'), 2);
      expect(countSyllablesInWord('meadow'), 2);
    });

    test('counts weather words correctly', () {
      expect(countSyllablesInWord('rain'), 1);
      expect(countSyllablesInWord('snow'), 1);
      expect(countSyllablesInWord('wind'), 1);
      expect(countSyllablesInWord('mist'), 1);
      expect(countSyllablesInWord('fog'), 1);
      expect(countSyllablesInWord('dew'), 1);
    });

    test('counts season words correctly', () {
      expect(countSyllablesInWord('spring'), 1);
      expect(countSyllablesInWord('summer'), 2);
      expect(countSyllablesInWord('autumn'), 2);
      expect(countSyllablesInWord('winter'), 2);
    });
  });

  group('mindfulness vocabulary', () {
    test('counts meditation terms correctly', () {
      expect(countSyllablesInWord('peaceful'), 2);
      expect(countSyllablesInWord('mindful'), 2);
      expect(countSyllablesInWord('serene'), 2);
      expect(countSyllablesInWord('tranquil'), 2);
      expect(countSyllablesInWord('meditation'), 4);
      expect(countSyllablesInWord('mindfulness'), 3);
    });

    test('counts action words correctly', () {
      expect(countSyllablesInWord('breathing'), 2);
      expect(countSyllablesInWord('flowing'), 2);
      expect(countSyllablesInWord('floating'), 2);
      expect(countSyllablesInWord('drifting'), 2);
      expect(countSyllablesInWord('awakening'), 4);
    });
  });
}
