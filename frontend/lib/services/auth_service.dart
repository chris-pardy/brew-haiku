import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';

/// Exception thrown during authentication operations
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Keys for secure storage
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String did = 'did';
  static const String handle = 'handle';
  static const String expiresAt = 'expires_at';
  static const String pdsUrl = 'pds_url';
}

/// Stored auth session data
class StoredSession {
  final String did;
  final String handle;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? pdsUrl;

  const StoredSession({
    required this.did,
    required this.handle,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.pdsUrl,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get needsRefresh {
    // Refresh if expires within 5 minutes
    final refreshThreshold = expiresAt.subtract(const Duration(minutes: 5));
    return DateTime.now().isAfter(refreshThreshold);
  }

  Map<String, String> toStorageMap() {
    return {
      StorageKeys.did: did,
      StorageKeys.handle: handle,
      StorageKeys.accessToken: accessToken,
      StorageKeys.refreshToken: refreshToken,
      StorageKeys.expiresAt: expiresAt.toIso8601String(),
      if (pdsUrl != null) StorageKeys.pdsUrl: pdsUrl!,
    };
  }

  static StoredSession? fromStorageMap(Map<String, String?> map) {
    final did = map[StorageKeys.did];
    final handle = map[StorageKeys.handle];
    final accessToken = map[StorageKeys.accessToken];
    final refreshToken = map[StorageKeys.refreshToken];
    final expiresAtStr = map[StorageKeys.expiresAt];

    if (did == null ||
        handle == null ||
        accessToken == null ||
        refreshToken == null ||
        expiresAtStr == null) {
      return null;
    }

    final expiresAt = DateTime.tryParse(expiresAtStr);
    if (expiresAt == null) return null;

    return StoredSession(
      did: did,
      handle: handle,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      pdsUrl: map[StorageKeys.pdsUrl],
    );
  }
}

/// Service for handling Bluesky OAuth authentication
class AuthService {
  final FlutterSecureStorage _storage;
  final http.Client _httpClient;
  final String _apiBaseUrl;
  final String _clientId;
  final String _redirectUri;

  AuthService({
    FlutterSecureStorage? storage,
    http.Client? httpClient,
    required String apiBaseUrl,
    required String clientId,
    required String redirectUri,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client(),
        _apiBaseUrl = apiBaseUrl,
        _clientId = clientId,
        _redirectUri = redirectUri;

  /// Resolve a Bluesky handle to get the PDS URL
  Future<String> resolvePdsUrl(String handle) async {
    final response = await _httpClient.get(
      Uri.parse('$_apiBaseUrl/resolve/$handle'),
    );

    if (response.statusCode != 200) {
      throw AuthException('Failed to resolve handle: $handle');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final pdsUrl = data['pds_url'] as String?;

    if (pdsUrl == null || pdsUrl.isEmpty) {
      throw AuthException('No PDS URL found for handle: $handle');
    }

    return pdsUrl;
  }

  /// Build the OAuth authorization URL for a given handle
  Future<Uri> buildAuthorizationUrl(String handle) async {
    final pdsUrl = await resolvePdsUrl(handle);

    // First, get the authorization server metadata from the PDS
    final metadataUrl = Uri.parse('$pdsUrl/.well-known/oauth-authorization-server');
    final metadataResponse = await _httpClient.get(metadataUrl);

    if (metadataResponse.statusCode != 200) {
      // Fallback to standard Bluesky authorization endpoint
      return _buildFallbackAuthUrl(handle);
    }

    final metadata = json.decode(metadataResponse.body) as Map<String, dynamic>;
    final authorizationEndpoint = metadata['authorization_endpoint'] as String?;

    if (authorizationEndpoint == null) {
      return _buildFallbackAuthUrl(handle);
    }

    return Uri.parse(authorizationEndpoint).replace(
      queryParameters: {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'scope': 'atproto transition:generic',
        'login_hint': handle,
      },
    );
  }

  Uri _buildFallbackAuthUrl(String handle) {
    return Uri.parse('https://bsky.social/oauth/authorize').replace(
      queryParameters: {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'scope': 'atproto transition:generic',
        'login_hint': handle,
      },
    );
  }

  /// Launch the OAuth flow in browser
  Future<void> launchOAuthFlow(String handle) async {
    final authUrl = await buildAuthorizationUrl(handle);

    if (!await canLaunchUrl(authUrl)) {
      throw AuthException('Cannot launch OAuth URL');
    }

    await launchUrl(
      authUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  /// Handle the OAuth callback with authorization code
  Future<StoredSession> handleCallback({
    required String code,
    String? state,
    String? iss,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$_apiBaseUrl/auth/callback'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'code': code,
        'redirect_uri': _redirectUri,
        if (state != null) 'state': state,
        if (iss != null) 'iss': iss,
      }),
    );

    if (response.statusCode == 401) {
      throw AuthException('Invalid authorization code');
    }

    if (response.statusCode != 200) {
      throw AuthException('Authentication failed: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    final session = _parseSessionFromResponse(data);
    await _saveSession(session);

    return session;
  }

  /// Refresh the access token using the refresh token
  Future<StoredSession> refreshSession(StoredSession currentSession) async {
    final response = await _httpClient.post(
      Uri.parse('$_apiBaseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'refreshToken': currentSession.refreshToken,
        'did': currentSession.did,
      }),
    );

    if (response.statusCode == 401) {
      // Refresh token is invalid, clear session
      await clearSession();
      throw AuthException('Session expired, please sign in again');
    }

    if (response.statusCode != 200) {
      throw AuthException('Token refresh failed: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    final newSession = _parseSessionFromResponse(data);
    await _saveSession(newSession);

    return newSession;
  }

  StoredSession _parseSessionFromResponse(Map<String, dynamic> data) {
    final accessToken = data['accessToken'] as String? ?? data['access_token'] as String?;
    final refreshToken = data['refreshToken'] as String? ?? data['refresh_token'] as String?;
    final did = data['did'] as String?;
    final handle = data['handle'] as String?;
    final expiresIn = data['expiresIn'] as int? ?? data['expires_in'] as int? ?? 3600;
    final pdsUrl = data['pds_url'] as String? ?? data['pdsUrl'] as String?;

    if (accessToken == null || refreshToken == null || did == null || handle == null) {
      throw AuthException('Invalid session response from server');
    }

    return StoredSession(
      did: did,
      handle: handle,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      pdsUrl: pdsUrl,
    );
  }

  /// Load session from secure storage
  Future<StoredSession?> loadSession() async {
    final values = await _storage.readAll();

    final session = StoredSession.fromStorageMap(values);

    if (session == null) return null;

    // If session is expired beyond refresh capability, clear it
    if (session.isExpired) {
      // Try to refresh if we have a refresh token
      // For now, just return the session and let the caller handle refresh
    }

    return session;
  }

  /// Save session to secure storage
  Future<void> _saveSession(StoredSession session) async {
    final storageMap = session.toStorageMap();

    for (final entry in storageMap.entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }

  /// Clear session from secure storage
  Future<void> clearSession() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
    await _storage.delete(key: StorageKeys.did);
    await _storage.delete(key: StorageKeys.handle);
    await _storage.delete(key: StorageKeys.expiresAt);
    await _storage.delete(key: StorageKeys.pdsUrl);
  }

  void dispose() {
    _httpClient.close();
  }
}
