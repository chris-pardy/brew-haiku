class TimerStep {
  final String action;
  final String stepType; // "timed" | "indeterminate"
  final int? durationSeconds;
  final String? unit;
  final double? ratioOfStep;

  const TimerStep({
    required this.action,
    required this.stepType,
    this.durationSeconds,
    this.unit,
    this.ratioOfStep,
  });

  bool get isTimed => stepType == 'timed';
  bool get isIndeterminate => stepType == 'indeterminate';

  factory TimerStep.fromJson(Map<String, dynamic> json) {
    return TimerStep(
      action: json['action'] as String,
      stepType: json['stepType'] as String,
      durationSeconds: json['durationSeconds'] as int?,
      unit: json['unit'] as String?,
      ratioOfStep: (json['ratioOfStep'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'stepType': stepType,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (unit != null) 'unit': unit,
      if (ratioOfStep != null) 'ratioOfStep': ratioOfStep,
    };
  }
}

class BrewTimer {
  final String uri;
  final String? cid;
  final String author;
  final String? handle;
  final String name;
  final String vessel;
  final String brewType;
  final double? ratio;
  final List<TimerStep> steps;
  final String? notes;
  final int saveCount;
  final DateTime createdAt;
  final bool? saved;

  const BrewTimer({
    required this.uri,
    this.cid,
    required this.author,
    this.handle,
    required this.name,
    required this.vessel,
    required this.brewType,
    this.ratio,
    required this.steps,
    this.notes,
    required this.saveCount,
    required this.createdAt,
    this.saved,
  });

  int get totalDurationSeconds => steps
      .where((s) => s.isTimed)
      .fold(0, (sum, s) => sum + (s.durationSeconds ?? 0));

  String get formattedDuration {
    final total = totalDurationSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    if (minutes == 0) return '${seconds}s';
    if (seconds == 0) return '${minutes}m';
    return '${minutes}m ${seconds}s';
  }

  factory BrewTimer.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'];
    final List<TimerStep> steps;
    if (stepsJson is List) {
      steps = stepsJson
          .map((s) => TimerStep.fromJson(s as Map<String, dynamic>))
          .toList();
    } else {
      steps = [];
    }

    return BrewTimer(
      uri: json['uri'] as String,
      cid: json['cid'] as String?,
      author: json['author'] as String? ?? json['did'] as String? ?? '',
      handle: json['handle'] as String?,
      name: json['name'] as String,
      vessel: json['vessel'] as String,
      brewType: json['brewType'] as String? ?? json['brew_type'] as String? ?? '',
      ratio: (json['ratio'] as num?)?.toDouble(),
      steps: steps,
      notes: json['notes'] as String?,
      saveCount: json['saveCount'] as int? ?? json['save_count'] as int? ?? 0,
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
      saved: json['saved'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      if (cid != null) 'cid': cid,
      'author': author,
      if (handle != null) 'handle': handle,
      'name': name,
      'vessel': vessel,
      'brewType': brewType,
      if (ratio != null) 'ratio': ratio,
      'steps': steps.map((s) => s.toJson()).toList(),
      if (notes != null) 'notes': notes,
      'saveCount': saveCount,
      'createdAt': createdAt.toIso8601String(),
      if (saved != null) 'saved': saved,
    };
  }

  BrewTimer copyWith({bool? saved, int? saveCount}) {
    return BrewTimer(
      uri: uri,
      cid: cid,
      author: author,
      handle: handle,
      name: name,
      vessel: vessel,
      brewType: brewType,
      ratio: ratio,
      steps: steps,
      notes: notes,
      saveCount: saveCount ?? this.saveCount,
      createdAt: createdAt,
      saved: saved ?? this.saved,
    );
  }
}
