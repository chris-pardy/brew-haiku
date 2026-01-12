import '../models/timer_model.dart';

/// Default timers available for anonymous users without authentication.
/// These timers are hardcoded and work offline.
class DefaultTimers {
  DefaultTimers._();

  /// Local URI prefix for default timers
  static const String _localUriPrefix = 'local://brew-haiku/default/';

  /// Local DID for default timers (indicates built-in content)
  static const String _localDid = 'did:local:brew-haiku';

  /// Simple Pour Over timer - a straightforward single-pour recipe
  static final simplePourOver = TimerModel(
    uri: '${_localUriPrefix}simple-pour-over',
    did: _localDid,
    handle: 'brew-haiku.app',
    name: 'Simple Pour Over',
    vessel: 'Generic',
    brewType: 'coffee',
    ratio: 16.0,
    saveCount: 0,
    createdAt: DateTime(2024, 1, 1),
    steps: const [
      TimerStepModel(
        action: 'Heat water to 96°C (205°F)',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Rinse filter and preheat vessel',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Add ground coffee (medium-fine)',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Bloom: pour 2x coffee weight in water',
        stepType: 'timed',
        durationSeconds: 30,
      ),
      TimerStepModel(
        action: 'Pour remaining water in slow circles',
        stepType: 'timed',
        durationSeconds: 120,
      ),
      TimerStepModel(
        action: 'Allow to drain completely',
        stepType: 'timed',
        durationSeconds: 30,
      ),
    ],
  );

  /// French Press timer - classic immersion brewing
  static final frenchPress = TimerModel(
    uri: '${_localUriPrefix}french-press',
    did: _localDid,
    handle: 'brew-haiku.app',
    name: 'French Press',
    vessel: 'French Press',
    brewType: 'coffee',
    ratio: 15.0,
    saveCount: 0,
    createdAt: DateTime(2024, 1, 1),
    steps: const [
      TimerStepModel(
        action: 'Heat water to 93°C (200°F)',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Add coarse ground coffee',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Pour all water and stir gently',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Place lid on, do not press yet',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Steep',
        stepType: 'timed',
        durationSeconds: 240,
      ),
      TimerStepModel(
        action: 'Press plunger slowly and serve',
        stepType: 'indeterminate',
      ),
    ],
  );

  /// Green Tea timer - delicate and temperature-sensitive
  static final greenTea = TimerModel(
    uri: '${_localUriPrefix}green-tea',
    did: _localDid,
    handle: 'brew-haiku.app',
    name: 'Green Tea',
    vessel: 'Teapot',
    brewType: 'tea',
    ratio: 50.0,
    saveCount: 0,
    createdAt: DateTime(2024, 1, 1),
    steps: const [
      TimerStepModel(
        action: 'Heat water to 75-80°C (165-175°F)',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Warm the teapot with hot water',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Add tea leaves',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Pour water and steep',
        stepType: 'timed',
        durationSeconds: 120,
      ),
      TimerStepModel(
        action: 'Pour into cups, emptying pot completely',
        stepType: 'indeterminate',
      ),
    ],
  );

  /// Black Tea timer - robust and forgiving
  static final blackTea = TimerModel(
    uri: '${_localUriPrefix}black-tea',
    did: _localDid,
    handle: 'brew-haiku.app',
    name: 'Black Tea',
    vessel: 'Teapot',
    brewType: 'tea',
    ratio: 50.0,
    saveCount: 0,
    createdAt: DateTime(2024, 1, 1),
    steps: const [
      TimerStepModel(
        action: 'Heat water to 100°C (212°F)',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Warm the teapot with hot water',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Add tea leaves',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Pour water and steep',
        stepType: 'timed',
        durationSeconds: 180,
      ),
      TimerStepModel(
        action: 'Pour into cups, emptying pot completely',
        stepType: 'indeterminate',
      ),
    ],
  );

  /// Gongfu Intro timer - traditional Chinese tea ceremony style
  static final gongfuIntro = TimerModel(
    uri: '${_localUriPrefix}gongfu-intro',
    did: _localDid,
    handle: 'brew-haiku.app',
    name: 'Gongfu Intro',
    vessel: 'Gaiwan',
    brewType: 'tea',
    ratio: 5.0,
    saveCount: 0,
    createdAt: DateTime(2024, 1, 1),
    steps: const [
      TimerStepModel(
        action: 'Heat water to 95°C (203°F)',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Warm gaiwan and cups',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Add tea leaves (generous amount)',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Rinse: quick pour and discard',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'First infusion',
        stepType: 'timed',
        durationSeconds: 15,
      ),
      TimerStepModel(
        action: 'Pour into cups and enjoy',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Second infusion',
        stepType: 'timed',
        durationSeconds: 20,
      ),
      TimerStepModel(
        action: 'Pour and enjoy',
        stepType: 'indeterminate',
      ),
      TimerStepModel(
        action: 'Third infusion',
        stepType: 'timed',
        durationSeconds: 30,
      ),
      TimerStepModel(
        action: 'Pour and enjoy (continue as desired)',
        stepType: 'indeterminate',
      ),
    ],
  );

  /// Get all default timers as a list
  static List<TimerModel> get all => [
        simplePourOver,
        frenchPress,
        greenTea,
        blackTea,
        gongfuIntro,
      ];

  /// Get default timers filtered by brew type
  static List<TimerModel> byBrewType(String brewType) {
    return all.where((t) => t.brewType == brewType).toList();
  }

  /// Get coffee timers
  static List<TimerModel> get coffeeTimers =>
      all.where((t) => t.brewType == 'coffee').toList();

  /// Get tea timers
  static List<TimerModel> get teaTimers =>
      all.where((t) => t.brewType == 'tea').toList();

  /// Find a default timer by URI
  static TimerModel? findByUri(String uri) {
    try {
      return all.firstWhere((t) => t.uri == uri);
    } catch (_) {
      return null;
    }
  }

  /// Check if a URI is a default timer
  static bool isDefaultTimer(String uri) {
    return uri.startsWith(_localUriPrefix);
  }
}
