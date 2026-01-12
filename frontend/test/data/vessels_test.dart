import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/data/vessels.dart';

void main() {
  group('Vessel', () {
    test('creates vessel with required properties', () {
      const vessel = Vessel(
        name: 'Test Vessel',
        category: 'coffee',
        defaultRatio: 16,
        defaultDurationSeconds: 180,
        description: 'Test description',
      );

      expect(vessel.name, 'Test Vessel');
      expect(vessel.category, 'coffee');
      expect(vessel.defaultRatio, 16);
      expect(vessel.defaultDurationSeconds, 180);
      expect(vessel.description, 'Test description');
    });

    test('formattedDuration formats correctly', () {
      const vessel = Vessel(
        name: 'Test',
        category: 'coffee',
        defaultRatio: 16,
        defaultDurationSeconds: 180, // 3:00
        description: '',
      );

      expect(vessel.formattedDuration, '03:00');
    });

    test('formattedDuration handles seconds only', () {
      const vessel = Vessel(
        name: 'Test',
        category: 'tea',
        defaultRatio: 5,
        defaultDurationSeconds: 30, // 0:30
        description: '',
      );

      expect(vessel.formattedDuration, '00:30');
    });

    test('formattedDuration handles zero duration', () {
      const vessel = Vessel(
        name: 'Test',
        category: 'tea',
        defaultRatio: 20,
        defaultDurationSeconds: 0,
        description: '',
      );

      expect(vessel.formattedDuration, '00:00');
    });

    test('formattedRatio formats whole numbers', () {
      const vessel = Vessel(
        name: 'Test',
        category: 'coffee',
        defaultRatio: 16,
        defaultDurationSeconds: 180,
        description: '',
      );

      expect(vessel.formattedRatio, '16:1');
    });

    test('formattedRatio formats decimals', () {
      const vessel = Vessel(
        name: 'Test',
        category: 'coffee',
        defaultRatio: 16.5,
        defaultDurationSeconds: 180,
        description: '',
      );

      expect(vessel.formattedRatio, '16.5:1');
    });
  });

  group('Vessels', () {
    test('all contains expected number of vessels', () {
      expect(Vessels.all.length, greaterThanOrEqualTo(12));
    });

    test('coffeeVessels contains only coffee', () {
      for (final vessel in Vessels.coffeeVessels) {
        expect(vessel.category, 'coffee');
      }
    });

    test('teaVessels contains only tea', () {
      for (final vessel in Vessels.teaVessels) {
        expect(vessel.category, 'tea');
      }
    });

    test('coffeeVessels includes expected vessels', () {
      final names = Vessels.coffeeVessels.map((v) => v.name).toList();
      expect(names, contains('Hario V60'));
      expect(names, contains('Chemex'));
      expect(names, contains('AeroPress'));
      expect(names, contains('French Press'));
    });

    test('teaVessels includes expected vessels', () {
      final names = Vessels.teaVessels.map((v) => v.name).toList();
      expect(names, contains('Gaiwan'));
      expect(names, contains('Kyusu'));
      expect(names, contains('Western Teapot'));
    });

    test('findByName finds vessel', () {
      final vessel = Vessels.findByName('Hario V60');
      expect(vessel, isNotNull);
      expect(vessel!.name, 'Hario V60');
    });

    test('findByName is case insensitive', () {
      final vessel = Vessels.findByName('hario v60');
      expect(vessel, isNotNull);
      expect(vessel!.name, 'Hario V60');
    });

    test('findByName returns null for unknown', () {
      final vessel = Vessels.findByName('Unknown Vessel');
      expect(vessel, isNull);
    });

    group('Hario V60', () {
      test('has correct properties', () {
        expect(Vessels.harioV60.name, 'Hario V60');
        expect(Vessels.harioV60.category, 'coffee');
        expect(Vessels.harioV60.defaultRatio, 16);
        expect(Vessels.harioV60.defaultDurationSeconds, 180);
      });
    });

    group('Chemex', () {
      test('has correct properties', () {
        expect(Vessels.chemex.name, 'Chemex');
        expect(Vessels.chemex.defaultRatio, 15);
        expect(Vessels.chemex.defaultDurationSeconds, 240);
      });
    });

    group('AeroPress', () {
      test('has correct properties', () {
        expect(Vessels.aeroPress.name, 'AeroPress');
        expect(Vessels.aeroPress.defaultRatio, 12);
        expect(Vessels.aeroPress.defaultDurationSeconds, 120);
      });
    });

    group('Gaiwan', () {
      test('has correct properties', () {
        expect(Vessels.gaiwan.name, 'Gaiwan');
        expect(Vessels.gaiwan.category, 'tea');
        expect(Vessels.gaiwan.defaultRatio, 5);
        expect(Vessels.gaiwan.defaultDurationSeconds, 30);
      });
    });

    group('Grandpa Style', () {
      test('has variable duration (0)', () {
        expect(Vessels.grandpaStyle.name, 'Grandpa Style');
        expect(Vessels.grandpaStyle.defaultDurationSeconds, 0);
      });
    });

    test('all vessels have non-empty names', () {
      for (final vessel in Vessels.all) {
        expect(vessel.name.isNotEmpty, true);
      }
    });

    test('all vessels have non-empty descriptions', () {
      for (final vessel in Vessels.all) {
        expect(vessel.description.isNotEmpty, true);
      }
    });

    test('all vessels have valid ratios', () {
      for (final vessel in Vessels.all) {
        expect(vessel.defaultRatio, greaterThan(0));
      }
    });

    test('all vessels have valid categories', () {
      for (final vessel in Vessels.all) {
        expect(['coffee', 'tea'], contains(vessel.category));
      }
    });
  });
}
