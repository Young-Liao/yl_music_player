import 'package:flutter/material.dart';
import 'package:yl_music_player/components/playback_controls.dart';
import 'package:yl_music_player/components/progress_bar.dart';
import 'package:yl_music_player/components/track_metadata.dart';
import '../themes/theme_provider.dart';
import '../components/header_bar.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({ super.key });
  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Scaffold(
      backgroundColor: theme.outerBackgroundColor,
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 28.0,
              ),
              decoration: BoxDecoration(
                  color: theme.cardBackgroundColor,
                  borderRadius: BorderRadius.circular(theme.cardCornerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  HeaderBar(),
                  TrackMetadata(),
                  Column(
                    children: [
                      ProgressBar(),
                      PlaybackControls(),
                    ],
                  )
                ],
              )
          ),
          )
      )
    );
  }
}