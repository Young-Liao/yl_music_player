import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:metadata_god/metadata_god.dart';

/// Metadata model holding cached track details and compressed artwork bytes.
class TrackMetadataItem {
  final String filePath;
  final String title;
  final String artist;
  final String album;
  final Uint8List? compressedArtwork;

  TrackMetadataItem({
    required this.filePath,
    required this.title,
    required this.artist,
    this.album = '',
    this.compressedArtwork,
  });

  /// Factory constructor for unknown / empty track state.
  factory TrackMetadataItem.empty() {
    return TrackMetadataItem(
      filePath: "Unknown Path",
      title: "Waiting for a song...",
      artist: "...",
      album: "",
      compressedArtwork: null,
    );
  }

  /// Only file path
  factory TrackMetadataItem.onlyPath(String filePath) {
    return TrackMetadataItem(
      filePath: filePath,
      title: "",
      artist: "",
      album: "",
    );
  }

  /// Synchronous fallback when metadata parsing fails or isn't ready yet.
  factory TrackMetadataItem.fallback(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final cleanTitle = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    return TrackMetadataItem(
      filePath: path,
      title: cleanTitle,
      artist: 'Unknown Artist',
      album: 'Unknown Album',
      compressedArtwork: null,
    );
  }

  /// Async factory method that reads ID3 tags via [MetadataGod] and compresses artwork.
  static Future<TrackMetadataItem> fromPath(String path) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: path);

      final title =
          metadata.title ?? path.split('/').last.replaceAll('.mp3', '');
      final artist = metadata.artist ?? 'Unknown Artist';
      final album = metadata.album ?? 'Unknown Album';
      final rawArtwork = metadata.picture?.data;

      // Compress artwork byte array to 88x88 px thumbnail to save RAM and avoid render lag
      Uint8List? compressedArtwork;
      if (rawArtwork != null && rawArtwork.isNotEmpty) {
        compressedArtwork = await _compressImageBytes(
          rawArtwork,
          targetWidth: 88,
        );
      }

      return TrackMetadataItem(
        filePath: path,
        title: title,
        artist: artist,
        album: album,
        compressedArtwork: compressedArtwork,
      );
    } catch (e) {
      return TrackMetadataItem.fallback(path);
    }
  }

  /// Convert JSON map to TrackMetadataItem (for DB or cache storage)
  factory TrackMetadataItem.fromJson(Map<String, dynamic> json) {
    return TrackMetadataItem(
      filePath: json['filePath'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      compressedArtwork: json['compressedArtwork'] != null
          ? Uint8List.fromList(List<int>.from(json['compressedArtwork']))
          : null,
    );
  }

  /// Downscales high-resolution cover images to a thumbnail target width using Flutter UI codecs.
  static Future<Uint8List?> _compressImageBytes(
      Uint8List rawBytes, {
        required int targetWidth,
      }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetWidth,
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      // Fallback to original raw bytes if codec compression fails
      return rawBytes;
    }
  }

  /// Returns the file size in bytes synchronously using [File].
  /// Returns 0 if the file does not exist or if an IO error occurs.
  int getFileSize() {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (e) {
      rethrow;
    }
    return 0;
  }
}
