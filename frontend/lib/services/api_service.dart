import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_session.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthRequiredException implements Exception {
  const AuthRequiredException();
  @override
  String toString() => 'Authentication required';
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Not found']);
  @override
  String toString() => 'NotFoundException: $message';
}

class ApiService {
  static const baseUrl = 'https://api.brew-haiku.app';
  static const bskyPublicApi = 'https://public.api.bsky.app';

  AuthSession? _session;
  Future<AuthSession?> Function()? onRefreshNeeded;

  ApiService({
    AuthSession? session,
    this.onRefreshNeeded,
  })  : _session = session;

  void updateSession(AuthSession? session) {
    _session = session;
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth && _session != null) {
      headers['Authorization'] = 'Bearer ${_session!.accessToken}';
    }
    return headers;
  }

  Future<void> _ensureAuth() async {
    if (_session == null) throw const AuthRequiredException();
    if (_session!.needsRefresh && onRefreshNeeded != null) {
      final refreshed = await onRefreshNeeded!();
      if (refreshed != null) _session = refreshed;
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    bool auth = false,
    String? baseUrlOverride,
  }) async {
    if (auth) await _ensureAuth();

    final base = baseUrlOverride ?? baseUrl;
    var uri = Uri.parse('$base$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    var response = await http.get(uri, headers: _headers(auth: auth));

    // Retry once on 401 after token refresh
    if (response.statusCode == 401 && auth && onRefreshNeeded != null) {
      final refreshed = await onRefreshNeeded!();
      if (refreshed != null) {
        _session = refreshed;
        response = await http.get(uri, headers: _headers(auth: true));
      }
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    if (auth) await _ensureAuth();

    final uri = Uri.parse('$baseUrl$path');
    var response = await http.post(
      uri,
      headers: _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );

    // Retry once on 401 after token refresh
    if (response.statusCode == 401 && auth && onRefreshNeeded != null) {
      final refreshed = await onRefreshNeeded!();
      if (refreshed != null) {
        _session = refreshed;
        response = await http.post(
          uri,
          headers: _headers(auth: true),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 404) {
      throw const NotFoundException();
    }
    if (response.statusCode == 401) {
      throw const AuthRequiredException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message'] as String? ?? response.body;
      } catch (_) {
        message = response.body;
      }
      throw ApiException(response.statusCode, message);
    }

    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
