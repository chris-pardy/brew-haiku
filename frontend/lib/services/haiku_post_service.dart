import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Exception thrown during haiku posting
class HaikuPostException implements Exception {
  final String message;
  final int? statusCode;

  const HaikuPostException(this.message, {this.statusCode});

  @override
  String toString() => 'HaikuPostException: $message';
}

/// Result of posting a haiku
class HaikuPostResult {
  final String uri;
  final String cid;

  const HaikuPostResult({
    required this.uri,
    required this.cid,
  });
}

/// App signature appended to haiku posts
const String haikuSignature = 'via @brew-haiku.app';

/// Service for posting haiku to Bluesky
class HaikuPostService {
  final http.Client _httpClient;

  HaikuPostService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Post a haiku to Bluesky
  ///
  /// Creates an app.bsky.feed.post record on the user's PDS
  /// with the haiku text and the brew-haiku.app signature.
  Future<HaikuPostResult> postHaiku({
    required StoredSession session,
    required String haiku,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';

    // Format the post text with signature
    final postText = '$haiku\n\n$haikuSignature';

    // Create the post record
    final record = {
      '\$type': 'app.bsky.feed.post',
      'text': postText,
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
        'collection': 'app.bsky.feed.post',
        'record': record,
      }),
    );

    if (response.statusCode == 401) {
      throw const HaikuPostException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      final body = response.body;
      String message = 'Failed to post haiku';

      try {
        final data = json.decode(body) as Map<String, dynamic>;
        message = data['message'] as String? ?? message;
      } catch (_) {}

      throw HaikuPostException(
        message,
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    final uri = data['uri'] as String?;
    final cid = data['cid'] as String?;

    if (uri == null || cid == null) {
      throw const HaikuPostException('Invalid response from server');
    }

    return HaikuPostResult(uri: uri, cid: cid);
  }

  /// Delete a haiku post
  Future<void> deleteHaiku({
    required StoredSession session,
    required String uri,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';

    // Parse the URI to get the rkey
    // Format: at://did/collection/rkey
    final parts = uri.split('/');
    if (parts.length < 5) {
      throw const HaikuPostException('Invalid post URI');
    }
    final rkey = parts.last;

    final response = await _httpClient.post(
      Uri.parse('$pdsUrl/xrpc/com.atproto.repo.deleteRecord'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: json.encode({
        'repo': session.did,
        'collection': 'app.bsky.feed.post',
        'rkey': rkey,
      }),
    );

    if (response.statusCode == 401) {
      throw const HaikuPostException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      throw HaikuPostException(
        'Failed to delete haiku',
        statusCode: response.statusCode,
      );
    }
  }

  /// Format a haiku with the app signature
  String formatHaikuWithSignature(String haiku) {
    return '$haiku\n\n$haikuSignature';
  }

  void dispose() {
    _httpClient.close();
  }
}
