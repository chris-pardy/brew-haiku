import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Exception thrown during timer save operations
class TimerSaveException implements Exception {
  final String message;
  final int? statusCode;

  const TimerSaveException(this.message, {this.statusCode});

  @override
  String toString() => 'TimerSaveException: $message';
}

/// Result of saving a timer
class SaveTimerResult {
  final String uri;
  final String cid;

  const SaveTimerResult({
    required this.uri,
    required this.cid,
  });
}

/// Service for saving/unsaving timers to user's collection
class TimerSaveService {
  final http.Client _httpClient;

  TimerSaveService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Extract rkey from an AT URI
  ///
  /// Example: at://did:plc:abc123/app.brew-haiku.timer/3jk5xyz → 3jk5xyz
  String _extractRkey(String uri) {
    final parts = uri.split('/');
    if (parts.length < 5) {
      throw const TimerSaveException('Invalid timer URI');
    }
    return parts.last;
  }

  /// Save a timer to the user's collection
  ///
  /// Creates an app.brew-haiku.savedTimer record on the user's PDS
  /// with rkey derived from the timer URI.
  Future<SaveTimerResult> saveTimer({
    required StoredSession session,
    required String timerUri,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';
    final rkey = _extractRkey(timerUri);

    // Create the savedTimer record
    final record = {
      '\$type': 'app.brew-haiku.savedTimer',
      'timer': timerUri,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _httpClient.post(
      Uri.parse('$pdsUrl/xrpc/com.atproto.repo.createRecord'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: json.encode({
        'repo': session.did,
        'collection': 'app.brew-haiku.savedTimer',
        'rkey': rkey,
        'record': record,
      }),
    );

    if (response.statusCode == 401) {
      throw const TimerSaveException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      final body = response.body;
      String message = 'Failed to save timer';

      try {
        final data = json.decode(body) as Map<String, dynamic>;
        message = data['message'] as String? ?? message;
      } catch (_) {}

      throw TimerSaveException(
        message,
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    final uri = data['uri'] as String?;
    final cid = data['cid'] as String?;

    if (uri == null || cid == null) {
      throw const TimerSaveException('Invalid response from server');
    }

    return SaveTimerResult(uri: uri, cid: cid);
  }

  /// Remove a timer from the user's collection
  ///
  /// Deletes the app.brew-haiku.savedTimer record from the user's PDS.
  Future<void> unsaveTimer({
    required StoredSession session,
    required String timerUri,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';
    final rkey = _extractRkey(timerUri);

    final response = await _httpClient.post(
      Uri.parse('$pdsUrl/xrpc/com.atproto.repo.deleteRecord'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: json.encode({
        'repo': session.did,
        'collection': 'app.brew-haiku.savedTimer',
        'rkey': rkey,
      }),
    );

    if (response.statusCode == 401) {
      throw const TimerSaveException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      throw TimerSaveException(
        'Failed to remove timer',
        statusCode: response.statusCode,
      );
    }
  }

  /// Check if a timer is saved by checking for the savedTimer record
  Future<bool> isTimerSaved({
    required StoredSession session,
    required String timerUri,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';
    final rkey = _extractRkey(timerUri);

    final uri = Uri.parse('$pdsUrl/xrpc/com.atproto.repo.getRecord').replace(
      queryParameters: {
        'repo': session.did,
        'collection': 'app.brew-haiku.savedTimer',
        'rkey': rkey,
      },
    );

    final response = await _httpClient.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );

    // 200 means record exists, 400/404 means not found
    return response.statusCode == 200;
  }

  /// Get all saved timers for the user
  Future<List<String>> getSavedTimerUris({
    required StoredSession session,
    int limit = 100,
    String? cursor,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';

    final queryParams = {
      'repo': session.did,
      'collection': 'app.brew-haiku.savedTimer',
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final uri = Uri.parse('$pdsUrl/xrpc/com.atproto.repo.listRecords').replace(
      queryParameters: queryParams,
    );

    final response = await _httpClient.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );

    if (response.statusCode != 200) {
      throw TimerSaveException(
        'Failed to fetch saved timers',
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final records = data['records'] as List<dynamic>? ?? [];

    return records.map((record) {
      final value = record['value'] as Map<String, dynamic>;
      return value['timer'] as String;
    }).toList();
  }

  void dispose() {
    _httpClient.close();
  }
}
