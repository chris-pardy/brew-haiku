class StepValue {
  final int stepIndex;
  final double value;

  const StepValue({required this.stepIndex, required this.value});

  factory StepValue.fromJson(Map<String, dynamic> json) {
    return StepValue(
      stepIndex: json['stepIndex'] as int,
      value: (json['value'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'stepIndex': stepIndex,
        'value': value,
      };
}

class Brew {
  final String? uri;
  final String? did;
  final String timerUri;
  final String? postUri;
  final List<StepValue>? stepValues;
  final DateTime createdAt;

  const Brew({
    this.uri,
    this.did,
    required this.timerUri,
    this.postUri,
    this.stepValues,
    required this.createdAt,
  });

  factory Brew.fromJson(Map<String, dynamic> json) {
    return Brew(
      uri: json['uri'] as String?,
      did: json['did'] as String?,
      timerUri: json['timerUri'] as String,
      postUri: json['postUri'] as String?,
      stepValues: (json['stepValues'] as List?)
          ?.map((v) => StepValue.fromJson(v as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        if (uri != null) 'uri': uri,
        if (did != null) 'did': did,
        'timerUri': timerUri,
        if (postUri != null) 'postUri': postUri,
        if (stepValues != null)
          'stepValues': stepValues!.map((v) => v.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  Brew copyWith({String? postUri}) {
    return Brew(
      uri: uri,
      did: did,
      timerUri: timerUri,
      postUri: postUri ?? this.postUri,
      stepValues: stepValues,
      createdAt: createdAt,
    );
  }
}
