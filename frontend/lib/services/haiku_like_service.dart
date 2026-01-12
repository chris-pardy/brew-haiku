import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Exception thrown during like operations
class HaikuLikeException implements Exception {
  final String message;
  final int? statusCode;

  const HaikuLikeException(this.message, {this.statusCode});

  @override
  String toString() => 'HaikuLikeException: $message';
}

/// Result of liking a haiku
class LikeResult {
  final String uri;
  final String cid;

  const LikeResult({
    required this.uri,
    required this.cid,
  });
}

/// Service for liking/unliking haikus on Bluesky
class HaikuLikeService {
  final http.Client _httpClient;

  HaikuLikeService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Like a haiku post
  ///
  /// Creates an app.bsky.feed.like record on the user's PDS
  /// pointing to the target post.
  Future<LikeResult> likePost({
    required StoredSession session,
    required String postUri,
    required String postCid,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';

    // Create the like record
    final record = {
      '\$type': 'app.bsky.feed.like',
      'subject': {
        'uri': postUri,
        'cid': postCid,
      },
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
        'collection': 'app.bsky.feed.like',
        'record': record,
      }),
    );

    if (response.statusCode == 401) {
      throw const HaikuLikeException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      final body = response.body;
      String message = 'Failed to like post';

      try {
        final data = json.decode(body) as Map<String, dynamic>;
        message = data['message'] as String? ?? message;
      } catch (_) {}

      throw HaikuLikeException(
        message,
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;

    final uri = data['uri'] as String?;
    final cid = data['cid'] as String?;

    if (uri == null || cid == null) {
      throw const HaikuLikeException('Invalid response from server');
    }

    return LikeResult(uri: uri, cid: cid);
  }

  /// Unlike a haiku post
  ///
  /// Deletes the app.bsky.feed.like record from the user's PDS.
  Future<void> unlikePost({
    required StoredSession session,
    required String likeUri,
  }) async {
    final pdsUrl = session.pdsUrl ?? 'https://bsky.social';

    // Parse the URI to get the rkey
    // Format: at://did/collection/rkey
    final parts = likeUri.split('/');
    if (parts.length < 5) {
      throw const HaikuLikeException('Invalid like URI');
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
        'collection': 'app.bsky.feed.like',
        'rkey': rkey,
      }),
    );

    if (response.statusCode == 401) {
      throw const HaikuLikeException(
        'Authentication expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 200) {
      throw HaikuLikeException(
        'Failed to unlike post',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
