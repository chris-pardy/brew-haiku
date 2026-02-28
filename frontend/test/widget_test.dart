import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/utils/syllable_counter.dart';

void main() {
  group('SyllableCounter', () {
    test('counts basic words', () {
      expect(countWordSyllables('haiku'), 2);
      expect(countWordSyllables('tea'), 1);
      expect(countWordSyllables('beautiful'), 3);
    });

    test('counts line syllables', () {
      expect(countLineSyllables('the old pond'), 3);
    });
  });
}
