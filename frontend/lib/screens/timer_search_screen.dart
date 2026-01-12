import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timer_model.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Provider for the API service
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(baseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://brew-haiku.app',
  ));
});

/// State for timer search
class TimerSearchState {
  final String query;
  final String? brewType;
  final String? vessel;
  final List<TimerModel> results;
  final bool isLoading;
  final String? error;
  final bool hasSearched;

  const TimerSearchState({
    this.query = '',
    this.brewType,
    this.vessel,
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.hasSearched = false,
  });

  TimerSearchState copyWith({
    String? query,
    String? brewType,
    String? vessel,
    List<TimerModel>? results,
    bool? isLoading,
    String? error,
    bool? hasSearched,
    bool clearBrewType = false,
    bool clearVessel = false,
    bool clearError = false,
  }) {
    return TimerSearchState(
      query: query ?? this.query,
      brewType: clearBrewType ? null : (brewType ?? this.brewType),
      vessel: clearVessel ? null : (vessel ?? this.vessel),
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

/// Notifier for timer search state
class TimerSearchNotifier extends StateNotifier<TimerSearchState> {
  final Ref _ref;

  TimerSearchNotifier(this._ref) : super(const TimerSearchState());

  /// Update search query
  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  /// Set brew type filter
  void setBrewType(String? brewType) {
    state = state.copyWith(
      brewType: brewType,
      clearBrewType: brewType == null,
    );
  }

  /// Set vessel filter
  void setVessel(String? vessel) {
    state = state.copyWith(
      vessel: vessel,
      clearVessel: vessel == null,
    );
  }

  /// Perform search
  Future<void> search() async {
    if (state.query.isEmpty && state.brewType == null && state.vessel == null) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, hasSearched: true);

    try {
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.searchTimers(
        query: state.query.isNotEmpty ? state.query : '*',
        brewType: state.brewType,
        vessel: state.vessel,
        limit: 50,
      );

      final timers = (response['timers'] as List<dynamic>? ?? [])
          .map((t) => TimerModel.fromJson(t as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        results: timers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear search and results
  void clear() {
    state = const TimerSearchState();
  }
}

/// Provider for timer search
final timerSearchProvider =
    StateNotifierProvider<TimerSearchNotifier, TimerSearchState>((ref) {
  return TimerSearchNotifier(ref);
});

/// Common vessels for filtering
const List<String> commonVessels = [
  'V60',
  'Chemex',
  'AeroPress',
  'French Press',
  'Moka Pot',
  'Gaiwan',
  'Kyusu',
  'Teapot',
];

/// Screen for searching timer recipes
class TimerSearchScreen extends ConsumerStatefulWidget {
  /// Callback when a timer is selected
  final void Function(TimerModel timer)? onTimerSelected;

  const TimerSearchScreen({
    super.key,
    this.onTimerSelected,
  });

  @override
  ConsumerState<TimerSearchScreen> createState() => _TimerSearchScreenState();
}

class _TimerSearchScreenState extends ConsumerState<TimerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(timerSearchProvider.notifier).setQuery(_searchController.text);
  }

  void _performSearch() {
    _searchFocusNode.unfocus();
    ref.read(timerSearchProvider.notifier).search();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(timerSearchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final surfaceColor =
        isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Search Timers',
          style: textTheme.titleLarge?.copyWith(color: textColor),
        ),
      ),
      body: Column(
        children: [
          // Search input and filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search text field
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search recipes...',
                    hintStyle: TextStyle(color: secondaryColor),
                    prefixIcon: Icon(Icons.search, color: secondaryColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: secondaryColor),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(timerSearchProvider.notifier).clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(color: textColor),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 12),

                // Filter row
                Row(
                  children: [
                    // Brew type filter
                    Expanded(
                      child: _FilterDropdown(
                        label: 'Type',
                        value: searchState.brewType,
                        items: const ['coffee', 'tea'],
                        onChanged: (value) {
                          ref
                              .read(timerSearchProvider.notifier)
                              .setBrewType(value);
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Vessel filter
                    Expanded(
                      child: _FilterDropdown(
                        label: 'Vessel',
                        value: searchState.vessel,
                        items: commonVessels,
                        onChanged: (value) {
                          ref
                              .read(timerSearchProvider.notifier)
                              .setVessel(value);
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Search button
                    ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor:
                            isDark ? BrewColors.deepEspresso : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(searchState, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(TimerSearchState state, bool isDark) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(
            isDark ? BrewColors.accentGold : BrewColors.warmBrown,
          ),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: secondaryColor),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: textTheme.bodyMedium?.copyWith(color: secondaryColor),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _performSearch,
              child: Text(
                'Try Again',
                style: TextStyle(
                  color: isDark ? BrewColors.accentGold : BrewColors.warmBrown,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!state.hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: secondaryColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Search for timer recipes',
              style: textTheme.bodyMedium?.copyWith(color: secondaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Find recipes by name, vessel, or creator',
              style: textTheme.bodySmall?.copyWith(
                color: secondaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: secondaryColor),
            const SizedBox(height: 16),
            Text(
              'No timers found',
              style: textTheme.bodyMedium?.copyWith(color: secondaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different search terms or filters',
              style: textTheme.bodySmall?.copyWith(
                color: secondaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final timer = state.results[index];
        return _SearchResultCard(
          timer: timer,
          onTap: () => widget.onTimerSelected?.call(timer),
          isDark: isDark,
        );
      },
    );
  }
}

/// Dropdown filter widget
class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  final bool isDark;

  const _FilterDropdown({
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final surfaceColor =
        isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: TextStyle(color: secondaryColor)),
          isExpanded: true,
          dropdownColor: surfaceColor,
          icon: Icon(Icons.arrow_drop_down, color: secondaryColor),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All $label', style: TextStyle(color: textColor)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item[0].toUpperCase() + item.substring(1),
                    style: TextStyle(color: textColor),
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Card for search result
class _SearchResultCard extends StatelessWidget {
  final TimerModel timer;
  final VoidCallback? onTap;
  final bool isDark;

  const _SearchResultCard({
    required this.timer,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final cardColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  timer.brewType == 'coffee'
                      ? Icons.coffee_outlined
                      : Icons.emoji_food_beverage_outlined,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timer.name,
                      style: textTheme.titleSmall?.copyWith(color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${timer.vessel} • ${timer.formattedDuration}',
                      style: textTheme.bodySmall?.copyWith(color: secondaryColor),
                    ),
                    if (timer.handle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'by @${timer.handle}',
                        style: textTheme.bodySmall?.copyWith(
                          color: secondaryColor.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Save count badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark,
                          size: 12,
                          color: accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${timer.saveCount}',
                          style: textTheme.labelSmall?.copyWith(
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (timer.ratio != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${timer.ratio!.toStringAsFixed(timer.ratio! == timer.ratio!.truncateToDouble() ? 0 : 1)}:1',
                      style: textTheme.labelSmall?.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: secondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
