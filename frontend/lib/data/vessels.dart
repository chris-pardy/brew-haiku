/// Pre-configured brewing vessels with default ratios and times.
///
/// These vessels serve as templates for creating new timers.
class Vessel {
  final String name;
  final String category; // 'coffee' or 'tea'
  final double defaultRatio;
  final int defaultDurationSeconds;
  final String description;

  const Vessel({
    required this.name,
    required this.category,
    required this.defaultRatio,
    required this.defaultDurationSeconds,
    required this.description,
  });

  /// Format the default duration as mm:ss
  String get formattedDuration {
    final minutes = defaultDurationSeconds ~/ 60;
    final seconds = defaultDurationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format the ratio as "X:1"
  String get formattedRatio => '${defaultRatio.toStringAsFixed(defaultRatio.truncateToDouble() == defaultRatio ? 0 : 1)}:1';
}

/// Collection of pre-configured vessels
class Vessels {
  Vessels._();

  // Coffee vessels
  static const harioV60 = Vessel(
    name: 'Hario V60',
    category: 'coffee',
    defaultRatio: 16,
    defaultDurationSeconds: 180, // 3:00
    description: 'Iconic cone dripper for clean, bright pour-overs',
  );

  static const chemex = Vessel(
    name: 'Chemex',
    category: 'coffee',
    defaultRatio: 15,
    defaultDurationSeconds: 240, // 4:00
    description: 'Elegant carafe with thick filters for a smooth cup',
  );

  static const aeroPress = Vessel(
    name: 'AeroPress',
    category: 'coffee',
    defaultRatio: 12,
    defaultDurationSeconds: 120, // 2:00
    description: 'Versatile pressure brewer for rich, concentrated coffee',
  );

  static const frenchPress = Vessel(
    name: 'French Press',
    category: 'coffee',
    defaultRatio: 15,
    defaultDurationSeconds: 240, // 4:00
    description: 'Full immersion brewing for bold, full-bodied coffee',
  );

  static const moka = Vessel(
    name: 'Moka Pot',
    category: 'coffee',
    defaultRatio: 10,
    defaultDurationSeconds: 300, // 5:00
    description: 'Stovetop espresso-style brewing',
  );

  static const kalitaWave = Vessel(
    name: 'Kalita Wave',
    category: 'coffee',
    defaultRatio: 16,
    defaultDurationSeconds: 210, // 3:30
    description: 'Flat-bottom dripper for consistent extraction',
  );

  // Tea vessels
  static const gaiwan = Vessel(
    name: 'Gaiwan',
    category: 'tea',
    defaultRatio: 5,
    defaultDurationSeconds: 30, // 0:30
    description: 'Traditional lidded bowl for gongfu brewing',
  );

  static const kyusu = Vessel(
    name: 'Kyusu',
    category: 'tea',
    defaultRatio: 10,
    defaultDurationSeconds: 60, // 1:00
    description: 'Japanese side-handle teapot for sencha',
  );

  static const westernTeapot = Vessel(
    name: 'Western Teapot',
    category: 'tea',
    defaultRatio: 50,
    defaultDurationSeconds: 180, // 3:00
    description: 'Classic teapot for everyday brewing',
  );

  static const grandpaStyle = Vessel(
    name: 'Grandpa Style',
    category: 'tea',
    defaultRatio: 20,
    defaultDurationSeconds: 0, // Variable
    description: 'Leaves in cup, sip and refill continuously',
  );

  static const yixing = Vessel(
    name: 'Yixing',
    category: 'tea',
    defaultRatio: 6,
    defaultDurationSeconds: 20, // 0:20
    description: 'Unglazed clay pot that seasons over time',
  );

  static const tetsubin = Vessel(
    name: 'Tetsubin',
    category: 'tea',
    defaultRatio: 30,
    defaultDurationSeconds: 240, // 4:00
    description: 'Cast iron pot for robust teas',
  );

  /// All vessels
  static List<Vessel> get all => [
        harioV60,
        chemex,
        aeroPress,
        frenchPress,
        moka,
        kalitaWave,
        gaiwan,
        kyusu,
        westernTeapot,
        grandpaStyle,
        yixing,
        tetsubin,
      ];

  /// Get coffee vessels
  static List<Vessel> get coffeeVessels =>
      all.where((v) => v.category == 'coffee').toList();

  /// Get tea vessels
  static List<Vessel> get teaVessels =>
      all.where((v) => v.category == 'tea').toList();

  /// Find vessel by name
  static Vessel? findByName(String name) {
    try {
      return all.firstWhere(
        (v) => v.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
