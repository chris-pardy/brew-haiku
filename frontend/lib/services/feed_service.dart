import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/haiku_post.dart';
import 'api_service.dart';

class FeedService {
  final ApiService _api;

  FeedService({required ApiService api}) : _api = api;

  /// Fetch feed skeleton from our backend, then hydrate via public Bluesky API.
  Future<({List<HaikuPost> posts, String? cursor})> getFeed({
    int limit = 25,
    String? cursor,
    String? type,
    bool auth = false,
  }) async {
    // 1. Get skeleton from our feed generator
    final params = <String, String>{
      'feed': 'at://did:web:feed.brew-haiku.app/app.bsky.feed.generator/haikus',
      'limit': '$limit',
    };
    if (cursor != null) params['cursor'] = cursor;
    if (type != null) params['type'] = type;

    debugPrint('[FeedService] Fetching skeleton with params: $params');

    final skeleton = await _api.get(
      '/xrpc/app.bsky.feed.getFeedSkeleton',
      queryParams: params,
      auth: auth,
    );

    final feedItems = skeleton['feed'] as List? ?? [];
    debugPrint('[FeedService] Skeleton returned ${feedItems.length} items, cursor: ${skeleton['cursor']}');

    if (feedItems.isEmpty) {
      return (posts: <HaikuPost>[], cursor: skeleton['cursor'] as String?);
    }

    // 2. Collect post URIs
    final uris = feedItems
        .map((item) => (item as Map<String, dynamic>)['post'] as String)
        .toList();
    debugPrint('[FeedService] URIs to hydrate: $uris');

    // 3. Hydrate via public Bluesky API (max 25 URIs per request)
    // Uses repeated `uris` query params: ?uris=at://...&uris=at://...
    final posts = <HaikuPost>[];
    for (var i = 0; i < uris.length; i += 25) {
      final batch = uris.sublist(i, i + 25 > uris.length ? uris.length : i + 25);

      try {
        final queryString = batch.map((u) => 'uris=${Uri.encodeComponent(u)}').join('&');
        final url = '${ApiService.bskyPublicApi}/xrpc/app.bsky.feed.getPosts?$queryString';
        debugPrint('[FeedService] Hydrating batch ${i ~/ 25 + 1}: $url');

        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        );

        debugPrint('[FeedService] Hydration response: ${response.statusCode}');

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final bskyPosts = body['posts'] as List? ?? [];
          debugPrint('[FeedService] Got ${bskyPosts.length} hydrated posts');
          for (final post in bskyPosts) {
            posts.add(HaikuPost.fromBskyPost(post as Map<String, dynamic>));
          }
        } else {
          debugPrint('[FeedService] Hydration failed: ${response.body}');
        }
      } catch (e) {
        debugPrint('[FeedService] Hydration error: $e');
      }
    }

    // Filter to only valid haiku (Latin, English, valid 5-7-5 split)
    final validPosts = posts.where((p) => p.isValidHaiku).toList();
    debugPrint('[FeedService] ${posts.length} hydrated → ${validPosts.length} valid haiku');
    return (posts: validPosts, cursor: skeleton['cursor'] as String?);
  }
}
