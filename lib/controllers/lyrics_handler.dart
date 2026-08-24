import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

/// Individual lyric line holding a precise timestamp and text.
class LyricLine implements Comparable<LyricLine> {
  final Duration timestamp;
  final String text;

  LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  int compareTo(LyricLine other) => timestamp.compareTo(other.timestamp);
}

/// Handler for loading, parsing LRC files, and tracking active lyric lines.
class LyricsHandler {
  List<LyricLine> _lines = [];

  List<LyricLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  bool get isNotEmpty => _lines.isNotEmpty;

  /// Reads metadata directly from [audioFilePath], extracts embedded lyrics tags (e.g. USLT / SYLT / vorbis),
  /// and falls back to a sidecar `.lrc` file if no embedded lyrics are found.
  Future<void> loadFromFile(String? audioFilePath) async {
    _lines.clear();
    if (audioFilePath == null || audioFilePath.isEmpty) return;

    try {
      final file = File(audioFilePath);
      final metadata = readMetadata(file);
      final embeddedLyrics = metadata.lyrics;
      if (embeddedLyrics != null && embeddedLyrics.trim().isNotEmpty) {
        _parseLrc(embeddedLyrics);
        return;
      }
    } catch (e) {
      // Metadata reading failed; continue to sidecar file fallback
      debugPrint("Failed loading lyrics from music file, falling back: $e");
    }

    // 2. Fallback: Check for a sidecar .lrc file in the same directory
    try {
      final lrcPath = audioFilePath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
      final lrcFile = File(lrcPath);

      if (await lrcFile.exists()) {
        final lrcContent = await lrcFile.readAsString();
        _parseLrc(lrcContent);
      }
    } catch (e) {
      _lines.clear();
      debugPrint("Failed when loading lyrics: $e");
    }
  }

  /// Parses raw LRC text content into sorted [LyricLine] items.
  void _parseLrc(String lrcText) {
    final timeTagRegExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
    final parsed = <LyricLine>[];
    debugPrint("Successfully loaded lyrics.");

    for (var line in lrcText.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Extract all timestamp tags in the line
      final matches = timeTagRegExp.allMatches(line).toList();
      if (matches.isEmpty) continue;

      // Remove timestamp tags to get plain lyric text
      final text = line.replaceAll(timeTagRegExp, '').trim();

      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisecondsStr = match.group(3)!;

        // Normalize 2-digit (centiseconds) or 3-digit (milliseconds)
        final milliseconds = millisecondsStr.length == 2
            ? int.parse(millisecondsStr) * 10
            : int.parse(millisecondsStr);

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        parsed.add(LyricLine(timestamp: timestamp, text: text));
      }
    }

    // 2. Save sorted list by timestamp
    parsed.sort();
    _lines = parsed;
  }

  /// Returns all line indices matching the active timestamp (e.g., [2, 3, 4] for triple-line lyrics)
  List<int> getCurrentIndices(Duration position) {
    if (_lines.isEmpty || position < _lines.first.timestamp) {
      return [];
    }

    // 1. Find the latest timestamp <= current position
    int low = 0;
    int high = _lines.length - 1;
    int matchedIndex = -1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (_lines[mid].timestamp <= position) {
        matchedIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (matchedIndex == -1) return [];

    final targetTimestamp = _lines[matchedIndex].timestamp;

    // 2. Expand left to find the first line sharing this exact timestamp
    int firstIndex = matchedIndex;
    while (firstIndex > 0 && _lines[firstIndex - 1].timestamp == targetTimestamp) {
      firstIndex--;
    }

    // 3. Expand right to collect all lines sharing this exact timestamp
    int lastIndex = matchedIndex;
    while (lastIndex < _lines.length - 1 && _lines[lastIndex + 1].timestamp == targetTimestamp) {
      lastIndex++;
    }

    return List<int>.generate(lastIndex - firstIndex + 1, (i) => firstIndex + i);
  }
}