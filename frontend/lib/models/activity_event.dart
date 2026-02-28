class ActivityEvent {
  final String eventType; // "brew" | "save" | "create"
  final String did;
  final String uri;
  final String timerUri;
  final String? postUri;
  final DateTime createdAt;

  // Hydrated fields (populated client-side)
  final String? handle;
  final String? timerName;

  const ActivityEvent({
    required this.eventType,
    required this.did,
    required this.uri,
    required this.timerUri,
    this.postUri,
    required this.createdAt,
    this.handle,
    this.timerName,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      eventType: json['eventType'] as String,
      did: json['did'] as String,
      uri: json['uri'] as String,
      timerUri: json['timerUri'] as String,
      postUri: json['postUri'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      handle: json['handle'] as String?,
      timerName: json['timerName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'did': did,
        'uri': uri,
        'timerUri': timerUri,
        if (postUri != null) 'postUri': postUri,
        'createdAt': createdAt.toIso8601String(),
        if (handle != null) 'handle': handle,
        if (timerName != null) 'timerName': timerName,
      };
}
