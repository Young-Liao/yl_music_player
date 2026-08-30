import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:yl_music_player/themes/app_theme_interface.dart';
import '../../themes/theme_provider.dart';
import '../../utils/algorithms.dart';
import '../../controllers/lyrics/lyrics_handler.dart';
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
  final Map<int, GlobalKey> _itemKeys = {};

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
    if (oldWidget.currentPosition != widget.currentPosition &&
        !_isUserScrolling) {
      _checkAndScroll();
    }
  }

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

  /// Centers the requested lyric index by retrieving its dynamic RenderBox context
  void _scrollToActiveLine(int primaryIndex, {bool withAnimate = true}) {
    if (!_scrollController.hasClients || _isUserScrolling) return;

    final key = _itemKeys[primaryIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: withAnimate
            ? const Duration(milliseconds: 350)
            : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onScroll() {
    if (!_isUserScrolling) return;

    _resetInactivityTimer();
    _updateHoveredIndex();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isUserScrolling = true;
        _inactivityTimer?.cancel();
        _resetInactivityTimer();
        _updateHoveredIndex();
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) {
        if (!_isUserScrolling) {
          setState(() => _isUserScrolling = true);
        }
        _resetInactivityTimer();
        _updateHoveredIndex();
      }
    } else if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        if (!_isUserScrolling) {
          setState(() => _isUserScrolling = true);
        }
        _resetInactivityTimer();
      }
    }
    return false;
  }

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

  void _updateHoveredIndex() {
    if (!_scrollController.hasClients) return;

    int closestIndex = 0;
    double minDistance = double.infinity;

    _itemKeys.forEach((index, key) {
      final context = key.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final position = renderBox.localToGlobal(Offset.zero);
          final distance = (position.dy - (MediaQuery.of(context).size.height / 2)).abs();
          if (distance < minDistance) {
            minDistance = distance;
            closestIndex = index;
          }
        }
      }
    });

    if (closestIndex != _hoveredIndex) {
      setState(() {
        _hoveredIndex = closestIndex;
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
                  padding: EdgeInsets.symmetric(
                    vertical: verticalPadding,
                    horizontal: 24.0,
                  ),
                  itemCount: handler.lines.length,
                  itemBuilder: (context, index) {
                    final line = handler.lines[index];
                    final isActive = activeIndices.contains(index);

                    final key = _itemKeys.putIfAbsent(index, () => GlobalKey());

                    return Container(
                      key: key,
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                          height: 1.4,
                        ),
                        child: Text(
                          line.text.isEmpty ? '♪' : line.text,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          maxLines: null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_isUserScrolling &&
                _hoveredIndex >= 0 &&
                _hoveredIndex < handler.lines.length)
              _buildTargetOverlay(theme, handler),
          ],
        );
      },
    );
  }

  Widget _buildTargetOverlay(IAppTheme theme, LyricsHandler handler) {
    final hoveredLine = handler.lines[_hoveredIndex];
    final lineTimestamp = hoveredLine.timestamp;

    return IgnorePointer(
      ignoring: false,
      child: Container(
        height: 46.0,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
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
            Expanded(
              child: CustomPaint(
                painter: DottedLinePainter(
                  color: theme.primaryColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
