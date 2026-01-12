import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/utils/syllable_counter.dart';

void main() {
  group('countWordSyllables', () {
    group('CMU dictionary words', () {
      test('counts 1-syllable words correctly', () {
        expect(countWordSyllables('tea'), 1);
        expect(countWordSyllables('cup'), 1);
        expect(countWordSyllables('brew'), 1);
        expect(countWordSyllables('steam'), 1);
        expect(countWordSyllables('sun'), 1);
        expect(countWordSyllables('moon'), 1);
        expect(countWordSyllables('rain'), 1);
        expect(countWordSyllables('leaf'), 1);
        expect(countWordSyllables('bird'), 1);
      });

      test('counts 2-syllable words correctly', () {
        expect(countWordSyllables('coffee'), 2);
        expect(countWordSyllables('brewing'), 2);
        expect(countWordSyllables('morning'), 2);
        expect(countWordSyllables('water'), 2);
        expect(countWordSyllables('flower'), 2);
        expect(countWordSyllables('river'), 2);
        expect(countWordSyllables('autumn'), 2);
        expect(countWordSyllables('silent'), 2);
        expect(countWordSyllables('gentle'), 2);
      });

      test('counts 3-syllable words correctly', () {
        expect(countWordSyllables('butterfly'), 3);
        expect(countWordSyllables('waterfall'), 3);
        expect(countWordSyllables('espresso'), 3);
        expect(countWordSyllables('ritual'), 3);
        expect(countWordSyllables('awareness'), 3);
        expect(countWordSyllables('beautiful'), 3);
        expect(countWordSyllables('syllable'), 3);
      });

      test('counts 4-syllable words correctly', () {
        expect(countWordSyllables('ceremony'), 4);
        expect(countWordSyllables('remembering'), 4);
      });
    });

    group('contractions', () {
      test('counts common contractions correctly', () {
        expect(countWordSyllables("I'm"), 1);
        expect(countWordSyllables("you're"), 1);
        expect(countWordSyllables("it's"), 1);
        expect(countWordSyllables("don't"), 1);
        expect(countWordSyllables("won't"), 1);
        expect(countWordSyllables("can't"), 1);
        expect(countWordSyllables("we'll"), 1);
        expect(countWordSyllables("they've"), 1);
        expect(countWordSyllables("let's"), 1);
      });

      test('counts 2-syllable contractions correctly', () {
        expect(countWordSyllables("isn't"), 2);
        expect(countWordSyllables("wasn't"), 2);
        expect(countWordSyllables("doesn't"), 2);
        expect(countWordSyllables("haven't"), 2);
        expect(countWordSyllables("wouldn't"), 2);
        expect(countWordSyllables("couldn't"), 2);
        expect(countWordSyllables("shouldn't"), 2);
        expect(countWordSyllables("o'clock"), 2);
      });
    });

    group('heuristic fallback', () {
      test('handles unknown words with vowel counting', () {
        // These words should use heuristic
        expect(countWordSyllables('xyz'), 1); // minimum 1
        expect(countWordSyllables('bluesky'), 2);
        expect(countWordSyllables('atproto'), 3);
      });

      test('handles silent e', () {
        expect(countWordSyllables('make'), 1);
        expect(countWordSyllables('take'), 1);
        expect(countWordSyllables('like'), 1);
        expect(countWordSyllables('time'), 1);
        expect(countWordSyllables('home'), 1);
      });

      test('handles -ed endings', () {
        expect(countWordSyllables('walked'), 1);
        expect(countWordSyllables('played'), 1);
        expect(countWordSyllables('wanted'), 2);
        expect(countWordSyllables('needed'), 2);
      });
    });

    group('edge cases', () {
      test('returns 0 for empty string', () {
        expect(countWordSyllables(''), 0);
      });

      test('handles single letters', () {
        expect(countWordSyllables('a'), 1);
        expect(countWordSyllables('I'), 1);
      });

      test('normalizes case', () {
        expect(countWordSyllables('TEA'), 1);
        expect(countWordSyllables('Coffee'), 2);
        expect(countWordSyllables('HAIKU'), 2);
      });

      test('strips punctuation', () {
        expect(countWordSyllables('tea,'), 1);
        expect(countWordSyllables('tea.'), 1);
        expect(countWordSyllables('tea!'), 1);
        expect(countWordSyllables('"tea"'), 1);
      });
    });
  });

  group('countSyllables (full text)', () {
    test('counts empty string as 0', () {
      expect(countSyllables(''), 0);
      expect(countSyllables('   '), 0);
    });

    test('counts single word', () {
      expect(countSyllables('tea'), 1);
      expect(countSyllables('coffee'), 2);
      expect(countSyllables('butterfly'), 3);
    });

    test('counts multiple words', () {
      expect(countSyllables('green tea'), 2);
      expect(countSyllables('hot coffee'), 3);
      expect(countSyllables('steam rising'), 3);
    });

    test('counts typical haiku lines', () {
      // Classic 5-syllable lines
      expect(countSyllables('an old silent pond'), 5);
      expect(countSyllables('a frog jumps into'), 5);
      expect(countSyllables('the splash of water'), 5);

      // 7-syllable lines
      expect(countSyllables('a frog leaps into the pond'), 7);
    });

    test('handles punctuation in sentences', () {
      expect(countSyllables('steam rises, slowly'), 5); // steam(1) + rises(2) + slowly(2)
      expect(countSyllables('wait... listen... breathe'), 4); // wait(1) + listen(2) + breathe(1)
      expect(countSyllables('tea, warm and peaceful'), 5);
    });

    test('handles contractions in sentences', () {
      expect(countSyllables("I'm brewing tea"), 4);
      expect(countSyllables("it's a quiet morning"), 6);
      expect(countSyllables("we don't rush the tea"), 5);
    });

    test('handles mixed case', () {
      expect(countSyllables('Green Tea'), 2);
      expect(countSyllables('QUIET MORNING'), 4);
    });

    test('handles extra whitespace', () {
      expect(countSyllables('tea   cup'), 2);
      expect(countSyllables('  morning tea  '), 3);
      expect(countSyllables('a    quiet    moment'), 5);
    });
  });

  group('haiku validation examples', () {
    test('validates classic haiku structure', () {
      // Basho's famous frog haiku (English adaptation)
      expect(countSyllables('an old silent pond'), 5);
      expect(countSyllables('a frog jumps into the pond'), 7);
      expect(countSyllables('splash silence again'), 5);
    });

    test('validates tea-themed haiku', () {
      expect(countSyllables('steam rises slowly'), 5); // steam(1) + rises(2) + slowly(2)
      expect(countSyllables('from the cup of morning tea'), 7);
      expect(countSyllables('warmth fills the quiet'), 5);
    });

    test('validates coffee-themed haiku', () {
      expect(countSyllables('dark beans ground fresh'), 4);
      expect(countSyllables('the aroma fills the room'), 7);
      expect(countSyllables('first sip of the day'), 5);
    });

    test('validates mindfulness haiku', () {
      expect(countSyllables('breathing in breathing'), 5); // breathing(2) + in(1) + breathing(2)
      expect(countSyllables('out slowly the world fades'), 7); // out(1) + slowly(2) + the(1) + world(1) + fades(2)
      expect(countSyllables('peace in each moment'), 5);
    });
  });

  group('real-time typing simulation', () {
    test('updates correctly as user types word by word', () {
      expect(countSyllables(''), 0);
      expect(countSyllables('the'), 1);
      expect(countSyllables('the tea'), 2);
      expect(countSyllables('the tea is'), 3);
      expect(countSyllables('the tea is warm'), 4);
      expect(countSyllables('the tea is warm and'), 5);
    });

    test('updates correctly with backspace (removing words)', () {
      expect(countSyllables('the tea is warm'), 4);
      expect(countSyllables('the tea is'), 3);
      expect(countSyllables('the tea'), 2);
      expect(countSyllables('the'), 1);
      expect(countSyllables(''), 0);
    });
  });
}
