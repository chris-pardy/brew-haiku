import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../copy/strings.dart';

class BrewSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final bool enabled;

  const BrewSearchBar({
    super.key,
    required this.onSearch,
    this.enabled = true,
  });

  @override
  State<BrewSearchBar> createState() => _BrewSearchBarState();
}

class _BrewSearchBarState extends State<BrewSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.onSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      onChanged: _onChanged,
      style: BrewTypography.body,
      decoration: InputDecoration(
        hintText: S.searchHint,
        hintStyle: BrewTypography.body.copyWith(color: BrewColors.subtle),
        prefixIcon: const Icon(Icons.search, color: BrewColors.subtle),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, __) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.clear, color: BrewColors.subtle),
              onPressed: () {
                _controller.clear();
                widget.onSearch('');
              },
            );
          },
        ),
      ),
    );
  }
}
