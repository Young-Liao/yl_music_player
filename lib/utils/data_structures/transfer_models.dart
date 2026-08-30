import 'dart:convert';
import 'dart:typed_data';

typedef TransferProgressCallback = void Function(
    int sentBytes,
    int totalBytes,
    double speedBytesPerSec,
    );

class NearbyDevice {
  final String id;
  final String name;
  final String ip;
  final int port;

  NearbyDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
  });
}

class TransferTrackInfo {
  final String id;
  final String fileName;
  final String title;
  final String artist;
  final int fileSize;
  final Uint8List? artworkBytes;

  TransferTrackInfo({
    required this.id,
    required this.fileName,
    required this.title,
    required this.artist,
    required this.fileSize,
    this.artworkBytes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'title': title,
    'artist': artist,
    'fileSize': fileSize,
    'artworkBytes': artworkBytes != null ? base64Encode(artworkBytes!) : null,
  };

  factory TransferTrackInfo.fromJson(Map<String, dynamic> json) {
    return TransferTrackInfo(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      title: json['title'] as String? ?? json['fileName'] as String,
      artist: json['artist'] as String? ?? 'Unknown Artist',
      fileSize: json['fileSize'] as int? ?? 0,
      artworkBytes: json['artworkBytes'] != null
          ? base64Decode(json['artworkBytes'] as String)
          : null,
    );
  }
}

class TransferBatchRequest {
  final NearbyDevice sender;
  final List<TransferTrackInfo> tracks;

  TransferBatchRequest({
    required this.sender,
    required this.tracks,
  });
}