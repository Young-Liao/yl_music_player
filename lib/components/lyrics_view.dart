import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:yl_music_player/themes/app_theme_interface.dart';
import '../themes/theme_provider.dart';
import '../utils/algorithms.dart';
import '../utils/lyrics_handler.dart';
import 'dotted_line_painter.dart';

/// A synchronized, auto-scrolling lyrics view with interactive seek-overlay capabilities.
class LyricsView extends StatefulWidget {
  final LyricsHandler lyricsHandler;
  final Duration currentPosition;
  final ValueChanged<Duration>? onSeekTo;

  const LyricsView({
    super.key,
    required this.lyricsHandler,
    required this.currentPosition,
    this.onSeekTo,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();

  /// Fixed line height enabling fast $O(1)$ index calculation from scroll offset.
  static const double _itemHeight = 46.0;

  List<int> _lastActiveIndices = [];
  bool _isUserScrolling = false;
  int _hoveredIndex = -1;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Strict guard: Do NOT trigger auto-scroll if user is dragging or scrolling
    if (oldWidget.currentPosition != widget.currentPosition &&
        !_isUserScrolling) {
      _checkAndScroll();
    }
  }

  /// Calculates current active lyric line indices and schedules centering animation
  void _checkAndScroll() {
    if (_isUserScrolling) return;

    final activeIndices = widget.lyricsHandler.getCurrentIndices(
      widget.currentPosition,
    );
    if (activeIndices.isEmpty) return;

    final primaryIndex = activeIndices.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isUserScrolling) {
        _scrollToActiveLine(primaryIndex);
      }
    });
  }

  /// Centers the requested lyric index within the ListView viewport
  void _scrollToActiveLine(int primaryIndex, {bool withAnimate = true}) {
    if (!_scrollController.hasClients || _isUserScrolling) return;

    final targetOffset = primaryIndex * _itemHeight;

    if (withAnimate) {
      _scrollController
          .animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {});
    } else {
      _scrollController.jumpTo(targetOffset);
      // Reset on the next microtask/frame for jumpTo
    }
  }

  /// Fires on every sub-pixel frame of scroll movement
  void _onScroll() {
    if (!_isUserScrolling) return;

    _resetInactivityTimer();
    _updateHoveredIndex();
  }

  /// Listens to low-level scroll notifications across drag, fling, and wheel events
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      // dragDetails is non-null ONLY when triggered by human input (touch, drag)
      if (notification.dragDetails != null) {
        _isUserScrolling = true;
        _inactivityTimer?.cancel();
        _resetInactivityTimer();
        _updateHoveredIndex();
      }
    } else if (notification is ScrollUpdateNotification) {
      // Mouse wheel or trackpad updates supply dragDetails or scrollDelta from user pointer
      if (notification.dragDetails != null) {
        if (!_isUserScrolling) {
          setState(() => _isUserScrolling = true);
        }
        _resetInactivityTimer();
        _updateHoveredIndex();
      }
    } else if (notification is UserScrollNotification) {
      // Fires explicitly on user gesture direction shifts (ScrollDirection.forward/reverse)
      if (notification.direction != ScrollDirection.idle) {
        if (!_isUserScrolling) {
          setState(() => _isUserScrolling = true);
        }
        _resetInactivityTimer();
      }
    }
    return false;
  }

  /// Resets 2.5s inactivity timeout before restoring programmatic auto-scrolling
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isUserScrolling = false;
        });
        _checkAndScroll();
      }
    });
  }

  /// Computes the hovered index at the horizontal center in $O(1)$ time
  void _updateHoveredIndex() {
    if (!_scrollController.hasClients) return;

    final double centerOffset = _scrollController.offset;
    final int calculatedIndex = (centerOffset / _itemHeight).round();
    final int clampedIndex = calculatedIndex.clamp(
      0,
      widget.lyricsHandler.lines.length - 1,
    );

    if (clampedIndex != _hoveredIndex) {
      setState(() {
        _hoveredIndex = clampedIndex;
      });
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

    // Sync line jumps when crossing line bounds during active playback
    if (activeIndices.isNotEmpty &&
        activeIndices != _lastActiveIndices &&
        !_isUserScrolling) {
      _lastActiveIndices = activeIndices;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isUserScrolling) {
          _scrollToActiveLine(activeIndices.first, withAnimate: false);
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double verticalPadding = constraints.maxHeight / 2;

        return Stack(
          alignment: Alignment.center,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemExtent: _itemHeight,
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
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
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
                ),
              ),
            ),
            // Floating target overlay visible when manual scrolling is active
            if (_isUserScrolling &&
                _hoveredIndex >= 0 &&
                _hoveredIndex < handler.lines.length)
              _buildTargetOverlay(theme, handler),
          ],
        );
      },
    );
  }

  /// Builds the center seek target overlay with timestamp and seek trigger
  Widget _buildTargetOverlay(IAppTheme theme, LyricsHandler handler) {
    final hoveredLine = handler.lines[_hoveredIndex];
    final lineTimestamp = hoveredLine.timestamp;

    return IgnorePointer(
      ignoring: false,
      child: Container(
        height: _itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            // Timestamp Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                formatDuration(lineTimestamp.inSeconds.toDouble()),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Center Dotted Guide Line
            Expanded(
              child: CustomPaint(
                painter: DottedLinePainter(
                  color: theme.primaryColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Seek Action Button
            IconButton(
              icon: Icon(
                Icons.play_circle_fill,
                color: theme.primaryColor,
                size: 28,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                widget.onSeekTo?.call(lineTimestamp);
                setState(() {
                  _isUserScrolling = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
