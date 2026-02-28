class AuthSession {
  final String did;
  final String handle;
  final String accessToken;
  final String refreshToken;
  final int expiresAt;

  const AuthSession({
    required this.did,
    required this.handle,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAt;

  bool get needsRefresh =>
      DateTime.now().millisecondsSinceEpoch >= expiresAt - (5 * 60 * 1000);

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      did: json['did'] as String,
      handle: json['handle'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: json['expiresAt'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'did': did,
        'handle': handle,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt,
      };

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? expiresAt,
  }) {
    return AuthSession(
      did: did,
      handle: handle,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
