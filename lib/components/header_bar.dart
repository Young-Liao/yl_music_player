import 'package:flutter/material.dart';
import '../themes/theme_provider.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({ super.key });

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Center
      children: [
        Text(
          'YL Music Player',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
        IconButton(
          onPressed: () {
            // TODO: SWITCHING THEMES
          },
          icon: Icon(
            Icons.wb_sunny_rounded,
            color: theme.primaryColor,
          ),
          splashRadius: 20,
        )
      ],
    );
  }
}