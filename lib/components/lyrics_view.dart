import 'package:flutter/material.dart';
import '../themes/theme_provider.dart';
import '../utils/lyrics_handler.dart';

class LyricsView extends StatefulWidget {
  final LyricsHandler lyricsHandler;
  final Duration currentPosition;

  const LyricsView({
    super.key,
    required this.lyricsHandler,
    required this.currentPosition,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();

  // Define an estimated fixed height per line item for index-based offset calculations
  static const double _itemHeight = 46.0;

  List<int> _lastActiveIndices = [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition) {
      _checkAndScroll();
    }
  }

  void _checkAndScroll() {
    final activeIndices = widget.lyricsHandler.getCurrentIndices(
      widget.currentPosition,
    );
    if (activeIndices.isEmpty) return;

    final primaryIndex = activeIndices.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToActiveLine(primaryIndex);
      }
    });
  }

  void _scrollToActiveLine(int primaryIndex, {bool withAnimate = true}) {
    if (!_scrollController.hasClients) return;

    // Calculate offset to place the target line dead center
    final targetOffset = primaryIndex * _itemHeight;

    if (withAnimate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final handler = widget.lyricsHandler;

    if (handler.isEmpty) {
      return Center(
        child: Text(
          'No Lyrics Available',
          style: TextStyle(
            fontSize: 16,
            color: theme.textSecondary.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final activeIndices = handler.getCurrentIndices(widget.currentPosition);

    // Only schedule post-frame scroll when crossing into a new lyric line
    if (activeIndices.isNotEmpty && activeIndices != _lastActiveIndices) {
      _lastActiveIndices = activeIndices;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToActiveLine(activeIndices.first, withAnimate: false);
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double verticalPadding = constraints.maxHeight / 2;

        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          itemExtent: _itemHeight,
          // Enforces deterministic sizing so unrendered lines have known offsets
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding - (_itemHeight / 2),
            horizontal: 24.0,
          ),
          itemCount: handler.lines.length,
          itemBuilder: (context, index) {
            final line = handler.lines[index];
            final isActive = activeIndices.contains(index);

            return Container(
              alignment: Alignment.center,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: isActive ? 22.0 : 16.0,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? theme.primaryColor
                      : theme.textSecondary.withValues(alpha: 0.4),
                  height: 1.3,
                ),
                child: Text(
                  line.text.isEmpty ? '♪' : line.text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
