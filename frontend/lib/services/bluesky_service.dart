import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_session.dart';

class BlueskyService {
  static const _haikuSignature = 'via @brew-haiku.app';

  /// Post a haiku to the user's Bluesky PDS.
  /// Returns the URI of the created post.
  Future<String> postHaiku({
    required List<String> lines,
    required AuthSession session,
    required String pdsUrl,
  }) async {
    final text = '${lines.join('\n')}\n\n$_haikuSignature';
    final now = DateTime.now().toUtc().toIso8601String();

    final body = {
      'repo': session.did,
      'collection': 'app.bsky.feed.post',
      'record': {
        '\$type': 'app.bsky.feed.post',
        'text': text,
        'createdAt': now,
      },
    };

    final uri = Uri.parse('$pdsUrl/xrpc/com.atproto.repo.createRecord');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to post haiku: ${response.body}');
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return result['uri'] as String;
  }

  /// Resolve a DID to get PDS URL.
  Future<String> getPdsUrl(String did) async {
    final uri = Uri.parse('https://plc.directory/$did');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to resolve DID: $did');
    }
    final doc = jsonDecode(response.body) as Map<String, dynamic>;
    final services = doc['service'] as List? ?? [];
    for (final service in services) {
      final s = service as Map<String, dynamic>;
      if (s['id'] == '#atproto_pds') {
        return s['serviceEndpoint'] as String;
      }
    }
    throw Exception('No PDS found for DID: $did');
  }
}
