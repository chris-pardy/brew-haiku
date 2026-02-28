import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_session.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;
  final FlutterSecureStorage _storage;

  static const _sessionKey = 'brew_haiku_session';
  static const _lastHandleKey = 'brew_haiku_last_handle';

  AuthService({required ApiService api, FlutterSecureStorage? storage})
      : _api = api,
        _storage = storage ?? const FlutterSecureStorage();

  /// Build the login URL. The gateway handles PAR + PKCE + redirect.
  /// The browser flow is: gateway /oauth/login → Bluesky → gateway /oauth/callback → deep link.
  String getLoginUrl(String handle) {
    return '${ApiService.baseUrl}/oauth/login?handle=${Uri.encodeComponent(handle)}';
  }

  /// Exchange OAuth authorization code for session tokens via our backend.
  Future<AuthSession> exchangeCode(String code, {String? state, String? iss}) async {
    final body = <String, dynamic>{
      'code': code,
      'redirect_uri': 'brew-haiku://oauth/callback',
    };
    if (state != null) body['state'] = state;
    if (iss != null) body['iss'] = iss;

    final result = await _api.post('/auth/callback', body: body);
    final session = AuthSession.fromJson(result);
    await saveSession(session);
    return session;
  }

  /// Refresh expired tokens.
  Future<AuthSession> refreshTokens(AuthSession session) async {
    final result = await _api.post('/auth/refresh', body: {
      'refreshToken': session.refreshToken,
      'did': session.did,
    });
    final refreshed = AuthSession.fromJson(result);
    await saveSession(refreshed);
    return refreshed;
  }

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
    await _storage.write(key: _lastHandleKey, value: session.handle);
  }

  Future<AuthSession?> loadSession() async {
    final data = await _storage.read(key: _sessionKey);
    if (data == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }

  Future<String?> getLastHandle() async {
    return _storage.read(key: _lastHandleKey);
  }
}
