import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'timer_save_service.dart';
import '../models/timer_model.dart';

/// Exception thrown during timer creation
class TimerCreateException implements Exception {
  final String message;
  final int? statusCode;

  const TimerCreateException(this.message, {this.statusCode});

  @override
  String toString() => 'TimerCreateException: $message';
}

/// Result of creating a timer
class CreateTimerResult {
  final String timerUri;
  final String timerCid;
  final String savedTimerUri;
  final String savedTimerCid;

  const CreateTimerResult({
    required this.timerUri,
    required this.timerCid,
    required this.savedTimerUri,
    required this.savedTimerCid,
  });
}

/// Generate a TID (Timestamp ID) for the record key
/// Format: base32-sortable encoded timestamp + random suffix
String _generateTid() {
  final now = DateTime.now().microsecondsSinceEpoch;
  // Simple base32-like encoding for timestamp
  const chars = '234567abcdefghijklmnopqrstuvwxyz';
  var encoded = '';
  var n = now;
  while (n > 0) {
    encoded = chars[n % 32] + encoded;
    n = n ~/ 32;
  }
  // Pad to 13 characters
  while (encoded.length < 13) {
    encoded = '2' + encoded;
  }
  return encoded;
}

/// Service for creating and publishing timer recipes
class TimerCreateService {
  final http.Client _httpClient;
  final TimerSaveService _saveService;

  TimerCreateService({
    http.Client? httpClient,
    TimerSaveService? saveService,
  })  : _httpClient = httpClient ?? http.Client(),
        _saveService = saveService ?? TimerSaveService(httpClient: httpClient);

  /// Create and publish a timer recipe
  ///
  /// Creates both:
  /// 1. app.brew-haiku.timer record on user's PDS
  /// 2. app.brew-haiku.savedTimer record (auto-save to user's collection)
  Future<CreateTimerResult> createTimer({
    required StoredSession session,
    required String name,
    required String vessel,
    required String brewType,
    required List<TimerStepModel> steps,
    double? ratio,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';
    final tid = _generateTid();

    // Create the timer record
    final record = {
      '\$type': 'app.brew-haiku.timer',
      'name': name,
      'vessel': vessel,
      'brewType': brewType,
      'steps': steps.map((s) => s.toJson()).toList(),
      if (ratio != null) 'ratio': ratio,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _httpClient.post(
      Uri.parse('$pdsUrl/xrpc/com.atproto.repo.createRecord'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: json.encode({
        'repo': session.did,
        'collection': 'app.brew-haiku.timer',
        'rkey': tid,
        'record': record,
      }),
    );

    if (response.statusCode == 401) {
      throw const TimerCreateException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      final body = response.body;
      String message = 'Failed to create timer';

      try {
        final data = json.decode(body) as Map<String, dynamic>;
        message = data['message'] as String? ?? message;
      } catch (_) {}

      throw TimerCreateException(
        message,
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final timerUri = data['uri'] as String?;
    final timerCid = data['cid'] as String?;

    if (timerUri == null || timerCid == null) {
      throw const TimerCreateException('Invalid response from server');
    }

    // Auto-save the timer to user's collection
    final saveResult = await _saveService.saveTimer(
      session: session,
      timerUri: timerUri,
    );

    return CreateTimerResult(
      timerUri: timerUri,
      timerCid: timerCid,
      savedTimerUri: saveResult.uri,
      savedTimerCid: saveResult.cid,
    );
  }

  /// Delete a timer from user's PDS
  ///
  /// Note: This only deletes if user owns the timer.
  /// Also removes from saved collection.
  Future<void> deleteTimer({
    required StoredSession session,
    required String timerUri,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';

    // Extract rkey from URI
    final parts = timerUri.split('/');
    if (parts.length < 5) {
      throw const TimerCreateException('Invalid timer URI');
    }
    final rkey = parts.last;

    // First, unsave the timer
    try {
      await _saveService.unsaveTimer(session: session, timerUri: timerUri);
    } catch (_) {
      // Ignore if not saved
    }

    // Delete the timer record
    final response = await _httpClient.post(
      Uri.parse('$pdsUrl/xrpc/com.atproto.repo.deleteRecord'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: json.encode({
        'repo': session.did,
        'collection': 'app.brew-haiku.timer',
        'rkey': rkey,
      }),
    );

    if (response.statusCode == 401) {
      throw const TimerCreateException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      throw TimerCreateException(
        'Failed to delete timer',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
