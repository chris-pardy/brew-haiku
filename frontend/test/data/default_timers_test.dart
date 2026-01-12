import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/data/default_timers.dart';

void main() {
  group('DefaultTimers', () {
    group('all', () {
      test('contains exactly 5 default timers', () {
        expect(DefaultTimers.all.length, 5);
      });

      test('includes Simple Pour Over', () {
        final timer = DefaultTimers.all.firstWhere(
          (t) => t.name == 'Simple Pour Over',
        );
        expect(timer.brewType, 'coffee');
        expect(timer.vessel, 'Generic');
        expect(timer.ratio, 16.0);
      });

      test('includes French Press', () {
        final timer = DefaultTimers.all.firstWhere(
          (t) => t.name == 'French Press',
        );
        expect(timer.brewType, 'coffee');
        expect(timer.vessel, 'French Press');
        expect(timer.ratio, 15.0);
      });

      test('includes Green Tea', () {
        final timer = DefaultTimers.all.firstWhere(
          (t) => t.name == 'Green Tea',
        );
        expect(timer.brewType, 'tea');
        expect(timer.vessel, 'Teapot');
        expect(timer.ratio, 50.0);
      });

      test('includes Black Tea', () {
        final timer = DefaultTimers.all.firstWhere(
          (t) => t.name == 'Black Tea',
        );
        expect(timer.brewType, 'tea');
        expect(timer.vessel, 'Teapot');
        expect(timer.ratio, 50.0);
      });

      test('includes Gongfu Intro', () {
        final timer = DefaultTimers.all.firstWhere(
          (t) => t.name == 'Gongfu Intro',
        );
        expect(timer.brewType, 'tea');
        expect(timer.vessel, 'Gaiwan');
        expect(timer.ratio, 5.0);
      });

      test('all timers have local URIs', () {
        for (final timer in DefaultTimers.all) {
          expect(timer.uri, startsWith('local://brew-haiku/default/'));
        }
      });

      test('all timers have local DID', () {
        for (final timer in DefaultTimers.all) {
          expect(timer.did, 'did:local:brew-haiku');
        }
      });

      test('all timers have brew-haiku.app handle', () {
        for (final timer in DefaultTimers.all) {
          expect(timer.handle, 'brew-haiku.app');
        }
      });

      test('all timers have zero save count', () {
        for (final timer in DefaultTimers.all) {
          expect(timer.saveCount, 0);
        }
      });

      test('all timers have at least one step', () {
        for (final timer in DefaultTimers.all) {
          expect(timer.steps.isNotEmpty, true);
        }
      });
    });

    group('simplePourOver', () {
      test('has correct properties', () {
        final timer = DefaultTimers.simplePourOver;

        expect(timer.name, 'Simple Pour Over');
        expect(timer.vessel, 'Generic');
        expect(timer.brewType, 'coffee');
        expect(timer.ratio, 16.0);
      });

      test('has mixed timed and indeterminate steps', () {
        final timer = DefaultTimers.simplePourOver;

        final timedSteps = timer.steps.where((s) => s.isTimed).toList();
        final indeterminateSteps =
            timer.steps.where((s) => s.isIndeterminate).toList();

        expect(timedSteps.isNotEmpty, true);
        expect(indeterminateSteps.isNotEmpty, true);
      });

      test('calculates total duration correctly', () {
        final timer = DefaultTimers.simplePourOver;

        // 30s bloom + 120s pour + 30s drain = 180s = 3:00
        expect(timer.totalDurationSeconds, 180);
        expect(timer.formattedDuration, '03:00');
      });
    });

    group('frenchPress', () {
      test('has 4 minute steep time', () {
        final timer = DefaultTimers.frenchPress;

        final steepStep = timer.steps.firstWhere(
          (s) => s.action == 'Steep',
        );

        expect(steepStep.durationSeconds, 240);
        expect(steepStep.formattedDuration, '04:00');
      });
    });

    group('greenTea', () {
      test('has 2 minute steep time', () {
        final timer = DefaultTimers.greenTea;

        final steepStep = timer.steps.firstWhere(
          (s) => s.action.contains('steep'),
        );

        expect(steepStep.durationSeconds, 120);
      });
    });

    group('blackTea', () {
      test('has 3 minute steep time', () {
        final timer = DefaultTimers.blackTea;

        final steepStep = timer.steps.firstWhere(
          (s) => s.action.contains('steep'),
        );

        expect(steepStep.durationSeconds, 180);
      });
    });

    group('gongfuIntro', () {
      test('has multiple short infusions', () {
        final timer = DefaultTimers.gongfuIntro;

        final timedSteps = timer.steps.where((s) => s.isTimed).toList();

        expect(timedSteps.length, 3);
        expect(timedSteps[0].durationSeconds, 15);
        expect(timedSteps[1].durationSeconds, 20);
        expect(timedSteps[2].durationSeconds, 30);
      });

      test('has very short total duration', () {
        final timer = DefaultTimers.gongfuIntro;

        // 15 + 20 + 30 = 65 seconds
        expect(timer.totalDurationSeconds, 65);
      });
    });

    group('byBrewType', () {
      test('returns only coffee timers for coffee', () {
        final coffeeTimers = DefaultTimers.byBrewType('coffee');

        expect(coffeeTimers.length, 2);
        for (final timer in coffeeTimers) {
          expect(timer.brewType, 'coffee');
        }
      });

      test('returns only tea timers for tea', () {
        final teaTimers = DefaultTimers.byBrewType('tea');

        expect(teaTimers.length, 3);
        for (final timer in teaTimers) {
          expect(timer.brewType, 'tea');
        }
      });

      test('returns empty list for unknown brew type', () {
        final timers = DefaultTimers.byBrewType('unknown');

        expect(timers.isEmpty, true);
      });
    });

    group('coffeeTimers', () {
      test('returns 2 coffee timers', () {
        expect(DefaultTimers.coffeeTimers.length, 2);
      });

      test('all are coffee type', () {
        for (final timer in DefaultTimers.coffeeTimers) {
          expect(timer.brewType, 'coffee');
        }
      });
    });

    group('teaTimers', () {
      test('returns 3 tea timers', () {
        expect(DefaultTimers.teaTimers.length, 3);
      });

      test('all are tea type', () {
        for (final timer in DefaultTimers.teaTimers) {
          expect(timer.brewType, 'tea');
        }
      });
    });

    group('findByUri', () {
      test('finds Simple Pour Over by URI', () {
        final timer = DefaultTimers.findByUri(
          'local://brew-haiku/default/simple-pour-over',
        );

        expect(timer, isNotNull);
        expect(timer!.name, 'Simple Pour Over');
      });

      test('finds French Press by URI', () {
        final timer = DefaultTimers.findByUri(
          'local://brew-haiku/default/french-press',
        );

        expect(timer, isNotNull);
        expect(timer!.name, 'French Press');
      });

      test('returns null for unknown URI', () {
        final timer = DefaultTimers.findByUri(
          'local://brew-haiku/default/unknown',
        );

        expect(timer, isNull);
      });

      test('returns null for non-local URI', () {
        final timer = DefaultTimers.findByUri(
          'at://did:plc:abc123/app.brew-haiku.timer/xyz',
        );

        expect(timer, isNull);
      });
    });

    group('isDefaultTimer', () {
      test('returns true for default timer URIs', () {
        expect(
          DefaultTimers.isDefaultTimer(
            'local://brew-haiku/default/simple-pour-over',
          ),
          true,
        );
        expect(
          DefaultTimers.isDefaultTimer(
            'local://brew-haiku/default/french-press',
          ),
          true,
        );
      });

      test('returns false for AT Protocol URIs', () {
        expect(
          DefaultTimers.isDefaultTimer(
            'at://did:plc:abc123/app.brew-haiku.timer/xyz',
          ),
          false,
        );
      });

      test('returns false for random strings', () {
        expect(
          DefaultTimers.isDefaultTimer('random-string'),
          false,
        );
      });
    });
  });
}
