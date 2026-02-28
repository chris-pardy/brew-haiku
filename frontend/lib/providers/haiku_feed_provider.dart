import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/haiku_post.dart';
import '../services/feed_service.dart';
import 'auth_provider.dart' show apiServiceProvider;
import 'connectivity_provider.dart';

class HaikuFeedState {
  final List<HaikuPost> posts;
  final bool loading;
  final String? cursor;
  final String? error;

  const HaikuFeedState({
    this.posts = const [],
    this.loading = false,
    this.cursor,
    this.error,
  });

  bool get hasMore => cursor != null;

  HaikuFeedState copyWith({
    List<HaikuPost>? posts,
    bool? loading,
    String? cursor,
    String? error,
  }) {
    return HaikuFeedState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      cursor: cursor,
      error: error,
    );
  }
}

class HaikuFeedNotifier extends StateNotifier<HaikuFeedState> {
  final FeedService _feedService;
  final Ref _ref;

  HaikuFeedNotifier({
    required FeedService feedService,
    required Ref ref,
  })  : _feedService = feedService,
        _ref = ref,
        super(const HaikuFeedState());

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<void> loadFeed({String? brewType}) async {
    debugPrint('[HaikuFeed] loadFeed called, isOnline=$_isOnline, brewType=$brewType');
    if (!_isOnline) {
      debugPrint('[HaikuFeed] Skipping — offline');
      return;
    }

    state = state.copyWith(loading: true);
    try {
      final result = await _feedService.getFeed(
        type: brewType,
        auth: false,
      );
      debugPrint('[HaikuFeed] Got ${result.posts.length} posts, cursor=${result.cursor}');
      state = state.copyWith(
        posts: result.posts,
        cursor: result.cursor,
        loading: false,
      );
    } catch (e) {
      debugPrint('[HaikuFeed] Error: $e');
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading || !_isOnline) return;

    state = state.copyWith(loading: true);
    try {
      final result = await _feedService.getFeed(
        cursor: state.cursor,
        auth: false,
      );
      state = state.copyWith(
        posts: [...state.posts, ...result.posts],
        cursor: result.cursor,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService(api: ref.read(apiServiceProvider));
});

final haikuFeedProvider =
    StateNotifierProvider<HaikuFeedNotifier, HaikuFeedState>((ref) {
  return HaikuFeedNotifier(
    feedService: ref.read(feedServiceProvider),
    ref: ref,
  );
});
