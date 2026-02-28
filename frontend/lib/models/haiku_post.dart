import '../utils/syllable_counter.dart';

class HaikuPost {
  final String uri;
  final String did;
  final String cid;
  final String text;
  final String? authorHandle;
  final String? authorDisplayName;
  final int likeCount;
  final DateTime createdAt;
  final List<String>? _splitLines;

  HaikuPost({
    required this.uri,
    required this.did,
    required this.cid,
    required this.text,
    this.authorHandle,
    this.authorDisplayName,
    required this.likeCount,
    required this.createdAt,
  }) : _splitLines = splitHaikuLines(text);

  /// Whether this post has a valid 5-7-5 split.
  bool get isValidHaiku => _splitLines != null;

  /// The haiku split into 3 lines based on syllable counting.
  List<String> get haikuLines => _splitLines ?? [text];

  factory HaikuPost.fromBskyPost(Map<String, dynamic> post) {
    final record = post['record'] as Map<String, dynamic>? ?? {};
    final author = post['author'] as Map<String, dynamic>? ?? {};
    return HaikuPost(
      uri: post['uri'] as String,
      did: author['did'] as String? ?? '',
      cid: post['cid'] as String? ?? '',
      text: record['text'] as String? ?? '',
      authorHandle: author['handle'] as String?,
      authorDisplayName: author['displayName'] as String?,
      likeCount: post['likeCount'] as int? ?? 0,
      createdAt: record['createdAt'] != null
          ? DateTime.parse(record['createdAt'] as String)
          : DateTime.now(),
    );
  }

  factory HaikuPost.fromJson(Map<String, dynamic> json) {
    return HaikuPost(
      uri: json['uri'] as String,
      did: json['did'] as String,
      cid: json['cid'] as String? ?? '',
      text: json['text'] as String,
      authorHandle: json['authorHandle'] as String?,
      authorDisplayName: json['authorDisplayName'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'did': did,
        'cid': cid,
        'text': text,
        if (authorHandle != null) 'authorHandle': authorHandle,
        if (authorDisplayName != null) 'authorDisplayName': authorDisplayName,
        'likeCount': likeCount,
        'createdAt': createdAt.toIso8601String(),
      };
}
