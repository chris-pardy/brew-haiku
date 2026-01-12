import 'package:flutter_test/flutter_test.dart';
import 'package:brew_haiku/models/timer_model.dart';

void main() {
  group('TimerStepModel', () {
    test('creates from JSON correctly', () {
      final json = {
        'action': 'Bloom with 50ml',
        'stepType': 'timed',
        'durationSeconds': 30,
      };

      final step = TimerStepModel.fromJson(json);

      expect(step.action, 'Bloom with 50ml');
      expect(step.stepType, 'timed');
      expect(step.durationSeconds, 30);
    });

    test('creates indeterminate step from JSON', () {
      final json = {
        'action': 'Wait for drain',
        'stepType': 'indeterminate',
      };

      final step = TimerStepModel.fromJson(json);

      expect(step.action, 'Wait for drain');
      expect(step.stepType, 'indeterminate');
      expect(step.durationSeconds, isNull);
    });

    test('converts to JSON correctly', () {
      const step = TimerStepModel(
        action: 'Pour remaining',
        stepType: 'timed',
        durationSeconds: 90,
      );

      final json = step.toJson();

      expect(json['action'], 'Pour remaining');
      expect(json['stepType'], 'timed');
      expect(json['durationSeconds'], 90);
    });

    test('toJson omits null durationSeconds', () {
      const step = TimerStepModel(
        action: 'Wait',
        stepType: 'indeterminate',
      );

      final json = step.toJson();

      expect(json.containsKey('durationSeconds'), false);
    });

    test('isTimed returns correct value', () {
      const timedStep = TimerStepModel(
        action: 'Pour',
        stepType: 'timed',
        durationSeconds: 30,
      );
      const indeterminateStep = TimerStepModel(
        action: 'Wait',
        stepType: 'indeterminate',
      );

      expect(timedStep.isTimed, true);
      expect(timedStep.isIndeterminate, false);
      expect(indeterminateStep.isTimed, false);
      expect(indeterminateStep.isIndeterminate, true);
    });

    test('formattedDuration formats correctly', () {
      const step1 = TimerStepModel(
        action: 'Step',
        stepType: 'timed',
        durationSeconds: 90,
      );
      const step2 = TimerStepModel(
        action: 'Step',
        stepType: 'timed',
        durationSeconds: 5,
      );
      const step3 = TimerStepModel(
        action: 'Step',
        stepType: 'indeterminate',
      );

      expect(step1.formattedDuration, '01:30');
      expect(step2.formattedDuration, '00:05');
      expect(step3.formattedDuration, '--:--');
    });
  });

  group('TimerModel', () {
    test('creates from JSON correctly', () {
      final json = {
        'uri': 'at://did:plc:test/app.brew-haiku.timer/abc123',
        'did': 'did:plc:test',
        'handle': 'test.bsky.social',
        'name': 'Morning V60',
        'vessel': 'Hario V60',
        'brewType': 'coffee',
        'ratio': 16.0,
        'steps': [
          {'action': 'Bloom', 'stepType': 'timed', 'durationSeconds': 30},
          {'action': 'Pour', 'stepType': 'timed', 'durationSeconds': 90},
        ],
        'saveCount': 42,
        'createdAt': '2024-01-15T10:30:00.000Z',
      };

      final timer = TimerModel.fromJson(json);

      expect(timer.uri, 'at://did:plc:test/app.brew-haiku.timer/abc123');
      expect(timer.did, 'did:plc:test');
      expect(timer.handle, 'test.bsky.social');
      expect(timer.name, 'Morning V60');
      expect(timer.vessel, 'Hario V60');
      expect(timer.brewType, 'coffee');
      expect(timer.ratio, 16.0);
      expect(timer.steps.length, 2);
      expect(timer.saveCount, 42);
    });

    test('converts to JSON correctly', () {
      final timer = TimerModel(
        uri: 'at://test/timer/1',
        did: 'did:plc:test',
        handle: 'test.bsky.social',
        name: 'Test Timer',
        vessel: 'V60',
        brewType: 'coffee',
        ratio: 15.0,
        steps: const [
          TimerStepModel(action: 'Bloom', stepType: 'timed', durationSeconds: 30),
        ],
        saveCount: 10,
        createdAt: DateTime.parse('2024-01-15T10:30:00.000Z'),
      );

      final json = timer.toJson();

      expect(json['uri'], 'at://test/timer/1');
      expect(json['name'], 'Test Timer');
      expect(json['steps'], isA<List>());
    });

    test('totalDurationSeconds calculates correctly', () {
      final timer = TimerModel(
        uri: 'at://test/timer/1',
        did: 'did:plc:test',
        name: 'Test Timer',
        vessel: 'V60',
        brewType: 'coffee',
        steps: const [
          TimerStepModel(action: 'Step 1', stepType: 'timed', durationSeconds: 30),
          TimerStepModel(action: 'Step 2', stepType: 'indeterminate'),
          TimerStepModel(action: 'Step 3', stepType: 'timed', durationSeconds: 60),
        ],
        saveCount: 1,
        createdAt: DateTime.now(),
      );

      expect(timer.totalDurationSeconds, 90); // Only timed steps
    });

    test('formattedDuration formats correctly', () {
      final timer = TimerModel(
        uri: 'at://test/timer/1',
        did: 'did:plc:test',
        name: 'Test Timer',
        vessel: 'V60',
        brewType: 'coffee',
        steps: const [
          TimerStepModel(action: 'Step', stepType: 'timed', durationSeconds: 150),
        ],
        saveCount: 1,
        createdAt: DateTime.now(),
      );

      expect(timer.formattedDuration, '02:30');
    });

    test('handles null handle', () {
      final json = {
        'uri': 'at://test/timer/1',
        'did': 'did:plc:test',
        'handle': null,
        'name': 'Timer',
        'vessel': 'V60',
        'brewType': 'coffee',
        'ratio': null,
        'steps': [],
        'saveCount': 0,
        'createdAt': '2024-01-15T10:30:00.000Z',
      };

      final timer = TimerModel.fromJson(json);

      expect(timer.handle, isNull);
      expect(timer.ratio, isNull);
    });
  });
}
