/// Model representing a brew timer
class TimerModel {
  final String uri;
  final String did;
  final String? handle;
  final String name;
  final String vessel;
  final String brewType;
  final double? ratio;
  final List<TimerStepModel> steps;
  final int saveCount;
  final DateTime createdAt;

  const TimerModel({
    required this.uri,
    required this.did,
    this.handle,
    required this.name,
    required this.vessel,
    required this.brewType,
    this.ratio,
    required this.steps,
    required this.saveCount,
    required this.createdAt,
  });

  factory TimerModel.fromJson(Map<String, dynamic> json) {
    return TimerModel(
      uri: json['uri'] as String,
      did: json['did'] as String,
      handle: json['handle'] as String?,
      name: json['name'] as String,
      vessel: json['vessel'] as String,
      brewType: json['brewType'] as String,
      ratio: (json['ratio'] as num?)?.toDouble(),
      steps: (json['steps'] as List<dynamic>)
          .map((s) => TimerStepModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      saveCount: json['saveCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'did': did,
      'handle': handle,
      'name': name,
      'vessel': vessel,
      'brewType': brewType,
      'ratio': ratio,
      'steps': steps.map((s) => s.toJson()).toList(),
      'saveCount': saveCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Calculate total duration in seconds
  int get totalDurationSeconds {
    return steps
        .where((s) => s.stepType == 'timed' && s.durationSeconds != null)
        .fold(0, (sum, s) => sum + (s.durationSeconds ?? 0));
  }

  /// Format total duration as mm:ss
  String get formattedDuration {
    final total = totalDurationSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  TimerModel copyWith({
    String? uri,
    String? did,
    String? handle,
    String? name,
    String? vessel,
    String? brewType,
    double? ratio,
    List<TimerStepModel>? steps,
    int? saveCount,
    DateTime? createdAt,
  }) {
    return TimerModel(
      uri: uri ?? this.uri,
      did: did ?? this.did,
      handle: handle ?? this.handle,
      name: name ?? this.name,
      vessel: vessel ?? this.vessel,
      brewType: brewType ?? this.brewType,
      ratio: ratio ?? this.ratio,
      steps: steps ?? this.steps,
      saveCount: saveCount ?? this.saveCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Model representing a single step in a brew timer
class TimerStepModel {
  final String action;
  final String stepType; // 'timed' or 'indeterminate'
  final int? durationSeconds;

  const TimerStepModel({
    required this.action,
    required this.stepType,
    this.durationSeconds,
  });

  factory TimerStepModel.fromJson(Map<String, dynamic> json) {
    return TimerStepModel(
      action: json['action'] as String,
      stepType: json['stepType'] as String,
      durationSeconds: json['durationSeconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'stepType': stepType,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
  }

  bool get isTimed => stepType == 'timed';
  bool get isIndeterminate => stepType == 'indeterminate';

  /// Format duration as mm:ss
  String get formattedDuration {
    if (durationSeconds == null) return '--:--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  TimerStepModel copyWith({
    String? action,
    String? stepType,
    int? durationSeconds,
  }) {
    return TimerStepModel(
      action: action ?? this.action,
      stepType: stepType ?? this.stepType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
