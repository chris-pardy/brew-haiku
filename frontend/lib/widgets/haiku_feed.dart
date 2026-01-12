import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/haiku_feed_service.dart';
import '../services/haiku_like_service.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Provider for the haiku feed service
final haikuFeedServiceProvider = Provider<HaikuFeedService>((ref) {
  return HaikuFeedService();
});

/// Provider for the haiku like service
final haikuLikeServiceProvider = Provider<HaikuLikeService>((ref) {
  return HaikuLikeService();
});

/// Provider for cached haiku posts
final haikuCacheProvider = StateNotifierProvider<HaikuCacheNotifier, HaikuCacheState>((ref) {
  return HaikuCacheNotifier(ref);
});

/// State for the haiku cache
class HaikuCacheState {
  final List<HaikuPost> posts;
  final String? cursor;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;

  const HaikuCacheState({
    this.posts = const [],
    this.cursor,
    this.isLoading = false,
    this.error,
    this.lastFetched,
  });

  bool get isEmpty => posts.isEmpty;
  bool get hasMore => cursor != null;

  /// Check if cache is stale (older than 5 minutes)
  bool get isStale {
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched!) > const Duration(minutes: 5);
  }

  HaikuCacheState copyWith({
    List<HaikuPost>? posts,
    String? cursor,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
    bool clearCursor = false,
    bool clearError = false,
  }) {
    return HaikuCacheState(
      posts: posts ?? this.posts,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

/// Notifier for haiku cache
class HaikuCacheNotifier extends StateNotifier<HaikuCacheState> {
  final Ref _ref;

  HaikuCacheNotifier(this._ref) : super(const HaikuCacheState());

  /// Fetch the feed (refresh or load more)
  Future<void> fetchFeed({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = _ref.read(haikuFeedServiceProvider);
      final authState = _ref.read(authStateProvider);
      final session = authState.session;

      final result = await service.getFeed(
        session: session,
        cursor: refresh ? null : state.cursor,
      );

      if (refresh) {
        state = state.copyWith(
          posts: result.posts,
          cursor: result.cursor,
          isLoading: false,
          lastFetched: DateTime.now(),
          clearCursor: result.cursor == null,
        );
      } else {
        state = state.copyWith(
          posts: [...state.posts, ...result.posts],
          cursor: result.cursor,
          isLoading: false,
          lastFetched: DateTime.now(),
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh the feed
  Future<void> refresh() => fetchFeed(refresh: true);

  /// Load more posts
  Future<void> loadMore() {
    if (!state.hasMore) return Future.value();
    return fetchFeed(refresh: false);
  }

  /// Update like status for a post (used for optimistic updates)
  void updateLikeStatus(String uri, bool isLiked, int likeCount, {String? likeUri}) {
    final updatedPosts = state.posts.map((post) {
      if (post.uri == uri) {
        return post.copyWith(
          isLikedByUser: isLiked,
          likeCount: likeCount,
          likeUri: likeUri,
          clearLikeUri: !isLiked,
        );
      }
      return post;
    }).toList();

    state = state.copyWith(posts: updatedPosts);
  }

  /// Toggle like on a post with optimistic UI update
  /// Returns true if the action was successful
  Future<bool> toggleLike(HaikuPost post) async {
    final authState = _ref.read(authStateProvider);
    final session = authState.session;

    if (session == null) {
      // User not logged in, can't like
      return false;
    }

    final likeService = _ref.read(haikuLikeServiceProvider);
    final wasLiked = post.isLikedByUser;
    final oldLikeCount = post.likeCount;
    final oldLikeUri = post.likeUri;

    // Optimistic update
    updateLikeStatus(
      post.uri,
      !wasLiked,
      wasLiked ? oldLikeCount - 1 : oldLikeCount + 1,
    );

    try {
      if (wasLiked && oldLikeUri != null) {
        // Unlike
        await likeService.unlikePost(
          session: session,
          likeUri: oldLikeUri,
        );
      } else if (!wasLiked) {
        // Like
        final result = await likeService.likePost(
          session: session,
          postUri: post.uri,
          postCid: post.cid,
        );
        // Update with the real like URI
        updateLikeStatus(post.uri, true, oldLikeCount + 1, likeUri: result.uri);
      }
      return true;
    } catch (e) {
      // Revert optimistic update on failure
      updateLikeStatus(post.uri, wasLiked, oldLikeCount, likeUri: oldLikeUri);
      return false;
    }
  }

  /// Clear the cache
  void clear() {
    state = const HaikuCacheState();
  }
}

/// Haiku feed carousel widget
class HaikuFeedCarousel extends ConsumerStatefulWidget {
  /// Transition duration for page changes
  final Duration transitionDuration;

  /// Whether to auto-scroll
  final bool autoScroll;

  /// Auto-scroll interval
  final Duration autoScrollInterval;

  /// Called when a haiku is liked
  final void Function(HaikuPost post)? onLike;

  const HaikuFeedCarousel({
    super.key,
    this.transitionDuration = const Duration(milliseconds: 500),
    this.autoScroll = false,
    this.autoScrollInterval = const Duration(seconds: 10),
    this.onLike,
  });

  @override
  ConsumerState<HaikuFeedCarousel> createState() => _HaikuFeedCarouselState();
}

class _HaikuFeedCarouselState extends ConsumerState<HaikuFeedCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Fetch feed if empty or stale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cache = ref.read(haikuCacheProvider);
      if (cache.isEmpty || cache.isStale) {
        ref.read(haikuCacheProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(haikuCacheProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cache.isLoading && cache.isEmpty) {
      return _LoadingState(isDark: isDark);
    }

    if (cache.error != null && cache.isEmpty) {
      return _ErrorState(
        error: cache.error!,
        onRetry: () => ref.read(haikuCacheProvider.notifier).refresh(),
        isDark: isDark,
      );
    }

    if (cache.isEmpty) {
      return _EmptyState(isDark: isDark);
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: cache.posts.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);

              // Load more when near the end
              if (index >= cache.posts.length - 3 && cache.hasMore) {
                ref.read(haikuCacheProvider.notifier).loadMore();
              }
            },
            itemBuilder: (context, index) {
              return AnimatedSwitcher(
                duration: widget.transitionDuration,
                child: HaikuCard(
                  key: ValueKey(cache.posts[index].uri),
                  post: cache.posts[index],
                  onLike: widget.onLike,
                ),
              );
            },
          ),
        ),

        // Page indicator
        if (cache.posts.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _PageIndicator(
              count: cache.posts.length,
              current: _currentPage,
              isDark: isDark,
            ),
          ),
      ],
    );
  }
}

/// Individual haiku card
class HaikuCard extends ConsumerWidget {
  final HaikuPost post;
  final void Function(HaikuPost post)? onLike;

  const HaikuCard({
    super.key,
    required this.post,
    this.onLike,
  });

  Future<void> _handleLikeTap(WidgetRef ref) async {
    // Haptic feedback on tap
    HapticFeedback.lightImpact();

    // Toggle like with optimistic UI
    final success = await ref.read(haikuCacheProvider.notifier).toggleLike(post);

    if (success) {
      // Call the onLike callback if provided
      onLike?.call(post);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor = isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor = isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    final haikuLines = post.haikuText.split('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Haiku text
          for (final line in haikuLines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                line,
                style: textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Playfair Display',
                  fontStyle: FontStyle.italic,
                  color: textColor,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 24),

          // Author info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (post.authorAvatar != null) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(post.authorAvatar!),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                post.authorDisplayName ?? '@${post.authorHandle}',
                style: textTheme.bodySmall?.copyWith(color: secondaryColor),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Like button with haptic feedback
          GestureDetector(
            onTap: () => _handleLikeTap(ref),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    post.isLikedByUser ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(post.isLikedByUser),
                    size: 20,
                    color: post.isLikedByUser ? Colors.red : secondaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: textTheme.bodySmall?.copyWith(color: secondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page indicator dots
class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;
  final bool isDark;

  const _PageIndicator({
    required this.count,
    required this.current,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final inactiveColor = isDark ? BrewColors.mistDark : BrewColors.mistLight;

    // Limit displayed dots
    final maxDots = 5;
    final displayCount = count > maxDots ? maxDots : count;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(displayCount, (index) {
        final isActive = index == (current % displayCount);
        return Container(
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }
}

/// Loading state
class _LoadingState extends StatelessWidget {
  final bool isDark;

  const _LoadingState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading haikus...',
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

/// Error state
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final bool isDark;

  const _ErrorState({
    required this.error,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: textColor),
          const SizedBox(height: 16),
          Text(
            'Could not load haikus',
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text('Try Again', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }
}

/// Empty state
class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa_outlined, size: 48, color: textColor),
          const SizedBox(height: 16),
          Text(
            'No haikus yet',
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share one',
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
