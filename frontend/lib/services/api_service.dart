import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for communicating with the Brew Haiku backend API
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Search for timers
  Future<Map<String, dynamic>> searchTimers({
    required String query,
    int? limit,
    int? offset,
    String? brewType,
    String? vessel,
  }) async {
    final queryParams = {
      'q': query,
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
      if (brewType != null) 'brew_type': brewType,
      if (vessel != null) 'vessel': vessel,
    };

    final uri = Uri.parse('$baseUrl/timers/search').replace(
      queryParameters: queryParams,
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to search timers',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Get a single timer by URI
  Future<Map<String, dynamic>> getTimer(String uri) async {
    final encodedUri = Uri.encodeComponent(uri);
    final response = await _client.get(
      Uri.parse('$baseUrl/timers/$encodedUri'),
    );

    if (response.statusCode == 404) {
      throw TimerNotFoundException(uri);
    }

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get timer',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// List timers
  Future<Map<String, dynamic>> listTimers({
    int? limit,
    int? offset,
    String? brewType,
    String? vessel,
  }) async {
    final queryParams = {
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
      if (brewType != null) 'brew_type': brewType,
      if (vessel != null) 'vessel': vessel,
    };

    final uri = Uri.parse('$baseUrl/timers').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to list timers',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// OAuth callback
  Future<Map<String, dynamic>> authCallback({
    required String code,
    String? state,
    String? iss,
  }) async {
    final body = {
      'code': code,
      if (state != null) 'state': state,
      if (iss != null) 'iss': iss,
    };

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/callback'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 401) {
      throw AuthException('Invalid authorization code');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Authentication failed',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Refresh auth token
  Future<Map<String, dynamic>> refreshAuth({
    required String refreshToken,
    required String did,
  }) async {
    final body = {
      'refreshToken': refreshToken,
      'did': did,
    };

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 401) {
      throw AuthException('Invalid refresh token');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Token refresh failed',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  void dispose() {
    _client.close();
  }
}

/// Base API exception
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Timer not found exception
class TimerNotFoundException implements Exception {
  final String uri;

  TimerNotFoundException(this.uri);

  @override
  String toString() => 'Timer not found: $uri';
}

/// Authentication exception
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
