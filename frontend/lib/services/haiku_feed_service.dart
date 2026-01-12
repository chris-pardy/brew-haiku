import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Exception thrown during feed operations
class HaikuFeedException implements Exception {
  final String message;
  final int? statusCode;

  const HaikuFeedException(this.message, {this.statusCode});

  @override
  String toString() => 'HaikuFeedException: $message';
}

/// A haiku post from the feed
class HaikuPost {
  final String uri;
  final String cid;
  final String authorDid;
  final String authorHandle;
  final String? authorDisplayName;
  final String? authorAvatar;
  final String text;
  final int likeCount;
  final DateTime createdAt;
  final bool isLikedByUser;
  final String? likeUri;

  const HaikuPost({
    required this.uri,
    required this.cid,
    required this.authorDid,
    required this.authorHandle,
    this.authorDisplayName,
    this.authorAvatar,
    required this.text,
    required this.likeCount,
    required this.createdAt,
    this.isLikedByUser = false,
    this.likeUri,
  });

  /// Extract just the haiku text (remove signature)
  String get haikuText {
    final lines = text.split('\n');
    // Remove the signature line(s)
    final filtered = lines.where((line) => !line.contains('via @brew-haiku.app')).toList();
    // Remove trailing empty lines
    while (filtered.isNotEmpty && filtered.last.trim().isEmpty) {
      filtered.removeLast();
    }
    return filtered.join('\n');
  }

  HaikuPost copyWith({
    String? uri,
    String? cid,
    String? authorDid,
    String? authorHandle,
    String? authorDisplayName,
    String? authorAvatar,
    String? text,
    int? likeCount,
    DateTime? createdAt,
    bool? isLikedByUser,
    String? likeUri,
    bool clearLikeUri = false,
  }) {
    return HaikuPost(
      uri: uri ?? this.uri,
      cid: cid ?? this.cid,
      authorDid: authorDid ?? this.authorDid,
      authorHandle: authorHandle ?? this.authorHandle,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      text: text ?? this.text,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt ?? this.createdAt,
      isLikedByUser: isLikedByUser ?? this.isLikedByUser,
      likeUri: clearLikeUri ? null : (likeUri ?? this.likeUri),
    );
  }
}

/// Result of fetching the feed
class HaikuFeedResult {
  final List<HaikuPost> posts;
  final String? cursor;

  const HaikuFeedResult({
    required this.posts,
    this.cursor,
  });
}

/// Feed URI for the Brew Haiku custom feed
const String brewHaikuFeedUri = 'at://did:web:brew-haiku.app/app.bsky.feed.generator/haikus';

/// Service for fetching the haiku feed from Bluesky
class HaikuFeedService {
  final http.Client _httpClient;
  final String _appViewUrl;

  HaikuFeedService({
    http.Client? httpClient,
    String appViewUrl = 'https://public.api.bsky.app',
  })  : _httpClient = httpClient ?? http.Client(),
        _appViewUrl = appViewUrl;

  /// Fetch the haiku feed
  Future<HaikuFeedResult> getFeed({
    StoredSession? session,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParams = {
      'feed': brewHaikuFeedUri,
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final uri = Uri.parse('$_appViewUrl/xrpc/app.bsky.feed.getFeed')
        .replace(queryParameters: queryParams);

    final headers = <String, String>{};
    if (session != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    final response = await _httpClient.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw HaikuFeedException(
        'Failed to fetch feed',
        statusCode: response.statusCode,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final feed = data['feed'] as List<dynamic>? ?? [];
    final newCursor = data['cursor'] as String?;

    final posts = feed.map((item) {
      final post = item['post'] as Map<String, dynamic>;
      final author = post['author'] as Map<String, dynamic>;
      final record = post['record'] as Map<String, dynamic>;
      final viewer = post['viewer'] as Map<String, dynamic>?;

      return HaikuPost(
        uri: post['uri'] as String,
        cid: post['cid'] as String,
        authorDid: author['did'] as String,
        authorHandle: author['handle'] as String,
        authorDisplayName: author['displayName'] as String?,
        authorAvatar: author['avatar'] as String?,
        text: record['text'] as String? ?? '',
        likeCount: post['likeCount'] as int? ?? 0,
        createdAt: DateTime.tryParse(record['createdAt'] as String? ?? '') ??
            DateTime.now(),
        isLikedByUser: viewer?['like'] != null,
        likeUri: viewer?['like'] as String?,
      );
    }).toList();

    return HaikuFeedResult(posts: posts, cursor: newCursor);
  }

  void dispose() {
    _httpClient.close();
  }
}
