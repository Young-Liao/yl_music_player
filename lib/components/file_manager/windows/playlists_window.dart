import 'package:flutter/material.dart';
import '../../../../../themes/theme_provider.dart';

class PlaylistsWindow extends StatelessWidget {
  const PlaylistsWindow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Center(
      child: Text(
        'Playlists Window',
        style: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
          color: theme.textSecondary,
        ),
      ),
    );
  }
}