import 'package:yl_music_player/utils/data_structures/track_metadata_item.dart';

class GroupEntity {
  final int id;
  String name;
  final int? parentId;

  GroupEntity({required this.id, required this.name, this.parentId});

  Map<String, dynamic> toMap() => {
    if (id != 0) 'id': id,
    'name': name,
    'parent_id': parentId,
  };
}

class GroupNode {
  final GroupEntity entity;
  final List<GroupNode> subGroups;
  int totalTracks;

  GroupNode({
    required this.entity,
    this.subGroups = const [],
    this.totalTracks = 0,
  });
}

class GroupedTrackMetadataItem extends TrackMetadataItem {
  final int id;
  final int groupId;

  GroupedTrackMetadataItem({
    required this.id,
    required this.groupId,
    required super.filePath,
    required super.title,
    required super.artist,
    required super.album,
    super.compressedArtwork,
  });

  factory GroupedTrackMetadataItem.fromMetadata({
    required int id,
    required int groupId,
    required TrackMetadataItem metadata,
  }) {
    return GroupedTrackMetadataItem(
      id: id,
      groupId: groupId,
      filePath: metadata.filePath,
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      compressedArtwork: metadata.compressedArtwork,
    );
  }

  /// Copies metadata while preserving the group assignment context
  GroupedTrackMetadataItem copyWithGroup({
    int? id,
    int? groupId,
    TrackMetadataItem? metadata,
  }) {
    final meta = metadata ?? this;
    return GroupedTrackMetadataItem(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      filePath: meta.filePath,
      title: meta.title,
      artist: meta.artist,
      album: meta.album,
      compressedArtwork: meta.compressedArtwork,
    );
  }
}

/// Tracks the active viewport range for a specific group tab/view.
class GroupWindowCursor {
  final int groupId;
  int windowL = 0;
  int windowR = 0;
  List<GroupedTrackMetadataItem> cachedWindowItems = [];

  GroupWindowCursor({required this.groupId});
}
