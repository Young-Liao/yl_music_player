import 'package:flutter/material.dart';
import '../controllers/audio_player_controller.dart';
import '../themes/theme_provider.dart';

class TrackMetadata extends StatefulWidget {
  const TrackMetadata({
    super.key,
    required this.controller,
  });

  final AudioPlayerController controller;

  @override
  State<StatefulWidget> createState() => _TrackMetadataState();
}

class _TrackMetadataState extends State<TrackMetadata> {
  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    // Calculate a responsive size based on screen width so it stays a perfect 1:1 square
    final screenWidth = MediaQuery.of(context).size.width;
    final artworkSize = (screenWidth * 0.68).clamp(200.0, 270.0);

    final title = widget.controller.title;
    final artist = widget.controller.artist;
    final artworkBytes = widget.controller.artworkBytes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fixed 1:1 Square Artwork Container
        Container(
          width: artworkSize,
          height: artworkSize,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(theme.imageCornerRadius),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: artworkBytes != null 
              ? Image.memory(
                artworkBytes,
                fit: BoxFit.cover,
                width: artworkSize,
                height: artworkSize,
              )
              : Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: artworkSize * 0.38,
                  color: theme.primaryColor,
                ),
              ),
        ),
        const SizedBox(height: 16),
        // Track Title
        Text(
          title,
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Artist Name
        Text(
          artist,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: theme.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
