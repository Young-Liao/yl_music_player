import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../themes/theme_provider.dart';

class GroupListSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const GroupListSearchBar({super.key, required this.onChanged});

  @override
  State<GroupListSearchBar> createState() => _GroupListSearchBarState();
}

class _GroupListSearchBarState extends State<GroupListSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Search sub-groups and tracks below current path...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, size: 18),
          onPressed: () {
            _controller.clear();
            setState(() => _query = '');
            widget.onChanged('');
          },
        )
            : null,
        filled: true,
        fillColor: theme.cardBackgroundColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.textMuted.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.textMuted.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor.withValues(alpha: 0.5)),
        ),
      ),
      onChanged: (value) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          setState(() => _query = value.trim().toLowerCase());
          widget.onChanged(_query);
        });
      },
    );
  }
}