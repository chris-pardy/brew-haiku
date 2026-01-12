import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brew_haiku/providers/default_timers_provider.dart';
import 'package:brew_haiku/data/default_timers.dart';

void main() {
  group('Default Timers Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('defaultTimersProvider', () {
      test('returns all default timers', () {
        final timers = container.read(defaultTimersProvider);

        expect(timers.length, 5);
        expect(timers, DefaultTimers.all);
      });

      test('includes both coffee and tea timers', () {
        final timers = container.read(defaultTimersProvider);

        final coffeeCount = timers.where((t) => t.brewType == 'coffee').length;
        final teaCount = timers.where((t) => t.brewType == 'tea').length;

        expect(coffeeCount, 2);
        expect(teaCount, 3);
      });
    });

    group('defaultCoffeeTimersProvider', () {
      test('returns only coffee timers', () {
        final timers = container.read(defaultCoffeeTimersProvider);

        expect(timers.length, 2);
        for (final timer in timers) {
          expect(timer.brewType, 'coffee');
        }
      });

      test('includes Simple Pour Over and French Press', () {
        final timers = container.read(defaultCoffeeTimersProvider);

        final names = timers.map((t) => t.name).toList();
        expect(names, contains('Simple Pour Over'));
        expect(names, contains('French Press'));
      });
    });

    group('defaultTeaTimersProvider', () {
      test('returns only tea timers', () {
        final timers = container.read(defaultTeaTimersProvider);

        expect(timers.length, 3);
        for (final timer in timers) {
          expect(timer.brewType, 'tea');
        }
      });

      test('includes Green Tea, Black Tea, and Gongfu Intro', () {
        final timers = container.read(defaultTeaTimersProvider);

        final names = timers.map((t) => t.name).toList();
        expect(names, contains('Green Tea'));
        expect(names, contains('Black Tea'));
        expect(names, contains('Gongfu Intro'));
      });
    });

    group('defaultTimerByUriProvider', () {
      test('returns timer for valid URI', () {
        final timer = container.read(
          defaultTimerByUriProvider(
            'local://brew-haiku/default/simple-pour-over',
          ),
        );

        expect(timer, isNotNull);
        expect(timer!.name, 'Simple Pour Over');
      });

      test('returns null for invalid URI', () {
        final timer = container.read(
          defaultTimerByUriProvider('invalid-uri'),
        );

        expect(timer, isNull);
      });

      test('returns null for non-default AT URI', () {
        final timer = container.read(
          defaultTimerByUriProvider(
            'at://did:plc:abc/app.brew-haiku.timer/123',
          ),
        );

        expect(timer, isNull);
      });
    });

    group('isDefaultTimerProvider', () {
      test('returns true for default timer URIs', () {
        final isDefault = container.read(
          isDefaultTimerProvider(
            'local://brew-haiku/default/french-press',
          ),
        );

        expect(isDefault, true);
      });

      test('returns false for AT Protocol URIs', () {
        final isDefault = container.read(
          isDefaultTimerProvider(
            'at://did:plc:abc/app.brew-haiku.timer/123',
          ),
        );

        expect(isDefault, false);
      });
    });

    group('defaultTimersByBrewTypeProvider', () {
      test('returns coffee timers for coffee type', () {
        final timers = container.read(
          defaultTimersByBrewTypeProvider('coffee'),
        );

        expect(timers.length, 2);
        for (final timer in timers) {
          expect(timer.brewType, 'coffee');
        }
      });

      test('returns tea timers for tea type', () {
        final timers = container.read(
          defaultTimersByBrewTypeProvider('tea'),
        );

        expect(timers.length, 3);
        for (final timer in timers) {
          expect(timer.brewType, 'tea');
        }
      });

      test('returns empty list for unknown type', () {
        final timers = container.read(
          defaultTimersByBrewTypeProvider('espresso'),
        );

        expect(timers.isEmpty, true);
      });
    });
  });
}
